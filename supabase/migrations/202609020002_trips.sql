create type public.trip_status as enum (
  'draft',
  'planning',
  'finalized',
  'active',
  'completed',
  'archived',
  'cancelled'
);

create type public.trip_member_role as enum ('owner', 'member');

create table public.trips (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id),
  destination text not null check (char_length(trim(destination)) between 2 and 120),
  start_date date not null,
  end_date date not null,
  budget numeric(12, 2) not null default 0 check (budget >= 0),
  cover_image_url text,
  status public.trip_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  constraint trips_date_order check (end_date >= start_date)
);

create table public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.trip_member_role not null default 'member',
  joined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz,
  primary key (trip_id, user_id)
);

create index trips_owner_id_idx on public.trips(owner_id);
create index trips_dates_idx on public.trips(start_date, end_date);
create index trips_status_idx on public.trips(status) where deleted_at is null;
create index trip_members_user_id_idx on public.trip_members(user_id)
where deleted_at is null;

alter table public.trips enable row level security;
alter table public.trip_members enable row level security;

create or replace function public.is_trip_member(target_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trip_members
    where trip_id = target_trip_id
      and user_id = auth.uid()
      and deleted_at is null
  );
$$;

create or replace function public.is_trip_owner(target_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trips
    where id = target_trip_id
      and owner_id = auth.uid()
      and deleted_at is null
  );
$$;

create policy "members can view trips"
on public.trips for select to authenticated
using (owner_id = auth.uid() or public.is_trip_member(id));

create policy "authenticated users can create their trips"
on public.trips for insert to authenticated
with check (owner_id = auth.uid());

create policy "owners can update trips"
on public.trips for update to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "owners can delete trips"
on public.trips for delete to authenticated
using (owner_id = auth.uid());

create policy "members can view trip membership"
on public.trip_members for select to authenticated
using (user_id = auth.uid() or public.is_trip_member(trip_id));

create policy "owners can add members"
on public.trip_members for insert to authenticated
with check (public.is_trip_owner(trip_id));

create policy "owners can update members"
on public.trip_members for update to authenticated
using (public.is_trip_owner(trip_id))
with check (public.is_trip_owner(trip_id));

create policy "owners can remove members"
on public.trip_members for delete to authenticated
using (public.is_trip_owner(trip_id));

create or replace function public.add_trip_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.trip_members (trip_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;

create trigger on_trip_created_add_owner
  after insert on public.trips
  for each row execute procedure public.add_trip_owner_membership();

create or replace function public.validate_trip_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = old.status then
    return new;
  end if;

  if not (
    (old.status = 'draft' and new.status in ('planning', 'cancelled', 'archived'))
    or (old.status = 'planning' and new.status in ('finalized', 'cancelled', 'archived'))
    or (old.status = 'finalized' and new.status in ('active', 'cancelled', 'archived'))
    or (old.status = 'active' and new.status in ('completed', 'cancelled'))
    or (old.status = 'completed' and new.status = 'archived')
    or (old.status = 'cancelled' and new.status = 'archived')
  ) then
    raise exception 'Invalid trip status transition from % to %', old.status, new.status;
  end if;

  return new;
end;
$$;

create trigger validate_trip_status_before_update
  before update on public.trips
  for each row execute procedure public.validate_trip_status_transition();

create or replace function public.bump_trip_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  new.version = old.version + 1;
  return new;
end;
$$;

create trigger before_trip_update
  before update on public.trips
  for each row execute procedure public.bump_trip_version();

insert into storage.buckets (id, name, public)
values ('trip-covers', 'trip-covers', true)
on conflict (id) do nothing;

create policy "trip covers are publicly readable"
on storage.objects for select
using (bucket_id = 'trip-covers');

create policy "owners upload trip covers"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'trip-covers'
  and public.is_trip_owner(((storage.foldername(name))[1])::uuid)
);

create policy "owners update trip covers"
on storage.objects for update to authenticated
using (
  bucket_id = 'trip-covers'
  and public.is_trip_owner(((storage.foldername(name))[1])::uuid)
)
with check (
  bucket_id = 'trip-covers'
  and public.is_trip_owner(((storage.foldername(name))[1])::uuid)
);
