-- Adopt an Area — let the gallery bucket take video (run once in the Supabase SQL
-- editor, only if posting a video comes back with an error)
--
-- The app now offers video wherever it offered a photo: a single clip, or a clip
-- as the before or the after of a pair. Nothing about the gallery_photos table
-- changes — the file goes in the same bucket and the same three columns hold the
-- link. The gallery reads the extension off the link to know it's a video.
--
-- What can still stop it is the bucket itself. A Storage bucket may carry a list
-- of allowed MIME types and a file size ceiling, and if the gallery bucket was
-- created with image types only, a video upload comes back "mime type video/mp4
-- is not supported". This clears the list and sets the ceiling to 50MB, which is
-- what the app tells the uploader and checks for before it starts.
--
-- Check what's there now:
--
--   select id, file_size_limit, allowed_mime_types from storage.buckets;
--
-- allowed_mime_types null means anything goes — which is what an admins-only
-- upload path can afford, since nobody else can post into it.

update storage.buckets
   set allowed_mime_types = null,
       file_size_limit    = 52428800   -- 50MB, in bytes
 where id = 'gallery';

-- The same is worth doing for the group photo wall if you ever want video there.
-- It's a separate bucket with its own settings:
--
--   update storage.buckets
--      set allowed_mime_types = null, file_size_limit = 52428800
--    where id = 'team-photos';
