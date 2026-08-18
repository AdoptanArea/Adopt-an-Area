-- Adopt an Area — group logos and clean-up events (run once in the Supabase SQL
-- editor, AFTER supabase-delete-group.sql)
--
-- Two things live in here:
--
--   1) Every group can have a logo. It's just another file in the team-photos
--      bucket, so the upload rule that's already there (admins only, inside the
--      group's own folder) covers it without any new storage policy.
--
--   2) Some groups are clean-up events: a group with a day and a meeting spot on
--      the map. Not everybody may start one, or the home page would fill up with
--      whatever anyone felt like posting. You tick who may. You can also make
--      somebody a deputy, who may then tick others, so handing this out doesn't
--      all sit with you once the thing grows.
--
--   Nobody can join an event once its day has passed. The group stays, with its
--   photos and its members, and the app files it under "past events".

-- 1) The new columns -----------------------------------------------------------
alter table public.teams add column if not exists logo_url    text;
alter table public.teams add column if not exists event_date  date;
alter table public.teams add column if not exists event_time  text;   -- free text: "09:00", "Saturday morning"
alter table public.teams add column if not exists event_lat   double precision;
alter table public.teams add column if not exists event_lng   double precision;
alter table public.teams add column if not exists event_place text;   -- what to tell people: "Corner of Main and Church"

-- Upcoming events are read on every home page load, by name of date.
create index if not exists teams_event_date_idx on public.teams (event_date)
  where event_date is not null;

alter table public.profiles add column if not exists can_host_events  boolean not null default false;
alter table public.profiles add column if not exists can_grant_events boolean not null default false;
-- Where this person is, so the home page can work out which events are near them.
-- The app fills these in by looking up whichever town they picked.
alter table public.profiles add column if not exists town_lat double precision;
alter table public.profiles add column if not exists town_lng double precision;

-- Your own coordinates are yours to write. The two event permissions deliberately
-- are not: they're handed out through the functions further down.
grant update (name, town_id, phone, share_contact, town_lat, town_lng)
  on public.profiles to authenticated;

-- teams is granted column by column since supabase-group-admins.sql (that's how
-- invite_code stays hidden), so anything new has to be named here or the app
-- can't read it back.
grant select (id, name, town_id, created_by, is_public, photos_public,
              logo_url, event_date, event_time, event_lat, event_lng, event_place)
  on public.teams to anon, authenticated;

-- 2) Who may run an event ------------------------------------------------------
-- Site admin always may. Everybody else is off until somebody ticks them.

create or replace function public.may_host_events()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin or can_host_events
                     from public.profiles where id = auth.uid()), false);
$$;

-- Deputies. Being allowed to hand it out doesn't imply being allowed to run one
-- yourself — tick both if that's what you mean.
create or replace function public.may_grant_events()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin or can_grant_events
                     from public.profiles where id = auth.uid()), false);
$$;

grant execute on function public.may_host_events()  to authenticated;
grant execute on function public.may_grant_events() to authenticated;

-- 3) Handing it out ------------------------------------------------------------

create or replace function public.set_event_host(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.may_grant_events() then
    raise exception 'Only the site admin, or a deputy, can decide who may run events';
  end if;
  update public.profiles set can_host_events = p_on where id = p_user;
  if not found then
    raise exception 'No such person';
  end if;
end;
$$;

-- Making somebody a deputy stays with the site admin. A deputy handing out
-- deputyships is how a permission quietly becomes everybody's.
create or replace function public.set_event_granter(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_site_admin() then
    raise exception 'Only the site admin can appoint a deputy';
  end if;
  update public.profiles set can_grant_events = p_on where id = p_user;
  if not found then
    raise exception 'No such person';
  end if;
end;
$$;

grant execute on function public.set_event_host(uuid, boolean)    to authenticated;
grant execute on function public.set_event_granter(uuid, boolean) to authenticated;

-- The list to tick from. Profiles are readable only by their owner, so this is
-- the only way an admin sees anybody else — and it hands back a name and a town,
-- never a phone number or an email.
create or replace function public.event_people(p_q text default null)
returns table (id uuid, name text, town_id text, can_host_events boolean, can_grant_events boolean)
language sql security definer set search_path = public stable
as $$
  select p.id, p.name, p.town_id, p.can_host_events, p.can_grant_events
    from public.profiles p
   where public.may_grant_events()
     and (p_q is null or btrim(p_q) = '' or p.name ilike '%' || btrim(p_q) || '%')
   order by p.can_host_events desc, p.can_grant_events desc, p.name
   limit 40;
$$;

grant execute on function public.event_people(text) to authenticated;

-- 4) Starting an event ---------------------------------------------------------
-- Goes through here rather than a plain insert, so the permission check and the
-- "whoever starts it runs it" rule sit next to the data.

create or replace function public.create_event_group(
  p_name text, p_public boolean, p_date date, p_time text,
  p_lat double precision, p_lng double precision, p_place text, p_town text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  tid uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in first';
  end if;
  if not public.may_host_events() then
    raise exception 'You are not set up to run clean-up events yet — ask the Adopt an Area admin';
  end if;
  if p_date is null then
    raise exception 'An event needs a day';
  end if;
  if p_date < current_date then
    raise exception 'That day has already passed';
  end if;
  if p_lat is null or p_lng is null then
    raise exception 'Drop a pin on the map so people know where to meet';
  end if;

  insert into public.teams (name, town_id, created_by, is_public,
                            event_date, event_time, event_lat, event_lng, event_place)
  values (nullif(btrim(p_name), ''), nullif(btrim(p_town), ''), auth.uid(), coalesce(p_public, true),
          p_date, nullif(btrim(p_time), ''), p_lat, p_lng, nullif(btrim(p_place), ''))
  returning id into tid;

  insert into public.team_members (team_id, user_id, member_name, role)
  values (tid, auth.uid(),
          coalesce((select name from public.profiles where id = auth.uid()), 'Neighbour'), 'admin');

  return tid;
end;
$$;

grant execute on function public.create_event_group(text, boolean, date, text, double precision, double precision, text, text)
  to authenticated;

-- 5) Nobody turns an ordinary group into an event on the sly --------------------
-- The app inserts and updates teams directly, so the check has to be on the
-- table itself, not only in the function above.

create or replace function public.teams_event_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.event_date is not null and not public.may_host_events() then
      raise exception 'You are not set up to run clean-up events yet';
    end if;
  else
    if (new.event_date is distinct from old.event_date
        or new.event_lat  is distinct from old.event_lat
        or new.event_lng  is distinct from old.event_lng)
       and not public.may_host_events() then
      raise exception 'You are not set up to run clean-up events yet';
    end if;
    -- A day that has been and gone stays gone: no quietly moving an old event
    -- forward to get back onto the home page.
    if old.event_date is not null and old.event_date < current_date
       and new.event_date is distinct from old.event_date then
      raise exception 'That event is over — start a new one instead';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists teams_event_guard on public.teams;
create trigger teams_event_guard
  before insert or update on public.teams
  for each row execute function public.teams_event_guard();

-- 6) An event you can't join any more ------------------------------------------
-- Same function as before, with one extra rule at the top.

create or replace function public.join_team_with_pin(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  tid uuid;
  ev  date;
begin
  if auth.uid() is null then
    raise exception 'Sign in first';
  end if;
  select id, event_date into tid, ev
    from public.teams
   where upper(invite_code) = upper(btrim(p_code))
   limit 1;
  if tid is null then
    return null;
  end if;
  if ev is not null and ev < current_date then
    raise exception 'That clean-up has already happened — its photos are still there to look at';
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
