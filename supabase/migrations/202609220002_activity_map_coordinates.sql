alter table public.activity_proposals
add column if not exists latitude double precision,
add column if not exists longitude double precision;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_proposals_latitude_check'
      and conrelid = 'public.activity_proposals'::regclass
  ) then
    alter table public.activity_proposals
    add constraint activity_proposals_latitude_check
    check (latitude is null or latitude between -90 and 90);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_proposals_longitude_check'
      and conrelid = 'public.activity_proposals'::regclass
  ) then
    alter table public.activity_proposals
    add constraint activity_proposals_longitude_check
    check (longitude is null or longitude between -180 and 180);
  end if;
end
$$;

alter table public.itinerary_items
add column if not exists latitude double precision,
add column if not exists longitude double precision;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'itinerary_items_latitude_check'
      and conrelid = 'public.itinerary_items'::regclass
  ) then
    alter table public.itinerary_items
    add constraint itinerary_items_latitude_check
    check (latitude is null or latitude between -90 and 90);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'itinerary_items_longitude_check'
      and conrelid = 'public.itinerary_items'::regclass
  ) then
    alter table public.itinerary_items
    add constraint itinerary_items_longitude_check
    check (longitude is null or longitude between -180 and 180);
  end if;
end
$$;

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
    trip_id, proposal_id, title, location, latitude, longitude,
    start_at, end_at, position
  ) values (
    target_trip_id, proposal.id, proposal.title, proposal.location,
    proposal.latitude, proposal.longitude,
    item_start_at, item_end_at, next_position
  );

  update public.activity_proposals
  set status = 'scheduled'
  where id = proposal.id;
end;
$$;
