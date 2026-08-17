-- Adopt an Area — public groups (run this once in the Supabase SQL editor)
--
-- Adds the "public viewing" choice to teams, and opens up just enough reading for
-- the Gallery search to work: a public team, who's in it, and its photos.
-- Private teams are untouched — nothing outside the team can read them.
--
-- NOTE: this assumes teams.id is a uuid (the Supabase default). If your ids are
-- bigint, change the `uuid` argument type in the two functions below to `bigint`.

-- 1) The column the "Public / Private" picker writes to ------------------------
alter table public.teams
  add column if not exists is_public boolean not null default false;

-- 2) Helper functions ---------------------------------------------------------
-- These run as SECURITY DEFINER so they skip row-level security themselves.
-- That matters: a policy on team_members that queried teams directly (while a
-- policy on teams queried team_members) would recurse forever and every query
-- would error out.

create or replace function public.is_team_member(t uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = t and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_team_public(t uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_public from public.teams where id = t), false);
$$;

grant execute on function public.is_team_member(uuid) to anon, authenticated;
grant execute on function public.is_team_public(uuid) to anon, authenticated;

-- 3) Policies -----------------------------------------------------------------
-- Multiple SELECT policies are OR'd together, so these sit alongside whatever
-- you already have rather than replacing it.

alter table public.teams        enable row level security;
alter table public.team_members enable row level security;
alter table public.team_photos  enable row level security;

-- Anyone may read a team that chose public; members may always read their own.
drop policy if exists "read public or own team" on public.teams;
create policy "read public or own team"
  on public.teams for select
  using (is_public or public.is_team_member(id));

-- Only whoever created the team can flip it public/private.
drop policy if exists "creator updates own team" on public.teams;
create policy "creator updates own team"
  on public.teams for update
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

-- Member list of a public team is readable (the Gallery uses it to work out
-- which claimed areas belong to the group).
drop policy if exists "read members of public or own team" on public.team_members;
create policy "read members of public or own team"
  on public.team_members for select
  using (public.is_team_public(team_id) or public.is_team_member(team_id));

-- Photos of a public team are readable by anyone.
drop policy if exists "read photos of public or own team" on public.team_photos;
create policy "read photos of public or own team"
  on public.team_photos for select
  using (public.is_team_public(team_id) or public.is_team_member(team_id));

-- 4) Storage ------------------------------------------------------------------
-- The app builds photo links with getPublicUrl(), so the "team-photos" bucket
-- must be marked public for outsiders to actually see the images:
--   update storage.buckets set public = true where id = 'team-photos';
