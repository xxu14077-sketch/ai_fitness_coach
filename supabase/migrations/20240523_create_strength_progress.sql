create table if not exists strength_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date default current_date not null,
  exercise text not null, -- 'bench', 'squat', 'deadlift'
  weight_kg numeric not null,
  created_at timestamptz default now()
);

alter table strength_progress enable row level security;

create policy "Users can view own strength logs" 
  on strength_progress for select 
  using (auth.uid() = user_id);

create policy "Users can insert own strength logs" 
  on strength_progress for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own strength logs" 
  on strength_progress for update 
  using (auth.uid() = user_id);

create policy "Users can delete own strength logs" 
  on strength_progress for delete 
  using (auth.uid() = user_id);
