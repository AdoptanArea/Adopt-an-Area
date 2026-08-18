-- Adopt an Area — the event page, and joining a clean-up without a pin
-- (run once in the Supabase SQL editor, AFTER supabase-events.sql)
--
-- Two things:
--
--   1) An event carries what the host wants to say about it: a few words, a
--      contact for questions, and a video — either a link, or something short
--      they've uploaded from their phone.
--
--   2) A clean-up is a temporary group people should be able to walk into, so
--      the pin isn't the door any more: anybody signed in can join a public
--      event that hasn't happened yet, and the app shows who's coming. Nothing
--      else changes — admins still post the photos, hand out the pin for their
--      other groups, and hold the settings.

-- 1) What the host tells people --------------------------------------------------
alter table public.teams add column if not exists event_info    text;
alter table public.teams add column if not exists event_video   text;
alter table public.teams add column if not exists event_contact text;

grant select (id, name, town_id, created_by, is_public, photos_public,
              logo_url, event_date, event_time, event_lat, event_lng, event_place,
              event_info, event_video, event_contact)
  on public.teams to anon, authenticated;

-- 2) Walking into a clean-up -----------------------------------------------------
-- Public, still to come, and you're signed in: that's the whole gate. A private
-- event stays pin-only, same as any private group.

create or replace function public.join_event(t uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  ev  date;
  pub boolean;
begin
  if auth.uid() is null then
    raise exception 'Sign in first';
  end if;
  select event_date, is_public into ev, pub
    from public.teams where id = t;
  if ev is null then
    raise exception 'That group is not a clean-up event — you need its join pin';
  end if;
  if not coalesce(pub, false) then
    raise exception 'This one is private — ask an admin for the join pin';
  end if;
  if ev < current_date then
    raise exception 'That clean-up has already happened — its photos are still there to look at';
  end if;
  if not exists (select 1 from public.team_members
                  where team_id = t and user_id = auth.uid()) then
    insert into public.team_members (team_id, user_id, member_name, role)
    values (t, auth.uid(),
            coalesce((select name from public.profiles where id = auth.uid()), 'Neighbour'), 'member');
  end if;
  return t;
end;
$$;

grant execute on function public.join_event(uuid) to authenticated;

-- 3) Who's coming ----------------------------------------------------------------
-- The member list of a public group is already readable (supabase-public-groups.sql),
-- so the event page can name the people going and mark which of them are hosts
-- without anything new. This is only here to say so.
