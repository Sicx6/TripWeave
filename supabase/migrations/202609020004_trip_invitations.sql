create extension if not exists pgcrypto with schema extensions;

create type public.invitation_status as enum (
  'pending',
  'accepted',
  'declined',
  'expired',
  'revoked'
);

create table public.trip_invitations (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  invited_by uuid not null references public.profiles(id),
  invite_code text not null unique check (invite_code ~ '^[A-F0-9]{10}$'),
  status public.invitation_status not null default 'pending',
  accepted_by uuid references public.profiles(id),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz
);

create index trip_invitations_trip_idx
on public.trip_invitations(trip_id, created_at desc) where deleted_at is null;
create index trip_invitations_pending_idx
on public.trip_invitations(invite_code)
where status = 'pending' and deleted_at is null;

alter table public.trip_invitations enable row level security;

create policy "owners view trip invitations"
on public.trip_invitations for select to authenticated
using (public.is_trip_owner(trip_id));

create or replace function public.create_trip_invitation(target_trip_id uuid)
returns public.trip_invitations
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_invitation public.trip_invitations;
  generated_code text;
begin
  if not public.is_trip_owner(target_trip_id) then
    raise exception 'Only the trip owner can create invitations';
  end if;

  loop
    generated_code := upper(substr(
      encode(extensions.gen_random_bytes(6), 'hex'),
      1,
      10
    ));
    exit when not exists (
      select 1 from public.trip_invitations where invite_code = generated_code
    );
  end loop;

  insert into public.trip_invitations (
    trip_id,
    invited_by,
    invite_code,
    expires_at
  ) values (
    target_trip_id,
    auth.uid(),
    generated_code,
    now() + interval '7 days'
  ) returning * into new_invitation;

  return new_invitation;
end;
$$;

create or replace function public.preview_trip_invitation(submitted_code text)
returns table (
  trip_id uuid,
  destination text,
  owner_name text,
  start_date date,
  end_date date,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    t.id,
    t.destination,
    p.display_name,
    t.start_date,
    t.end_date,
    i.expires_at
  from public.trip_invitations i
  join public.trips t on t.id = i.trip_id and t.deleted_at is null
  join public.profiles p on p.id = t.owner_id and p.deleted_at is null
  where i.invite_code = upper(trim(submitted_code))
    and i.status = 'pending'
    and i.expires_at > now()
    and i.deleted_at is null;
$$;

create or replace function public.accept_trip_invitation(submitted_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation public.trip_invitations;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  select * into invitation
  from public.trip_invitations
  where invite_code = upper(trim(submitted_code))
  for update;

  if invitation.id is null
    or invitation.status <> 'pending'
    or invitation.expires_at <= now()
    or invitation.deleted_at is not null then
    raise exception 'Invitation is invalid, expired, or already used';
  end if;

  if public.is_trip_owner(invitation.trip_id) then
    raise exception 'The trip owner is already a member';
  end if;

  insert into public.trip_members as existing_member (
    trip_id,
    user_id,
    role,
    deleted_at
  )
  values (invitation.trip_id, auth.uid(), 'member', null)
  on conflict (trip_id, user_id) do update
    set deleted_at = null,
        role = 'member',
        joined_at = now(),
        updated_at = now(),
        version = existing_member.version + 1;

  update public.trip_invitations
  set status = 'accepted',
      accepted_by = auth.uid(),
      updated_at = now(),
      version = version + 1
  where id = invitation.id;

  return invitation.trip_id;
end;
$$;

create or replace function public.decline_trip_invitation(submitted_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.trip_invitations
  set status = 'declined',
      accepted_by = auth.uid(),
      updated_at = now(),
      version = version + 1
  where invite_code = upper(trim(submitted_code))
    and status = 'pending'
    and expires_at > now()
    and deleted_at is null;

  if not found then
    raise exception 'Invitation is invalid, expired, or already used';
  end if;
end;
$$;

create or replace function public.revoke_trip_invitation(
  target_invitation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation_trip_id uuid;
begin
  select trip_id into invitation_trip_id
  from public.trip_invitations
  where id = target_invitation_id and deleted_at is null;

  if invitation_trip_id is null
    or not public.is_trip_owner(invitation_trip_id) then
    raise exception 'Only the trip owner can revoke this invitation';
  end if;

  update public.trip_invitations
  set status = 'revoked', updated_at = now(), version = version + 1
  where id = target_invitation_id and status = 'pending';
end;
$$;

create or replace function public.remove_trip_member(
  target_trip_id uuid,
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_trip_owner(target_trip_id) then
    raise exception 'Only the trip owner can remove members';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'The owner cannot remove themselves';
  end if;

  update public.trip_members
  set deleted_at = now(), updated_at = now(), version = version + 1
  where trip_id = target_trip_id
    and user_id = target_user_id
    and role = 'member'
    and deleted_at is null;
end;
$$;

revoke execute on function public.create_trip_invitation(uuid) from public, anon;
revoke execute on function public.preview_trip_invitation(text) from public, anon;
revoke execute on function public.accept_trip_invitation(text) from public, anon;
revoke execute on function public.decline_trip_invitation(text) from public, anon;
revoke execute on function public.revoke_trip_invitation(uuid) from public, anon;
revoke execute on function public.remove_trip_member(uuid, uuid) from public, anon;

grant execute on function public.create_trip_invitation(uuid) to authenticated;
grant execute on function public.preview_trip_invitation(text) to authenticated;
grant execute on function public.accept_trip_invitation(text) to authenticated;
grant execute on function public.decline_trip_invitation(text) to authenticated;
grant execute on function public.revoke_trip_invitation(uuid) to authenticated;
grant execute on function public.remove_trip_member(uuid, uuid) to authenticated;
