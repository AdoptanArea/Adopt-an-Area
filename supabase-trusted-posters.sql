-- Adopt an Area — trusted posters, and the go-ahead a group needs before its
-- photos are public (run once in the Supabase SQL editor, AFTER
-- supabase-event-page.sql)
--
-- Two things, both built the same way as "who may run a clean-up event" in
-- supabase-events.sql — a switch per person, and a second switch that lets
-- somebody hand the first one out. Appointing a deputy always stays with the
-- site admin, so a permission can't quietly become everybody's.
--
--   1) THE GALLERY. Until now only the site admin could post to the photo wall.
--      Now anyone ticked can, and anyone ticked as a gallery deputy can tick
--      others. A trusted poster may take down what they themselves put up; the
--      site admin may take down anything, and is still the only one who sets
--      the featured project on the home page.
--
--   2) A GROUP'S PHOTOS. A public group has always shown its photo wall to
--      anyone who found it. That's the hole this closes. From here, a public
--      group shows its name, its town and the areas it looks after — and its
--      photos stay between its members until somebody trusted has looked at
--      the group and said yes.
--
--      The group asks (an admin taps a button), a reviewer says yes or not
--      yet. Reviewers are ticked the same way, and can be given the right to
--      tick other reviewers.
--
-- WORTH KNOWING BEFORE YOU RUN IT: every group that is public today has its
-- photos on show today. Running this hides all of them until they're approved,
-- one by one. That's the point of it — but if you'd rather start by trusting
-- what's already up, there's a line at the very bottom that approves every
-- group that exists right now.

-- =============================================================================
-- 1) The switches
-- =============================================================================

-- Posting to the gallery, and handing that out.
alter table public.profiles add column if not exists can_post_gallery  boolean not null default false;
alter table public.profiles add column if not exists can_grant_gallery boolean not null default false;

-- Saying yes to a group's photos, and handing that out.
alter table public.profiles add column if not exists can_ok_photos     boolean not null default false;
alter table public.profiles add column if not exists can_grant_photos  boolean not null default false;

-- Where a group stands: asked, and answered.
alter table public.teams add column if not exists photos_asked       boolean not null default false;
alter table public.teams add column if not exists photos_approved    boolean not null default false;
alter table public.teams add column if not exists photos_approved_by uuid;
alter table public.teams add column if not exists photos_approved_at timestamptz;

-- The gallery remembers who posted each thing, so a trusted poster can take
-- down their own without being able to touch anybody else's.
alter table public.gallery_photos add column if not exists posted_by uuid default auth.uid();

-- teams is granted column by column (that's how invite_code stays hidden), so
-- the two new ones have to be named here or the app can't read them back.
grant select (id, name, town_id, created_by, is_public, photos_public,
              logo_url, event_date, event_time, event_lat, event_lng, event_place,
              event_info, event_video, event_contact,
              photos_asked, photos_approved)
  on public.teams to anon, authenticated;

-- The queue of groups waiting to be looked at.
create index if not exists teams_photos_asked_idx on public.teams (photos_asked)
  where photos_asked and not photos_approved;

-- =============================================================================
-- 2) Who may do what
-- =============================================================================
-- Site admin always may. Everybody else is off until somebody ticks them.

create or replace function public.may_post_gallery()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin or can_post_gallery
                     from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.may_grant_gallery()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin or can_grant_gallery
                     from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.may_ok_photos()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin or can_ok_photos
                     from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.may_grant_photos()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin or can_grant_photos
                     from public.profiles where id = auth.uid()), false);
$$;

grant execute on function public.may_post_gallery()  to authenticated;
grant execute on function public.may_grant_gallery() to authenticated;
grant execute on function public.may_ok_photos()     to authenticated;
grant execute on function public.may_grant_photos()  to authenticated;

-- =============================================================================
-- 3) Handing it out
-- =============================================================================

