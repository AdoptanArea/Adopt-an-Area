-- Adopt an Area — belong to more than one group (run once in the Supabase SQL
-- editor, AFTER supabase-group-admins.sql)
--
-- The app used to assume one group per person: it asked team_members for your
-- single row and stopped there. Now it asks for all of them. If the table was
-- built with user_id as its primary key — or with a unique index on user_id —
-- the database would still refuse the second group, so that restriction has to
-- go, replaced by "one row per person PER group".
--
-- Safe to run whether or not such a constraint exists: the block below looks
-- for one and does nothing if there isn't.

do $$
declare
  r record;
  ucols text[];
begin
  -- Unique or primary-key CONSTRAINTS whose column list is exactly (user_id)
  for r in
    select c.conname
      from pg_constraint c
      join pg_class     t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and t.relname = 'team_members'
       and c.contype in ('p','u')
  loop
    select array_agg(a.attname::text order by a.attname) into ucols
      from pg_constraint c2
      join unnest(c2.conkey) k on true
      join pg_attribute a on a.attrelid = c2.conrelid and a.attnum = k
     where c2.conname = r.conname and c2.conrelid = 'public.team_members'::regclass;
    if ucols = array['user_id'] then
      raise notice 'dropping constraint % — it allowed only one group per person', r.conname;
      execute format('alter table public.team_members drop constraint %I', r.conname);
    end if;
  end loop;

  -- Free-standing unique INDEXES on (user_id), same idea
  for r in
    select i.relname as idxname,
           (select array_agg(a.attname::text order by a.attname)
              from unnest(string_to_array(x.indkey::text, ' ')::int[]) k
              join pg_attribute a on a.attrelid = x.indrelid and a.attnum = k) as cols
      from pg_index   x
      join pg_class   i on i.oid = x.indexrelid
      join pg_class   t on t.oid = x.indrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and t.relname = 'team_members'
       and x.indisunique
       and not x.indisprimary
  loop
    if r.cols = array['user_id'] then
      raise notice 'dropping index % — it allowed only one group per person', r.idxname;
      execute format('drop index public.%I', r.idxname);
    end if;
  end loop;
end $$;

-- What we do want: you can be in many groups, but only once in each.
create unique index if not exists team_members_team_user_uidx
  on public.team_members (team_id, user_id);

-- Leaving --------------------------------------------------------------------
-- Being in several groups means being able to get out of one. Same rule as
-- stepping down as admin: the last admin can't walk away and leave a group with
-- nobody able to post, share the pin, or promote a replacement.

create or replace function public.leave_team(t uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  my_role text;
  admin_count int;
begin
  select role into my_role
    from public.team_members
   where team_id = t and user_id = auth.uid();
  if my_role is null then
    raise exception 'You are not in that group';
  end if;
  if my_role = 'admin' then
    select count(*) into admin_count
      from public.team_members where team_id = t and role = 'admin';
    if admin_count <= 1 then
      raise exception 'You are this group''s only admin — make somebody else an admin before you go';
    end if;
  end if;
  delete from public.team_members
   where team_id = t and user_id = auth.uid();
end;
$$;

grant execute on function public.leave_team(uuid) to authenticated;
