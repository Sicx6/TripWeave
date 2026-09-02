create type public.itinerary_item_status as enum (
  'scheduled',
  'completed',
  'cancelled'
);

create table public.itinerary_items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  proposal_id uuid unique references public.activity_proposals(id),
  title text not null check (char_length(trim(title)) between 2 and 120),
  location text not null check (char_length(trim(location)) between 2 and 160),
  start_at timestamptz not null,
  end_at timestamptz not null,
  position integer not null default 0 check (position >= 0),
  status public.itinerary_item_status not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  constraint itinerary_time_order check (end_at > start_at)
);

create table public.expenses (
  id uuid primary key,
  trip_id uuid not null references public.trips(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 120),
  amount numeric(12, 2) not null check (amount > 0),
  paid_by uuid not null references public.profiles(id),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz
);

create table public.expense_splits (
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  amount numeric(12, 2) not null check (amount >= 0),
  settled boolean not null default false,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (expense_id, user_id)
);

create index itinerary_trip_time_idx
on public.itinerary_items(trip_id, start_at, position) where deleted_at is null;
create index expenses_trip_created_idx
on public.expenses(trip_id, created_at desc) where deleted_at is null;
create index expense_splits_user_idx
on public.expense_splits(user_id) where deleted_at is null and settled = false;

alter table public.itinerary_items enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;

create policy "members view itinerary"
on public.itinerary_items for select to authenticated
using (public.is_trip_member(trip_id));

create policy "members view expenses"
on public.expenses for select to authenticated
using (public.is_trip_member(trip_id));

create policy "members view expense splits"
on public.expense_splits for select to authenticated
using (public.is_trip_member((
  select e.trip_id from public.expenses e where e.id = expense_id
)));

