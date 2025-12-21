-- 5. User Profiles
create table if not exists user_profiles (
  user_id uuid references auth.users not null primary key,
  display_name text,
  birth_year int,
  gender text check (gender in ('male', 'female', 'other')),
  height_cm int,
  target_weight_kg float,
  primary_goal text, -- 'muscle_gain', 'fat_loss', 'strength', 'endurance'
  activity_level text, -- 'sedentary', 'light', 'moderate', 'active', 'very_active'
  dietary_preferences text[], -- 'vegan', 'keto', etc.
  injuries text,
  equipment text[],
  updated_at timestamp with time zone default timezone('utc'::text, now())
);
alter table user_profiles enable row level security;
create policy "Users can view own profile" on user_profiles for select using (auth.uid() = user_id);
create policy "Users can insert own profile" on user_profiles for insert with check (auth.uid() = user_id);
create policy "Users can update own profile" on user_profiles for update using (auth.uid() = user_id);

-- 6. Body Metrics (Weight, etc.)
create table if not exists body_metrics (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  date date not null default CURRENT_DATE,
  weight_kg float,
  body_fat_pct float,
  muscle_mass_kg float,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);
alter table body_metrics enable row level security;
create policy "Users can view own metrics" on body_metrics for select using (auth.uid() = user_id);
create policy "Users can insert own metrics" on body_metrics for insert with check (auth.uid() = user_id);
create policy "Users can update own metrics" on body_metrics for update using (auth.uid() = user_id);
create policy "Users can delete own metrics" on body_metrics for delete using (auth.uid() = user_id);
