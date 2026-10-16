create function public.current_user_is_pro()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select is_pro from public.profiles where id = (select auth.uid())),
    false
  );
$$;

create function public.sync_guard()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at <= old.updated_at then
    return null;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

create table public.workouts (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  note text,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  unique (id, user_id)
);

create table public.workout_exercises (
  id uuid primary key,
  user_id uuid not null,
  workout_id uuid not null,
  exercise_id uuid not null,
  position integer not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  unique (id, user_id),
  foreign key (workout_id, user_id)
    references public.workouts (id, user_id) on delete cascade
);

create table public.set_entries (
  id uuid primary key,
  user_id uuid not null,
  workout_exercise_id uuid not null,
  position integer not null,
  reps integer not null,
  weight double precision not null,
  weight_unit text not null,
  rpe double precision,
  is_warmup boolean not null,
  is_completed boolean not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  foreign key (workout_exercise_id, user_id)
    references public.workout_exercises (id, user_id) on delete cascade
);

create index workouts_sync_idx on public.workouts (user_id, server_updated_at);
create index workout_exercises_sync_idx on public.workout_exercises (user_id, server_updated_at);
create index set_entries_sync_idx on public.set_entries (user_id, server_updated_at);

create trigger workouts_sync_guard
  before insert or update on public.workouts
  for each row execute function public.sync_guard();
create trigger workout_exercises_sync_guard
  before insert or update on public.workout_exercises
  for each row execute function public.sync_guard();
create trigger set_entries_sync_guard
  before insert or update on public.set_entries
  for each row execute function public.sync_guard();

alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.set_entries enable row level security;

create policy "workouts_select_own" on public.workouts
  for select to authenticated using (user_id = (select auth.uid()));
create policy "workouts_insert_pro" on public.workouts
  for insert to authenticated
  with check (user_id = (select auth.uid()) and public.current_user_is_pro());
create policy "workouts_update_pro" on public.workouts
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.current_user_is_pro());

create policy "workout_exercises_select_own" on public.workout_exercises
  for select to authenticated using (user_id = (select auth.uid()));
create policy "workout_exercises_insert_pro" on public.workout_exercises
  for insert to authenticated
  with check (user_id = (select auth.uid()) and public.current_user_is_pro());
create policy "workout_exercises_update_pro" on public.workout_exercises
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.current_user_is_pro());

create policy "set_entries_select_own" on public.set_entries
  for select to authenticated using (user_id = (select auth.uid()));
create policy "set_entries_insert_pro" on public.set_entries
  for insert to authenticated
  with check (user_id = (select auth.uid()) and public.current_user_is_pro());
create policy "set_entries_update_pro" on public.set_entries
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.current_user_is_pro());

grant select, insert, update on public.workouts to authenticated;
grant select, insert, update on public.workout_exercises to authenticated;
grant select, insert, update on public.set_entries to authenticated;
grant all on public.workouts to service_role;
grant all on public.workout_exercises to service_role;
grant all on public.set_entries to service_role;
