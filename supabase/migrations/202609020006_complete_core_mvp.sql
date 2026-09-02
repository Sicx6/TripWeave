alter table public.trips
add column if not exists description text not null default ''
check (char_length(description) <= 1000);

alter table public.activity_proposals
add column if not exists custom_category text;

update public.activity_proposals
set
  custom_category = case
    when category = 'Nightlife' then 'Nightlife'
    when category = 'Other' then 'Other'
    when category = 'Custom' then
      coalesce(nullif(trim(custom_category), ''), 'Custom activity')
    when category not in (
      'Food', 'Sightseeing', 'Culture', 'Nature', 'Shopping',
      'Attractions', 'Restaurants', 'Accommodation', 'Transport'
    ) then left(category, 40)
    else null
  end,
  category = case
    when category = 'Food' then 'Restaurants'
    when category in ('Sightseeing', 'Culture', 'Nature') then 'Attractions'
    when category in ('Nightlife', 'Other') then 'Custom'
    when category in (
      'Attractions', 'Restaurants', 'Accommodation',
      'Transport', 'Shopping', 'Custom'
    ) then category
    else 'Custom'
  end
where category in (
    'Food', 'Sightseeing', 'Culture', 'Nature', 'Nightlife', 'Other'
  )
  or category not in (
    'Attractions', 'Restaurants', 'Accommodation',
    'Transport', 'Shopping', 'Custom'
  )
  or (category = 'Custom' and nullif(trim(custom_category), '') is null)
  or (category <> 'Custom' and custom_category is not null);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_proposals_category_check'
      and conrelid = 'public.activity_proposals'::regclass
  ) then
    alter table public.activity_proposals
    add constraint activity_proposals_category_check
    check (
      category in (
        'Attractions',
        'Restaurants',
        'Accommodation',
        'Transport',
        'Shopping',
        'Custom'
      )
    );
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_proposals_custom_category_check'
      and conrelid = 'public.activity_proposals'::regclass
  ) then
    alter table public.activity_proposals
    add constraint activity_proposals_custom_category_check
    check (
      (category = 'Custom' and char_length(trim(custom_category)) between 2 and 40)
      or (category <> 'Custom' and custom_category is null)
    );
  end if;
end;
$$;

drop policy if exists "authors soft delete activity comments"
on public.activity_comments;

create policy "authors soft delete activity comments"
on public.activity_comments for delete to authenticated
using (user_id = auth.uid());

create or replace function public.leave_trip(target_trip_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;
  if public.is_trip_owner(target_trip_id) then
    raise exception 'Transfer ownership before leaving the trip';
  end if;

  update public.trip_members
  set deleted_at = now(), updated_at = now(), version = version + 1
  where trip_id = target_trip_id
    and user_id = auth.uid()
    and role = 'member'
    and deleted_at is null;

  if not found then raise exception 'Active trip membership not found'; end if;
end;
$$;

create or replace function public.transfer_trip_ownership(
  target_trip_id uuid,
  new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_owner_id uuid := auth.uid();
begin
  if not public.is_trip_owner(target_trip_id) then
    raise exception 'Only the current owner can transfer ownership';
  end if;
  if new_owner_id = previous_owner_id then
    raise exception 'This user is already the owner';
  end if;
  if not exists (
    select 1 from public.trip_members
    where trip_id = target_trip_id
      and user_id = new_owner_id
      and role = 'member'
      and deleted_at is null
  ) then
    raise exception 'The new owner must be an active trip member';
  end if;

  update public.trips
  set owner_id = new_owner_id
  where id = target_trip_id and owner_id = previous_owner_id;

  update public.trip_members
  set role = case
        when user_id = new_owner_id then 'owner'::public.trip_member_role
        else 'member'::public.trip_member_role
      end,
      updated_at = now(),
      version = version + 1
  where trip_id = target_trip_id
    and user_id in (previous_owner_id, new_owner_id)
    and deleted_at is null;
end;
$$;

revoke execute on function public.leave_trip(uuid) from public, anon;
revoke execute on function public.transfer_trip_ownership(uuid, uuid)
from public, anon;

grant execute on function public.leave_trip(uuid) to authenticated;
grant execute on function public.transfer_trip_ownership(uuid, uuid)
to authenticated;
