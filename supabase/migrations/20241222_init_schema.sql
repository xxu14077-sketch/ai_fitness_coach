-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. User Settings Table
create table if not exists user_settings (
  user_id uuid references auth.users not null primary key,
  ai_api_key text,
  ai_base_url text,
  ai_system_prompt text,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table user_settings enable row level security;

create policy "Users can view own settings" 
  on user_settings for select 
  using (auth.uid() = user_id);

create policy "Users can insert own settings" 
  on user_settings for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own settings" 
  on user_settings for update 
  using (auth.uid() = user_id);

-- 2. Chat Sessions Table
create table if not exists chat_sessions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  title text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  last_updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table chat_sessions enable row level security;

create policy "Users can view own sessions" 
  on chat_sessions for select 
  using (auth.uid() = user_id);

create policy "Users can insert own sessions" 
  on chat_sessions for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own sessions" 
  on chat_sessions for update 
  using (auth.uid() = user_id);

create policy "Users can delete own sessions" 
  on chat_sessions for delete 
  using (auth.uid() = user_id);

-- 3. Chat Messages Table
create table if not exists chat_messages (
  id uuid default uuid_generate_v4() primary key,
  session_id uuid references chat_sessions on delete cascade not null,
  user_id uuid references auth.users not null,
  role text not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

alter table chat_messages enable row level security;

create policy "Users can view own messages" 
  on chat_messages for select 
  using (auth.uid() = user_id);

create policy "Users can insert own messages" 
  on chat_messages for insert 
  with check (auth.uid() = user_id);

-- 4. Knowledge Base Table
create table if not exists knowledge_base (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  content text not null,
  keywords text[],
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

alter table knowledge_base enable row level security;

create policy "Users can view own knowledge" 
  on knowledge_base for select 
  using (auth.uid() = user_id);

create policy "Users can insert own knowledge" 
  on knowledge_base for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own knowledge" 
  on knowledge_base for update 
  using (auth.uid() = user_id);

create policy "Users can delete own knowledge" 
  on knowledge_base for delete 
  using (auth.uid() = user_id);
