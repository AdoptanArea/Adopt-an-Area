-- Adopt an Area — deleting a group (run once in the Supabase SQL editor,
-- AFTER supabase-many-groups.sql)
--
-- The only admin of a group can't simply walk away — the group would be left
-- with nobody able to post, share the pin or hand the badge on. So the app
-- offers them the two honest ways out: make somebody else an admin, or end the
-- group. This is the second one.
--
-- Deletion is total and deliberate: the photo rows, the image files, the
-- membership list and the group itself. An admin is the only one who can do it.
--
-- Safe to re-run: it replaces the function and its policies rather than adding
-- to them.

-- 1) The image files ----------------------------------------------------------
-- These CANNOT be deleted from SQL. Supabase guards storage.objects and answers
-- "Direct deletion from storage tables is not allowed. Use the Storage API
-- instead." So the app clears the folder with sb.storage.remove() first, and
-- these two policies are what let an admin do that:
--   * select, so it can list what's in the group's folder
--   * delete, so it can remove what it found
-- Both are scoped by the first folder of the path, which the app sets to the
-- group's id when it uploads ("<group id>/<file>").

drop policy if exists "admins list team photo files" on storage.objects;
create policy "admins list team photo files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'team-photos'
    and case
          when (storage.foldername(name))[1] ~*
               '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then public.is_team_admin(((storage.foldername(name))[1])::uuid)
          else false
        end
  );

drop policy if exists "admins delete team photo files" on storage.objects;
create policy "admins delete team photo files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'team-photos'
    and case
          when (storage.foldername(name))[1] ~*
               '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then public.is_team_admin(((storage.foldername(name))[1])::uuid)
          else false
        end
  );

-- 2) Everything else ----------------------------------------------------------
-- The rows are ours to delete. Note the order the app works in: files first,
-- while it can still prove the caller is an admin of that group — this function
-- removes the membership that proof rests on.

create or replace function public.delete_team(t uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_team_admin(t) then
    raise exception 'Only a group admin can delete a group';
  end if;

  delete from public.team_photos  where team_id = t;
  delete from public.team_members where team_id = t;
  delete from public.teams        where id = t;
end;
$$;

grant execute on function public.delete_team(uuid) to authenticated;