create or replace function public.set_gallery_poster(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.may_grant_gallery() then
    raise exception 'Only the site admin, or a deputy, can decide who may post to the gallery';
  end if;
  update public.profiles set can_post_gallery = p_on where id = p_user;
  if not found then raise exception 'No such person'; end if;
end;
$$;

create or replace function public.set_photo_reviewer(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.may_grant_photos() then
    raise exception 'Only the site admin, or a deputy, can decide who reviews group photos';
  end if;
  update public.profiles set can_ok_photos = p_on where id = p_user;
  if not found then raise exception 'No such person'; end if;
end;
$$;

-- Deputies stay with the site admin, same as with events.
create or replace function public.set_gallery_granter(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_site_admin() then
    raise exception 'Only the site admin can appoint a deputy';
  end if;
  update public.profiles set can_grant_gallery = p_on where id = p_user;
  if not found then raise exception 'No such person'; end if;
end;
$$;

create or replace function public.set_photo_granter(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_site_admin() then
    raise exception 'Only the site admin can appoint a deputy';
  end if;
  update public.profiles set can_grant_photos = p_on where id = p_user;
  if not found then raise exception 'No such person'; end if;
end;
$$;

grant execute on function public.set_gallery_poster(uuid, boolean)  to authenticated;
grant execute on function public.set_gallery_granter(uuid, boolean) to authenticated;
grant execute on function public.set_photo_reviewer(uuid, boolean)  to authenticated;
grant execute on function public.set_photo_granter(uuid, boolean)   to authenticated;

-- The list to tick from — the same idea as event_people(), with every switch on
-- it. Whoever may hand out any one of them can see the list; the functions
-- above are what actually decide whether a tick sticks. Still a name and a
-- town, never a phone number or an email.
create or replace function public.permission_people(p_q text default null)
returns table (id uuid, name text, town_id text,
               can_host_events boolean, can_grant_events boolean,
               can_post_gallery boolean, can_grant_gallery boolean,
               can_ok_photos boolean, can_grant_photos boolean)
language sql security definer set search_path = public stable
as $$
  select p.id, p.name, p.town_id,
         p.can_host_events, p.can_grant_events,
         p.can_post_gallery, p.can_grant_gallery,
         p.can_ok_photos, p.can_grant_photos
    from public.profiles p
   where (public.may_grant_events() or public.may_grant_gallery() or public.may_grant_photos())
     and (p_q is null or btrim(p_q) = '' or p.name ilike '%' || btrim(p_q) || '%')
   order by (p.can_host_events or p.can_post_gallery or p.can_ok_photos) desc, p.name
   limit 40;
$$;

grant execute on function public.permission_people(text) to authenticated;

-- =============================================================================
-- 4) The gallery itself
-- =============================================================================
-- Posting was the site admin's alone and was held that way by the app. Now that
-- other people can post, the rule has to sit on the table.

alter table public.gallery_photos enable row level security;

drop policy if exists "anyone reads the gallery" on public.gallery_photos;
create policy "anyone reads the gallery"
  on public.gallery_photos for select
  using (true);

drop policy if exists "trusted people post to the gallery" on public.gallery_photos;
create policy "trusted people post to the gallery"
  on public.gallery_photos for insert to authenticated
  with check (public.may_post_gallery());

drop policy if exists "trusted people edit the gallery" on public.gallery_photos;
create policy "trusted people edit the gallery"
  on public.gallery_photos for update to authenticated
  using (public.may_post_gallery())
  with check (public.may_post_gallery());

-- Your own back, or anything at all if you're the site admin.
drop policy if exists "posters take down their own" on public.gallery_photos;
create policy "posters take down their own"
  on public.gallery_photos for delete to authenticated
  using (public.is_site_admin()
         or (public.may_post_gallery() and posted_by = auth.uid()));

-- The featured project is the first thing anybody sees on the home page, so it
-- stays the site admin's call. A trusted poster ticking the box gets a normal
-- post rather than an error.
create or replace function public.gallery_featured_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(new.is_featured, false) and not public.is_site_admin() then
      new.is_featured := false;
    end if;
  else
    if new.is_featured is distinct from old.is_featured and not public.is_site_admin() then
      raise exception 'Only the Adopt an Area admin picks the featured project';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists gallery_featured_guard on public.gallery_photos;
create trigger gallery_featured_guard
  before insert or update on public.gallery_photos
  for each row execute function public.gallery_featured_guard();

-- The files behind the posts. NOTE: storage policies are OR'd. If a blanket
-- "any signed-in user may upload to gallery" policy is already there, drop it
-- or this one won't actually hold anybody back.
drop policy if exists "trusted people upload gallery files" on storage.objects;
create policy "trusted people upload gallery files"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'gallery' and public.may_post_gallery());

-- =============================================================================
-- 5) A group's photos: asked, then answered
-- =============================================================================
-- This is the one line that changes what outsiders see. Members are unaffected:
-- inside the group everything works as it always did.

create or replace function public.can_see_team_photos(t uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select public.is_team_member(t)
      or public.may_ok_photos()          -- a reviewer has to be able to look
      or coalesce((select is_public and photos_public and photos_approved
                     from public.teams where id = t), false);
$$;

-- Asking. A group admin's to do, and only while there's something to ask for.
create or replace function public.request_group_photos(p_team uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  ok boolean;
begin
  if not public.is_team_admin(p_team) then
    raise exception 'Only a group admin can ask for this';
  end if;
  select photos_approved into ok from public.teams where id = p_team;
  if ok then
    raise exception 'This group already shows its photos to everyone';
  end if;
  update public.teams set photos_asked = true where id = p_team;
end;
$$;

-- Answering.
create or replace function public.set_group_photos(p_team uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.may_ok_photos() then
    raise exception 'You are not set up to review group photos';
  end if;
  update public.teams
     set photos_approved    = p_on,
         photos_asked       = false,
         photos_approved_by = case when p_on then auth.uid() end,
         photos_approved_at = case when p_on then now() end
   where id = p_team;
  if not found then raise exception 'No such group'; end if;
end;
$$;

-- The queue. Groups that have asked first, then the ones already said yes to,
-- so taking one back is as easy as giving it. Counts come along so a reviewer
-- can see there's something there without going in.
create or replace function public.group_photo_requests()
returns table (id uuid, name text, town_id text, photos_asked boolean,
               photos_approved boolean, is_public boolean,
               photo_count bigint, member_count bigint)
language sql security definer set search_path = public stable
as $$
  select t.id, t.name, t.town_id, t.photos_asked, t.photos_approved, t.is_public,
         (select count(*) from public.team_photos  p where p.team_id = t.id),
         (select count(*) from public.team_members m where m.team_id = t.id)
    from public.teams t
   where public.may_ok_photos()
     and (t.photos_asked or t.photos_approved)
   order by t.photos_asked desc, t.name
   limit 60;
$$;

grant execute on function public.request_group_photos(uuid)       to authenticated;
grant execute on function public.set_group_photos(uuid, boolean)  to authenticated;
grant execute on function public.group_photo_requests()           to authenticated;

-- A group admin may update their own group's row — which would include this,
-- if nothing stopped them. This stops them.
create or replace function public.teams_photo_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(new.photos_approved, false) and not public.may_ok_photos() then
      new.photos_approved := false;
    end if;
  else
    if new.photos_approved is distinct from old.photos_approved
       and not public.may_ok_photos() then
      raise exception 'Only Adopt an Area can let a group show its photos to everyone';
    end if;
    if new.photos_asked is distinct from old.photos_asked
       and not (public.is_team_admin(new.id) or public.may_ok_photos()) then
      raise exception 'Only a group admin can ask for this';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists teams_photo_guard on public.teams;
create trigger teams_photo_guard
  before insert or update on public.teams
  for each row execute function public.teams_photo_guard();

-- =============================================================================
-- 6) The groups that are already out there
-- =============================================================================
-- Everything above starts every group at "not approved", including the ones
-- whose photos have been public all along. Look through them in the app —
-- My Area, "Groups waiting to show their photos" — and say yes one at a time.
--
-- Or, if you'd rather trust what's already up and review only what comes next,
-- run this line on its own:
--
--   update public.teams set photos_approved = true where is_public;
