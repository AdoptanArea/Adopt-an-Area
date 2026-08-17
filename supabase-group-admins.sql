-- Adopt an Area — group admins (run once in the Supabase SQL editor,
-- AFTER supabase-public-groups.sql)
--
-- Gives every group one or more admins. An admin is the only one who can:
--   * post photos to the group page
--   * decide whether outsiders may look at those photos
--   * read (and therefore share) the join pin
--   * hand the admin badge to somebody else
-- Everyone else in the group is a plain member: they see the group, its
-- photos and its claimed areas, but they can't change any of that.
--
-- Assumes teams.id is a uuid (the Supabase default). If yours are bigint,
-- swap the `uuid` argument types below.

-- 1) The role column ----------------------------------------------------------
alter table public.team_members
  add column if not exists role text not null default 'member';

alter table public.team_members
  drop constraint if exists team_members_role_check;
alter table public.team_members
  add constraint team_members_role_check check (role in ('member','admin'));

-- Whoever created a team is its first admin.
update public.team_members m
   set role = 'admin'
  from public.teams t
 where t.id = m.team_id
   and t.created_by = m.user_id
   and m.role <> 'admin';

-- A team whose creator never joined (or has since left) still needs somebody
-- in charge, so the longest-standing member gets the badge. ctid stands in for
-- insertion order — team_members has no created_at to sort on.
update public.team_members m
   set role = 'admin'
  from (
    select t.id as team_id,
           (select mm.user_id
              from public.team_members mm
             where mm.team_id = t.id
             order by mm.ctid
             limit 1) as first_member
      from public.teams t
     where not exists (select 1 from public.team_members a
                        where a.team_id = t.id and a.role = 'admin')
  ) o
 where m.team_id = o.team_id
   and m.user_id = o.first_member;

-- 2) Separate switch for "can outsiders see our photos?" -----------------------
-- A group can be public (findable, claimed areas on show) and still keep its
-- photo wall to itself. Defaults to true so nothing changes for groups that
-- already went public.
alter table public.teams
  add column if not exists photos_public boolean not null default true;

-- 3) Helper functions ---------------------------------------------------------
-- SECURITY DEFINER for the same reason as the ones in supabase-public-groups.sql:
-- a policy that queried these tables directly would recurse into itself.

create or replace function public.is_team_admin(t uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = t and m.user_id = auth.uid() and m.role = 'admin'
  );
$$;

create or replace function public.can_see_team_photos(t uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.is_team_member(t)
      or coalesce((select is_public and photos_public
                     from public.teams where id = t), false);
$$;

grant execute on function public.is_team_admin(uuid)      to authenticated;
grant execute on function public.can_see_team_photos(uuid) to anon, authenticated;

-- 4) Policies -----------------------------------------------------------------

-- Team settings (name, public/private, photo visibility) are an admin job.
-- This replaces the old creator-only rule — the creator is an admin anyway.
drop policy if exists "creator updates own team" on public.teams;
drop policy if exists "admins update own team"   on public.teams;
create policy "admins update own team"
  on public.teams for update
  using (public.is_team_admin(id))
  with check (public.is_team_admin(id));

-- Photos: readable by members always, by outsiders only if the group is public
-- AND has left its photo wall open.
-- Worth knowing: this hides the photo *list*. The files themselves sit in a
-- public storage bucket (supabase-public-groups.sql turns that on so links
-- work), so a photo whose exact URL somebody already copied stays reachable.
-- Closing that off means making the bucket private and switching the app from
-- getPublicUrl() to signed URLs.
drop policy if exists "read photos of public or own team" on public.team_photos;
create policy "read photos of public or own team"
  on public.team_photos for select
  using (public.can_see_team_photos(team_id));

drop policy if exists "admins post team photos" on public.team_photos;
create policy "admins post team photos"
  on public.team_photos for insert
  with check (public.is_team_admin(team_id));

drop policy if exists "admins remove team photos" on public.team_photos;
create policy "admins remove team photos"
  on public.team_photos for delete
  using (public.is_team_admin(team_id));

-- The image files themselves. The app uploads to "<team id>/<file>", so the
-- first folder of the path says which team the file belongs to.
-- NOTE: policies are OR'd. If you already have a blanket "any signed-in user
-- may upload to team-photos" policy on storage.objects, drop it or this one
-- won't actually hold anybody back.
drop policy if exists "admins upload team photos" on storage.objects;
create policy "admins upload team photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'team-photos'
    and case
          when (storage.foldername(name))[1] ~*
               '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then public.is_team_admin(((storage.foldername(name))[1])::uuid)
          else false
        end
  );

-- 5) Handing out the admin badge ----------------------------------------------
-- Done through a function so the "a group can't be left with no admin" rule
-- lives next to the data instead of in the browser.

create or replace function public.set_team_member_role(t uuid, target uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_count int;
begin
  if new_role not in ('member','admin') then
    raise exception 'Unknown role %', new_role;
  end if;
  if not public.is_team_admin(t) then
    raise exception 'Only a group admin can change who else is an admin';
  end if;
  if new_role = 'member' then
    select count(*) into admin_count
      from public.team_members where team_id = t and role = 'admin';
    if admin_count <= 1 then
      raise exception 'A group needs at least one admin — make somebody else an admin first';
    end if;
  end if;
  update public.team_members
     set role = new_role
   where team_id = t and user_id = target;
  if not found then
    raise exception 'That person is not in this group';
  end if;
end;
$$;

grant execute on function public.set_team_member_role(uuid, uuid, text) to authenticated;

-- 6) The join pin --------------------------------------------------------------
-- Hiding the pin in the interface isn't enough — a member could still read it
-- straight off the API. Postgres won't let a column-level revoke override a
-- table-level grant, so the table grant goes and comes back column by column,
-- minus invite_code.
--
-- Anything selecting from teams must now name its columns; `select *` will be
-- refused. The app does exactly that (see TEAM_COLS in index.html).

revoke select on public.teams from anon, authenticated;
grant select (id, name, town_id, created_by, is_public, photos_public)
  on public.teams to anon, authenticated;

-- Admins read their own pin through here.
create or replace function public.team_invite_code(t uuid)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select case when public.is_team_admin(t)
              then (select invite_code from public.teams where id = t)
         end;
$$;

grant execute on function public.team_invite_code(uuid) to authenticated;

-- Joining by pin also has to go through a function now: the joiner can't read
-- the teams row to look the pin up, and (for a private group) couldn't see the
-- row at all. Matching is case-insensitive and ignores stray spaces.
create or replace function public.join_team_with_pin(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  tid uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in first';
  end if;
  select id into tid
    from public.teams
   where upper(invite_code) = upper(btrim(p_code))
   limit 1;
  if tid is null then
    return null;
  end if;
  if not exists (select 1 from public.team_members
                  where team_id = tid and user_id = auth.uid()) then
    insert into public.team_members (team_id, user_id, member_name, role)
    values (tid, auth.uid(), coalesce(nullif(btrim(p_name), ''), 'Neighbour'), 'member');
  end if;
  return tid;
end;
$$;

grant execute on function public.join_team_with_pin(text, text) to authenticated;
