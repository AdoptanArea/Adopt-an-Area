-- Adopt an Area — the paid video spot (run once in the Supabase SQL editor)
--
-- The short advert, the kind the car adverts are made of: the bakkie drives in,
-- the logo lands, ten seconds and it's done. It plays silently down the sides of
-- the Sponsors page on a wide screen, under the intro on a phone, and in a band
-- at the very foot of the home page. Nothing plays until it is on the screen in
-- front of somebody, and nothing ever has sound.
--
-- This is the spot that's worth money. The banner ticker and the logo tiles are
-- a name in passing; a clip is the thing a dealership or a hardware store already
-- has sitting on a hard drive from their radio-and-TV campaign, and it plays here
-- for whoever is looking at the town they sell in.
--
-- Two pieces: a table for the clips, and a bucket to hold the files. Both are the
-- site admin's alone to write to — a sponsor never gets a login, you upload their
-- clip for them under My Area → Video spots.

-- =============================================================================
-- 1) The clips
-- =============================================================================
-- placement decides where it runs, so a cheaper Sponsors-page-only spot and a
-- dearer home-page one are the same row with a different word in it.
--
-- target_towns is the same idea as the banner ticker's: '{all}' plays everywhere,
-- or a list of town ids plays only to people whose town is on it. Unlike the
-- ticker, there's no falling back to everywhere when nothing matches — somebody
-- paying for Humansdorp is paying for Humansdorp, and giving them Cape Town too
-- would be selling the same ten seconds twice.

create table if not exists public.sponsor_videos (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  video_url    text not null,
  poster_url   text,                                    -- optional still frame
  link_url     text,                                    -- optional, opens in a new tab
  placement    text not null default 'both'
               check (placement in ('both','home','side')),
  target_towns text[] not null default '{all}',
  created_at   timestamptz not null default now()
);

alter table public.sponsor_videos enable row level security;

-- Anyone may see them — that is what the sponsor is paying for. Signed in or not.
drop policy if exists "anyone sees the video spots" on public.sponsor_videos;
create policy "anyone sees the video spots"
  on public.sponsor_videos for select
  using (true);

-- Only the site admin puts one up, changes one or takes one down.
drop policy if exists "the admin sells the video spots" on public.sponsor_videos;
create policy "the admin sells the video spots"
  on public.sponsor_videos for all to authenticated
  using (public.is_site_admin())
  with check (public.is_site_admin());

grant select on public.sponsor_videos to anon, authenticated;
grant insert, update, delete on public.sponsor_videos to authenticated;

-- =============================================================================
-- 2) The files
-- =============================================================================
-- A public bucket, 50MB a file, no MIME list — the same settings the gallery
-- bucket ends up with, and safe for the same reason: only the site admin can
-- write to it.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sponsor-videos', 'sponsor-videos', true, 52428800, null)
on conflict (id) do update
  set public = true,
      file_size_limit = 52428800,
      allowed_mime_types = null;

-- NOTE: storage policies are OR'd together. If a blanket "any signed-in user may
-- upload anywhere" policy exists on storage.objects, it will let people past this
-- one — drop it, or this doesn't hold anybody back.

drop policy if exists "anyone watches sponsor videos" on storage.objects;
create policy "anyone watches sponsor videos"
  on storage.objects for select
  using (bucket_id = 'sponsor-videos');

drop policy if exists "the admin uploads sponsor videos" on storage.objects;
create policy "the admin uploads sponsor videos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'sponsor-videos' and public.is_site_admin());

drop policy if exists "the admin replaces sponsor videos" on storage.objects;
create policy "the admin replaces sponsor videos"
  on storage.objects for update to authenticated
  using (bucket_id = 'sponsor-videos' and public.is_site_admin())
  with check (bucket_id = 'sponsor-videos' and public.is_site_admin());

drop policy if exists "the admin removes sponsor videos" on storage.objects;
create policy "the admin removes sponsor videos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'sponsor-videos' and public.is_site_admin());

-- =============================================================================
-- 3) Until somebody buys one
-- =============================================================================
-- With the table empty, the home page band is gone altogether — an empty advert
-- slot on the front page looks worse than no advert at all — and the Sponsors
-- page shows a dashed "your clip could run here" card in its place. Deleting the
-- last row puts it back to exactly that.
--
-- Taking a clip down does not delete the file. To clear the file out too, remove
-- it under Storage → sponsor-videos in the Supabase dashboard.
