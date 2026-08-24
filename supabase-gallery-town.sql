-- Adopt an Area — which town a gallery photo is from (run once in the Supabase
-- SQL editor)
--
-- The photo wall is one long wall. Everything anyone has ever done is on it, in the
-- order it was posted, and the more of it there is the less any of it is about the
-- person looking. Somebody in Humansdorp opening the Gallery wants Humansdorp first,
-- and the rest of the country when they go looking for it.
--
-- Nothing on the row said where the photo was taken, so there was nothing to sort it
-- by. This adds that one thing.

alter table public.gallery_photos
  add column if not exists town_id text;

-- Nulls are allowed on purpose. Every photo already up was posted without a town and
-- stays that way — those show under "Everywhere in South Africa", which is where they
-- were before this ran. The app leaves the town filter out altogether until at least
-- one photo carries a town, so the wall looks exactly as it does now until you start
-- filling it in.
--
-- Same keys as everywhere else — the slug the app makes from the town name, so
-- 'humansdorp', 'kruisfontein'. The posting form picks it from the same list of towns
-- the map uses, defaulting to whoever is posting, so nothing has to be typed by hand.

-- Going back over what's already there, if you want the old photos filed too:
--
--   select id, caption, who, town_id from public.gallery_photos order by created_at;
--   update public.gallery_photos set town_id = 'humansdorp' where id = '<the id>';
--
-- Worth doing for the ones you know, and no harm in leaving the rest — a photo with
-- no town is still on the wall, it just isn't claimed by a particular place.

-- Reading the wall is public and stays public; this column changes nothing about who
-- may post or delete. See supabase-trusted-posters.sql for those rules.
