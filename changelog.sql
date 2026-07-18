-- Changelog: records every insert/update/delete on all data tables.
-- Run this in the Supabase SQL Editor. Safe to re-run.

create table if not exists changelog (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  table_name text not null,
  op text not null,
  old_row jsonb,
  new_row jsonb
);

-- Read-only for the app: no insert/update/delete policies.
alter table changelog enable row level security;
drop policy if exists "changelog_select" on changelog;
create policy "changelog_select" on changelog for select using (true);

-- Trigger function runs as owner (security definer) so it can write
-- to changelog even though the app role cannot.
create or replace function log_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into changelog (table_name, op, old_row, new_row)
  values (
    tg_table_name,
    tg_op,
    case when tg_op <> 'INSERT' then to_jsonb(old) end,
    case when tg_op <> 'DELETE' then to_jsonb(new) end
  );
  return coalesce(new, old);
end $$;

drop trigger if exists trg_log_players on players;
create trigger trg_log_players after insert or update or delete on players
for each row execute function log_change();

drop trigger if exists trg_log_games on games;
create trigger trg_log_games after insert or update or delete on games
for each row execute function log_change();

drop trigger if exists trg_log_entries on game_entries;
create trigger trg_log_entries after insert or update or delete on game_entries
for each row execute function log_change();

drop trigger if exists trg_log_payments on payments;
create trigger trg_log_payments after insert or update or delete on payments
for each row execute function log_change();

drop trigger if exists trg_log_settings on settings;
create trigger trg_log_settings after update on settings
for each row execute function log_change();