create or replace function public.add_proposal_to_itinerary(
  target_trip_id uuid,
  target_proposal_id uuid,
  item_start_at timestamptz,
  item_end_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal public.activity_proposals;
  trip_record public.trips;
  next_position integer;
begin
  if not public.is_trip_owner(target_trip_id) then
    raise exception 'Only the trip owner can schedule activities';
  end if;

  select * into proposal from public.activity_proposals
  where id = target_proposal_id and trip_id = target_trip_id
    and status = 'approved' and deleted_at is null;
  if proposal.id is null then
    raise exception 'Only an approved proposal can be scheduled';
  end if;

  select * into trip_record from public.trips where id = target_trip_id;
  if item_end_at <= item_start_at
    or item_start_at::date < trip_record.start_date
    or item_end_at::date > trip_record.end_date then
    raise exception 'Itinerary time must be within the trip dates';
  end if;

  select coalesce(max(position), -1) + 1 into next_position
  from public.itinerary_items where trip_id = target_trip_id
    and deleted_at is null;

  insert into public.itinerary_items (
    trip_id, proposal_id, title, location, start_at, end_at, position
  ) values (
    target_trip_id, proposal.id, proposal.title, proposal.location,
    item_start_at, item_end_at, next_position
  );

  update public.activity_proposals
  set status = 'scheduled'
  where id = proposal.id;
end;
$$;

create or replace function public.reorder_itinerary_items(
  target_trip_id uuid,
  ordered_item_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  item_id uuid;
  item_position integer := 0;
begin
  if not public.is_trip_owner(target_trip_id) then
    raise exception 'Only the trip owner can reorder the itinerary';
  end if;

  foreach item_id in array ordered_item_ids loop
    update public.itinerary_items
    set position = item_position, updated_at = now(), version = version + 1
    where id = item_id and trip_id = target_trip_id and deleted_at is null;
    if not found then raise exception 'Invalid itinerary item'; end if;
    item_position := item_position + 1;
  end loop;
end;
$$;

create or replace function public.change_itinerary_item_status(
  target_item_id uuid,
  expected_version integer,
  new_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  item_trip_id uuid;
begin
  select trip_id into item_trip_id from public.itinerary_items
  where id = target_item_id and deleted_at is null;
  if item_trip_id is null or not public.is_trip_member(item_trip_id) then
    raise exception 'You cannot update this itinerary item';
  end if;
  if new_status not in ('completed', 'cancelled') then
    raise exception 'Invalid itinerary status';
  end if;

  update public.itinerary_items
  set status = new_status::public.itinerary_item_status,
      updated_at = now(), version = version + 1
  where id = target_item_id and version = expected_version
    and status = 'scheduled';
  if not found then raise exception 'Itinerary changed; refresh and try again'; end if;
end;
$$;

create or replace function public.create_trip_expense(
  new_expense_id uuid,
  target_trip_id uuid,
  expense_title text,
  amount_cents bigint,
  payer_id uuid,
  split_values jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  split_value jsonb;
  split_user_id uuid;
  split_cents bigint;
  split_total bigint := 0;
begin
  if not public.is_trip_member(target_trip_id) then
    raise exception 'Only trip members can add expenses';
  end if;
  if payer_id <> auth.uid() and not public.is_trip_owner(target_trip_id) then
    raise exception 'Only the owner can record an expense paid by someone else';
  end if;
  if not exists (
    select 1 from public.trip_members
    where trip_id = target_trip_id and user_id = payer_id
      and deleted_at is null
  ) then
    raise exception 'The payer must be a trip member';
  end if;
  if amount_cents <= 0 or jsonb_array_length(split_values) = 0 then
    raise exception 'Expense amount and participants are required';
  end if;

  for split_value in select * from jsonb_array_elements(split_values) loop
    split_user_id := (split_value ->> 'user_id')::uuid;
    split_cents := (split_value ->> 'amount_cents')::bigint;
    if split_cents < 0 or not exists (
      select 1 from public.trip_members
      where trip_id = target_trip_id and user_id = split_user_id
        and deleted_at is null
    ) then
      raise exception 'Every expense participant must be a trip member';
    end if;
    split_total := split_total + split_cents;
  end loop;
  if split_total <> amount_cents then
    raise exception 'Expense splits must equal the expense total';
  end if;

  insert into public.expenses (
    id, trip_id, title, amount, paid_by, created_by
  ) values (
    new_expense_id, target_trip_id, trim(expense_title),
    amount_cents::numeric / 100, payer_id, auth.uid()
  );

  for split_value in select * from jsonb_array_elements(split_values) loop
    insert into public.expense_splits (expense_id, user_id, amount)
    values (
      new_expense_id,
      (split_value ->> 'user_id')::uuid,
      ((split_value ->> 'amount_cents')::bigint)::numeric / 100
    );
  end loop;
end;
$$;

create or replace function public.settle_expense_split(
  target_expense_id uuid,
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  expense_record public.expenses;
begin
  select * into expense_record from public.expenses
  where id = target_expense_id and deleted_at is null;
  if expense_record.id is null
    or not public.is_trip_member(expense_record.trip_id) then
    raise exception 'Expense not found';
  end if;
  if auth.uid() <> target_user_id
    and auth.uid() <> expense_record.paid_by
    and not public.is_trip_owner(expense_record.trip_id) then
    raise exception 'You cannot settle this balance';
  end if;

  update public.expense_splits
  set settled = true, settled_at = now(), updated_at = now()
  where expense_id = target_expense_id and user_id = target_user_id
    and settled = false and deleted_at is null;
end;
$$;

revoke execute on function public.add_proposal_to_itinerary(uuid, uuid, timestamptz, timestamptz) from public, anon;
revoke execute on function public.reorder_itinerary_items(uuid, uuid[]) from public, anon;
revoke execute on function public.change_itinerary_item_status(uuid, integer, text) from public, anon;
revoke execute on function public.create_trip_expense(uuid, uuid, text, bigint, uuid, jsonb) from public, anon;
revoke execute on function public.settle_expense_split(uuid, uuid) from public, anon;

grant execute on function public.add_proposal_to_itinerary(uuid, uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.reorder_itinerary_items(uuid, uuid[]) to authenticated;
grant execute on function public.change_itinerary_item_status(uuid, integer, text) to authenticated;
grant execute on function public.create_trip_expense(uuid, uuid, text, bigint, uuid, jsonb) to authenticated;
grant execute on function public.settle_expense_split(uuid, uuid) to authenticated;
