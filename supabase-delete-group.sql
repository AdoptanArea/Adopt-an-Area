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

  -- The image files, before the rows that point at them — once the rows are
  -- gone there's nothing left to say which files belonged to this group. The
  -- app uploads to "<group id>/<file>", so the first folder is the group.
  delete from storage.objects
   where bucket_id = 'team-photos'
     and (storage.foldername(name))[1] = t::text;

  delete from public.team_photos  where team_id = t;
  delete from public.team_members where team_id = t;
  delete from public.teams        where id = t;
end;
$$;

grant execute on function public.delete_team(uuid) to authenticated;
