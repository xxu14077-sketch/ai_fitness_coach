-- Create Posts Table
create table if not exists public.posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  content text,
  image_url text,
  likes_count int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create Comments Table
create table if not exists public.comments (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.posts on delete cascade not null,
  user_id uuid references auth.users, -- Nullable for AI bot
  username text, -- Store display name (e.g. "AI Coach")
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create Likes Table
create table if not exists public.likes (
  post_id uuid references public.posts on delete cascade not null,
  user_id uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (post_id, user_id)
);

-- Enable RLS
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;

-- Policies (Simplified for prototype)
create policy "Public read posts" on public.posts for select using (true);
create policy "Auth insert posts" on public.posts for insert with check (auth.role() = 'authenticated');

create policy "Public read comments" on public.comments for select using (true);
create policy "Auth insert comments" on public.comments for insert with check (true); -- Allow AI simulation to insert

create policy "Public read likes" on public.likes for select using (true);
create policy "Auth insert likes" on public.likes for insert with check (auth.role() = 'authenticated');
create policy "Auth delete likes" on public.likes for delete using (auth.role() = 'authenticated');
