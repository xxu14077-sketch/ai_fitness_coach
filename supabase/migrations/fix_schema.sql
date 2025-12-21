-- 1. Create body_metrics table if not exists
create table if not exists body_metrics (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date default current_date not null,
  weight_kg numeric not null,
  body_fat_pct numeric,
  created_at timestamptz default now()
);

-- 2. Create strength_progress table if not exists
create table if not exists strength_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date default current_date not null,
  exercise text not null,
  weight_kg numeric not null,
  created_at timestamptz default now()
);

-- 3. Enable RLS
alter table body_metrics enable row level security;
alter table strength_progress enable row level security;

-- 4. Create Policies (Drop existing to avoid errors)
drop policy if exists "Users can view own body metrics" on body_metrics;
drop policy if exists "Users can insert own body metrics" on body_metrics;
drop policy if exists "Users can update own body metrics" on body_metrics;
drop policy if exists "Users can delete own body metrics" on body_metrics;

create policy "Users can view own body metrics" on body_metrics for select using (auth.uid() = user_id);
create policy "Users can insert own body metrics" on body_metrics for insert with check (auth.uid() = user_id);
create policy "Users can update own body metrics" on body_metrics for update using (auth.uid() = user_id);
create policy "Users can delete own body metrics" on body_metrics for delete using (auth.uid() = user_id);

drop policy if exists "Users can view own strength logs" on strength_progress;
drop policy if exists "Users can insert own strength logs" on strength_progress;
drop policy if exists "Users can update own strength logs" on strength_progress;
drop policy if exists "Users can delete own strength logs" on strength_progress;

create policy "Users can view own strength logs" on strength_progress for select using (auth.uid() = user_id);
create policy "Users can insert own strength logs" on strength_progress for insert with check (auth.uid() = user_id);
create policy "Users can update own strength logs" on strength_progress for update using (auth.uid() = user_id);
create policy "Users can delete own strength logs" on strength_progress for delete using (auth.uid() = user_id);

-- 5. Clean up duplicates (Keep the latest one)
delete from body_metrics a using body_metrics b
where a.user_id = b.user_id and a.date = b.date and a.created_at < b.created_at;

delete from strength_progress a using strength_progress b
where a.user_id = b.user_id and a.date = b.date and a.exercise = b.exercise and a.created_at < b.created_at;

-- 6. Add Unique Constraints (Safe way)
alter table body_metrics drop constraint if exists body_metrics_user_date_key;
alter table body_metrics add constraint body_metrics_user_date_key unique (user_id, date);

alter table strength_progress drop constraint if exists strength_progress_user_date_exercise_key;
alter table strength_progress add constraint strength_progress_user_date_exercise_key unique (user_id, date, exercise);
