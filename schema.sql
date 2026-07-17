-- Poker Ledger schema — run this in Supabase SQL Editor

create table settings (
  id int primary key default 1 check (id = 1),
  chips_per_buyin numeric not null default 100,
  inr_per_chip numeric not null default 1
);
insert into settings (id) values (1);

create table players (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table games (
  id uuid primary key default gen_random_uuid(),
  name text,
  date date not null default current_date,
  inr_per_chip numeric not null,
  chips_per_buyin numeric not null,
  status text not null default 'live' check (status in ('live','done')),
  created_at timestamptz not null default now()
);

create table game_entries (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  player_id uuid not null references players(id),
  buy_ins int not null default 1 check (buy_ins >= 0),
  final_chips numeric,
  created_at timestamptz not null default now(),
  unique (game_id, player_id)
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  date date not null default current_date,
  from_id uuid not null references players(id),
  to_id uuid not null references players(id),
  amount numeric not null check (amount > 0),
  note text,
  created_at timestamptz not null default now()
);

-- Open access via anon key (fine for a private friends-group tool;
-- anyone with the URL/key can read & write).
alter table settings enable row level security;
alter table players enable row level security;
alter table games enable row level security;
alter table game_entries enable row level security;
alter table payments enable row level security;

create policy "open" on settings for all using (true) with check (true);
create policy "open" on players for all using (true) with check (true);
create policy "open" on games for all using (true) with check (true);
create policy "open" on game_entries for all using (true) with check (true);
create policy "open" on payments for all using (true) with check (true);

-- Realtime: push changes to all connected clients
alter publication supabase_realtime add table settings, players, games, game_entries, payments;
