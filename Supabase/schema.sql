-- Run this in Supabase Dashboard → SQL Editor to create tables and RLS for Great Reset Fantasy.
-- Replace with your project as needed.

-- Polls (owner = auth user who created the poll)
create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  created_at timestamptz not null default now(),
  owner_id uuid not null references auth.users(id) on delete cascade
);

-- Options for each poll
create table if not exists public.poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  text text not null,
  votes_count int not null default 0
);

-- One vote per user per poll (user_id = auth user)
create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_id uuid not null references public.poll_options(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, poll_id)
);

-- RLS: enable
alter table public.polls enable row level security;
alter table public.poll_options enable row level security;
alter table public.votes enable row level security;

-- Polls: users can do everything on their own polls
drop policy if exists "Users can manage own polls" on public.polls;
create policy "Users can manage own polls"
  on public.polls for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Poll options: readable/insertable/updatable in context of own polls
drop policy if exists "Users can manage options of own polls" on public.poll_options;
create policy "Users can manage options of own polls"
  on public.poll_options for all
  using (
    exists (select 1 from public.polls p where p.id = poll_id and p.owner_id = auth.uid())
  )
  with check (
    exists (select 1 from public.polls p where p.id = poll_id and p.owner_id = auth.uid())
  );

-- Votes: users can insert their own vote and read their own votes
drop policy if exists "Users can insert own vote" on public.votes;
create policy "Users can insert own vote"
  on public.votes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own votes" on public.votes;
create policy "Users can read own votes"
  on public.votes for select
  using (auth.uid() = user_id);

-- Allow anyone to read all polls and options (so everyone can see and vote; only owner can edit/delete)
drop policy if exists "Anyone can read polls" on public.polls;
create policy "Anyone can read polls"
  on public.polls for select
  using (true);

drop policy if exists "Anyone can read poll_options" on public.poll_options;
create policy "Anyone can read poll_options"
  on public.poll_options for select
  using (true);

-- Indexes for common queries
create index if not exists idx_polls_owner_id on public.polls(owner_id);
create index if not exists idx_poll_options_poll_id on public.poll_options(poll_id);
create index if not exists idx_votes_user_id on public.votes(user_id);
create index if not exists idx_votes_poll_id on public.votes(poll_id);

-- Trigger: when a vote is inserted, increment the option's votes_count (avoids RLS: only owner could update options otherwise)
create or replace function public.increment_option_votes_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.poll_options
  set votes_count = votes_count + 1
  where id = new.option_id;
  return new;
end;
$$;
drop trigger if exists on_vote_insert_increment_count on public.votes;
create trigger on_vote_insert_increment_count
  after insert on public.votes
  for each row execute function public.increment_option_votes_count();

-- Admins: only these users can update calculator config. Add your auth user id from Supabase Dashboard → Authentication → Users.
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admin_users enable row level security;
drop policy if exists "Authenticated can read admin list" on public.admin_users;
create policy "Authenticated can read admin list"
  on public.admin_users for select
  using (auth.uid() is not null);

drop policy if exists "Admins can insert admin_users" on public.admin_users;
create policy "Admins can insert admin_users"
  on public.admin_users for insert
  with check (auth.uid() in (select user_id from public.admin_users));

drop policy if exists "Admins can delete admin_users" on public.admin_users;
create policy "Admins can delete admin_users"
  on public.admin_users for delete
  using (auth.uid() in (select user_id from public.admin_users));
-- Note: First admin must be added via SQL Editor: insert into public.admin_users (user_id) values ('your-user-uuid');

-- Calculator config (single row of global constants)
create table if not exists public.calculator_globals (
  id int primary key default 1 check (id = 1),
  total_wealth double precision not null default 500000000000000,
  world_population double precision not null default 8000000000,
  poverty_line_per_person double precision not null default 10000,
  updated_at timestamptz not null default now()
);

-- Wealth brackets (top1, next9, middle40, bottom50)
create table if not exists public.wealth_brackets (
  id uuid primary key default gen_random_uuid(),
  bracket text not null unique,
  wealth_share double precision not null,
  population_share double precision not null,
  vulnerability double precision not null default 0.5,
  sort_order int not null default 0
);

