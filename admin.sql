-- Admin password protection for destructive actions.
-- 1. Replace CHANGE_ME below with your admin password.
-- 2. Run this whole file in the Supabase SQL Editor.
-- Safe to re-run: it will not overwrite an already-set password.

create extension if not exists pgcrypto with schema extensions;

-- Password store: RLS enabled with NO policies = anon can never read/write it.
create table if not exists admin_config (
  id int primary key default 1 check (id = 1),
  password_hash text not null
);
alter table admin_config enable row level security;

insert into admin_config (id, password_hash)
values (1, extensions.crypt('CHANGE_ME', extensions.gen_salt('bf')))
on conflict (id) do nothing;

create or replace function check_admin(pwd text) returns boolean
language sql security definer set search_path = public, extensions as $$
  select exists (
    select 1 from admin_config
    where id = 1 and password_hash = crypt(pwd, password_hash)
  );
$$;

-- Remove open DELETE access on games, players, payments.
drop policy if exists "open" on games;
drop policy if exists "games_select" on games;
drop policy if exists "games_insert" on games;
drop policy if exists "games_update" on games;
create policy "games_select" on games for select using (true);
create policy "games_insert" on games for insert with check (true);
create policy "games_update" on games for update using (true) with check (true);

drop policy if exists "open" on players;
drop policy if exists "players_select" on players;
drop policy if exists "players_insert" on players;
drop policy if exists "players_update" on players;
create policy "players_select" on players for select using (true);
create policy "players_insert" on players for insert with check (true);
create policy "players_update" on players for update using (true) with check (true);

drop policy if exists "open" on payments;
drop policy if exists "payments_select" on payments;
drop policy if exists "payments_insert" on payments;
create policy "payments_select" on payments for select using (true);
create policy "payments_insert" on payments for insert with check (true);

-- Block reopening (done -> live) except via the admin function.
create or replace function guard_game_reopen() returns trigger
language plpgsql as $$
begin
  if old.status = 'done' and new.status = 'live'
     and coalesce(current_setting('app.is_admin', true), '') <> 'on' then
    raise exception 'Admin password required to reopen a game';
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_reopen on games;
create trigger trg_guard_reopen before update on games
for each row execute function guard_game_reopen();

-- Admin-only actions (security definer bypasses RLS after password check).
create or replace function admin_delete_game(gid uuid, pwd text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not check_admin(pwd) then raise exception 'Wrong admin password'; end if;
  delete from games where id = gid;
end $$;

create or replace function admin_reopen_game(gid uuid, pwd text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not check_admin(pwd) then raise exception 'Wrong admin password'; end if;
  perform set_config('app.is_admin', 'on', true);
  update games set status = 'live' where id = gid;
end $$;

create or replace function admin_delete_player(pid uuid, pwd text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not check_admin(pwd) then raise exception 'Wrong admin password'; end if;
  delete from players where id = pid;
end $$;

create or replace function admin_delete_payment(pay_id uuid, pwd text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not check_admin(pwd) then raise exception 'Wrong admin password'; end if;
  delete from payments where id = pay_id;
end $$;

-- Change the admin password later (needs current password):
create or replace function admin_change_password(old_pwd text, new_pwd text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not check_admin(old_pwd) then raise exception 'Wrong admin password'; end if;
  update admin_config set password_hash = crypt(new_pwd, gen_salt('bf')) where id = 1;
end $$;
