-- 1. Create daily_checkins table for DAU tracking
create table if not exists daily_checkins (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date default current_date not null,
  created_at timestamptz default now(),
  unique(user_id, date)
);

-- 2. Add RLS for checkins
alter table daily_checkins enable row level security;
create policy "Users can manage own checkins" on daily_checkins for all using (auth.uid() = user_id);

-- 3. Add weekly goal to user_settings
alter table user_settings add column if not exists weekly_workout_goal int default 3;

-- 4. Create achievements table (optional, but good for tracking unlock time)
create table if not exists user_achievements (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  achievement_id text not null, -- 'streak_7', 'streak_30', 'streak_100'
  unlocked_at timestamptz default now(),
  unique(user_id, achievement_id)
);

alter table user_achievements enable row level security;
create policy "Users can view own achievements" on user_achievements for select using (auth.uid() = user_id);
create policy "Users can insert own achievements" on user_achievements for insert with check (auth.uid() = user_id);