-- Reset scenarios (Before Reset, Mild, etc.)
create table if not exists public.reset_scenarios (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  zeros_cut int not null,
  sort_order int not null default 0
);

-- RLS: calculator tables readable by all; only admins (in admin_users) can update
alter table public.calculator_globals enable row level security;
alter table public.wealth_brackets enable row level security;
alter table public.reset_scenarios enable row level security;

drop policy if exists "Anyone can read calculator_globals" on public.calculator_globals;
create policy "Anyone can read calculator_globals"
  on public.calculator_globals for select using (true);

drop policy if exists "Admins can update calculator_globals" on public.calculator_globals;
create policy "Admins can update calculator_globals"
  on public.calculator_globals for all
  using (auth.uid() in (select user_id from public.admin_users))
  with check (auth.uid() in (select user_id from public.admin_users));

drop policy if exists "Anyone can read wealth_brackets" on public.wealth_brackets;
create policy "Anyone can read wealth_brackets"
  on public.wealth_brackets for select using (true);

drop policy if exists "Admins can manage wealth_brackets" on public.wealth_brackets;
create policy "Admins can manage wealth_brackets"
  on public.wealth_brackets for all
  using (auth.uid() in (select user_id from public.admin_users))
  with check (auth.uid() in (select user_id from public.admin_users));

drop policy if exists "Anyone can read reset_scenarios" on public.reset_scenarios;
create policy "Anyone can read reset_scenarios"
  on public.reset_scenarios for select using (true);

drop policy if exists "Admins can manage reset_scenarios" on public.reset_scenarios;
create policy "Admins can manage reset_scenarios"
  on public.reset_scenarios for all
  using (auth.uid() in (select user_id from public.admin_users))
  with check (auth.uid() in (select user_id from public.admin_users));

-- Seed default calculator data (run once)
insert into public.calculator_globals (id, total_wealth, world_population, poverty_line_per_person)
values (1, 500000000000000, 8000000000, 10000)
on conflict (id) do nothing;

insert into public.wealth_brackets (bracket, wealth_share, population_share, vulnerability, sort_order)
values
  ('top1', 43, 1, 0.2, 0),
  ('next9', 52, 9, 0.4, 1),
  ('middle40', 14, 40, 0.8, 2),
  ('bottom50', 1, 50, 1.2, 3)
on conflict (bracket) do nothing;

insert into public.reset_scenarios (label, zeros_cut, sort_order)
values
  ('Pre', 0, 0),
  ('Mild', 3, 1),
  ('Moderate', 6, 2),
  ('Severe', 9, 3)
on conflict (label) do nothing;

-- User accounts: all account data in one table (extends auth.users)
-- Includes display name, avatar, streaks — synced across devices
create table if not exists public.user_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text default '',
  avatar_label text default 'GR',
  avatar_url text,
  visit_streak int not null default 0,
  poll_streak int not null default 0,
  share_streak int not null default 0,
  last_visit_date timestamptz,
  last_poll_date timestamptz,
  last_share_date timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_accounts enable row level security;

drop policy if exists "Users can insert own account" on public.user_accounts;
create policy "Users can insert own account"
  on public.user_accounts for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own account" on public.user_accounts;
create policy "Users can update own account"
  on public.user_accounts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Anyone can read accounts (so poll authors' names/avatars and streaks are visible)
drop policy if exists "Anyone can read user_accounts" on public.user_accounts;
create policy "Anyone can read user_accounts"
  on public.user_accounts for select
  using (true);

create index if not exists idx_user_accounts_user_id on public.user_accounts(user_id);

-- Storage: Create "avatars" bucket in Dashboard → Storage → New bucket
-- Set Public: yes, Max file size: 10MB, Allowed types: image/jpeg, image/png, image/webp
-- Add policy: "Authenticated users can upload" on storage.objects for insert with check (bucket_id = 'avatars')

-- Allow authenticated users to upload to avatars bucket
create policy "Authenticated users can upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars');

-- Allow public read access (needed for public bucket to serve images)
create policy "Public read access for avatars"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Allow overwriting existing avatar (required when upload uses upsert: true)
create policy "Authenticated users can update avatars"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars')
  with check (bucket_id = 'avatars');
