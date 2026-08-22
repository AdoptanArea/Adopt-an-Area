-- Adopt an Area — the brown "other" claim, and the end of grey (run once in the
-- Supabase SQL editor)
--
-- Two changes to what a claimed area can be.
--
--   1) GREY IS GONE. Grey meant "available — nobody has claimed it", which put a
--      colour on the map for a thing nobody was doing. An unclaimed area is what
--      a blank map already shows. Letting go of an area now takes it off the map
--      instead of turning it grey.
--
--   2) BROWN IS NEW. Green, orange and red describe how much of a place somebody
--      has taken on. Brown is the one that was missing: a particular job rather
--      than the whole place — the storm water pipes, the overgrown hedge, the
--      grass, the trees. Whoever claims it ticks which jobs, and those tick boxes
--      are stored here in other_jobs.
--
-- The app already hides any row whose status it doesn't recognise, so nothing on
-- the site looks broken before or after this runs. What this does is make the new
-- kind saveable, and give you the line to clear out the old grey rows for good.

-- =============================================================================
-- 1) The jobs behind "other"
-- =============================================================================
-- Keys, not labels: 'grass' stays 'grass' in the database however the wording on
-- the screen changes. The list of them lives in the app (OTHER_JOBS in index.html)
-- — adding one there is the whole job, nothing here needs touching again.

alter table public.areas
  add column if not exists other_jobs text[] not null default '{}';

-- =============================================================================
-- 2) Letting brown through
-- =============================================================================
-- The areas table may or may not carry a check constraint on status, depending on
-- how it was made. If it does, and it was written before brown existed, an "other"
-- claim comes back as a constraint violation. This drops whatever check is on
-- status and puts back one that knows the four kinds.

do $$
declare
  c record;
begin
  for c in
    select con.conname
      from pg_constraint con
      join pg_class rel on rel.oid = con.conrelid
      join pg_namespace ns on ns.oid = rel.relnamespace
     where ns.nspname = 'public'
       and rel.relname = 'areas'
       and con.contype = 'c'
       and pg_get_constraintdef(con.oid) ilike '%status%'
  loop
    execute format('alter table public.areas drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.areas
  add constraint areas_status_check
  check (status in ('green','orange','red','brown'));

-- =============================================================================
-- 3) The grey rows that are already there
-- =============================================================================
-- Areas somebody released back when releasing meant "turn it grey". The app leaves
-- them out of everything now, so they are invisible either way — but they will sit
-- in the table until you say otherwise, and the constraint above was added AFTER
-- them, so it doesn't complain about rows that already exist.
--
-- See how many there are:
--
--   select count(*) from public.areas where status = 'gray';
--
-- Clear them out, when you're happy to lose the names on them:
--
--   delete from public.areas where status = 'gray';
--
-- Nothing else refers to those rows, so nothing else changes when they go.
