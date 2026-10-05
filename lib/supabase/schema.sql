-- ============================================================
-- Coinly database schema
-- Run once on a fresh Supabase project (SQL Editor).
-- ============================================================

-- ---------- Profiles ----------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  currency text not null default 'INR',
  created_at timestamptz not null default now()
);

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name)
  values (new.id, new.raw_user_meta_data->>'name');
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

-- ---------- Types ----------
create type account_type as enum ('cash', 'bank', 'credit_card', 'savings', 'wallet');
create type txn_type as enum ('income', 'expense');
create type input_method as enum ('manual', 'receipt_scan', 'voice', 'sms');

-- ---------- Accounts ----------
create table accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  type account_type not null default 'bank',
  balance numeric(14,2) not null default 0,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

-- At most one default account per user.
create unique index one_default_account_per_user
  on accounts (user_id) where is_default;

-- Switch the default atomically (never leaves zero or two defaults).
create function set_default_account(p_id uuid) returns void
language plpgsql security invoker as $$
begin
  update accounts set is_default = false
  where user_id = auth.uid() and is_default and id <> p_id;

  update accounts set is_default = true
  where id = p_id and user_id = auth.uid();
end $$;

-- ---------- Categories ----------
create table categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  type txn_type not null,
  icon text,
  color text
);

insert into categories (user_id, name, type, icon, color) values
  (null, 'Food & Dining',    'expense', 'restaurant',     '#EF5350'),
  (null, 'Groceries',        'expense', 'shopping_cart',  '#66BB6A'),
  (null, 'Transport',        'expense', 'directions_car', '#42A5F5'),
  (null, 'Shopping',         'expense', 'shopping_bag',   '#AB47BC'),
  (null, 'Bills & Utilities','expense', 'receipt_long',   '#FFA726'),
  (null, 'Entertainment',    'expense', 'movie',          '#EC407A'),
  (null, 'Health',           'expense', 'favorite',       '#26A69A'),
  (null, 'Rent',             'expense', 'home',           '#8D6E63'),
  (null, 'Other',            'expense', 'more_horiz',     '#78909C'),
  (null, 'Salary',           'income',  'payments',       '#2E7D32'),
  (null, 'Freelance',        'income',  'work',           '#00897B'),
  (null, 'Other Income',     'income',  'add_circle',     '#558B2F');

-- ---------- Transactions ----------
create table transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  type txn_type not null,
  amount numeric(14,2) not null check (amount > 0),
  description text,
  date timestamptz not null default now(),
  input_method input_method not null default 'manual',
  voice_transcript text,
  receipt_url text,
  created_at timestamptz not null default now()
);

create index transactions_user_date_idx on transactions (user_id, date desc);

-- ---------- Budgets ----------
-- category_id null = the overall monthly budget.
create table budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category_id uuid references categories(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  unique nulls not distinct (user_id, category_id)
);

-- ---------- Keep account balances in sync ----------
create function apply_txn_to_balance() returns trigger
language plpgsql as $$
begin
  if tg_op in ('DELETE', 'UPDATE') then
    update accounts
    set balance = balance + case old.type when 'income' then -old.amount else old.amount end
    where id = old.account_id;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    update accounts
    set balance = balance + case new.type when 'income' then new.amount else -new.amount end
    where id = new.account_id;
  end if;

  return coalesce(new, old);
end $$;

create trigger txn_balance_sync
after insert or update or delete on transactions
for each row execute function apply_txn_to_balance();

-- ---------- AI usage (daily limits) ----------
create table ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  count int not null default 0,
  primary key (user_id, day)
);

-- +1 and check the limit in a single atomic statement.
create function consume_ai_quota(p_user uuid, p_limit int)
returns table (allowed boolean, used int, remaining int)
language plpgsql security definer set search_path = public as $$
declare
  v_day date := (now() at time zone 'Asia/Kolkata')::date;
  v_used int;
begin
  insert into ai_usage as u (user_id, day, count)
  values (p_user, v_day, 1)
  on conflict (user_id, day)
  do update set count = u.count + 1
  where u.count < p_limit
  returning u.count into v_used;

  -- The WHERE blocked the update: the limit is reached.
  if v_used is null then
    select u.count into v_used from ai_usage u
    where u.user_id = p_user and u.day = v_day;
    return query select false, coalesce(v_used, 0), 0;
    return;
  end if;

  return query select true, v_used, greatest(p_limit - v_used, 0);
end $$;

-- Give one back when the failure was not the user's fault.
create function refund_ai_quota(p_user uuid) returns void
language sql security definer set search_path = public as $$
  update ai_usage set count = greatest(count - 1, 0)
  where user_id = p_user and day = (now() at time zone 'Asia/Kolkata')::date;
$$;

-- Only Edge Functions (service role) may call the quota functions.
revoke all on function consume_ai_quota(uuid, int) from public, anon, authenticated;
revoke all on function refund_ai_quota(uuid) from public, anon, authenticated;
grant execute on function consume_ai_quota(uuid, int) to service_role;
grant execute on function refund_ai_quota(uuid) to service_role;

-- ---------- Row Level Security ----------
alter table profiles     enable row level security;
alter table accounts     enable row level security;
alter table categories   enable row level security;
alter table transactions enable row level security;
alter table budgets      enable row level security;
alter table ai_usage     enable row level security;

create policy "own profile" on profiles for all
  using (id = auth.uid()) with check (id = auth.uid());

create policy "own accounts" on accounts for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own transactions" on transactions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own budgets" on budgets for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Categories: everyone reads built-ins and their own; edit only your own.
create policy "read categories" on categories for select
  using (user_id is null or user_id = auth.uid());
create policy "insert own categories" on categories for insert
  with check (user_id = auth.uid());
create policy "update own categories" on categories for update
  using (user_id = auth.uid());
create policy "delete own categories" on categories for delete
  using (user_id = auth.uid());

-- Users can read their own AI usage; nobody can write it from the app.
create policy "read own ai usage" on ai_usage for select
  using (user_id = auth.uid());

-- Refresh the API schema cache.
notify pgrst, 'reload schema';