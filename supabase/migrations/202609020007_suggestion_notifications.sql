create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  trip_id uuid not null references public.trips(id) on delete cascade,
  proposal_id uuid references public.activity_proposals(id) on delete cascade,
  type text not null check (type in ('new_suggestion')),
  title text not null check (char_length(trim(title)) between 1 and 120),
  message text not null check (char_length(trim(message)) between 1 and 300),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_created_idx
on public.notifications(recipient_id, created_at desc);

create index if not exists notifications_recipient_unread_idx
on public.notifications(recipient_id, created_at desc)
where read_at is null;

alter table public.notifications enable row level security;

drop policy if exists "users view their notifications"
on public.notifications;
create policy "users view their notifications"
on public.notifications for select to authenticated
using (recipient_id = auth.uid());

drop policy if exists "users mark their notifications read"
on public.notifications;
create policy "users mark their notifications read"
on public.notifications for update to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

create or replace function public.notify_members_about_suggestion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (
    recipient_id,
    actor_id,
    trip_id,
    proposal_id,
    type,
    title,
    message
  )
  select
    member.user_id,
    new.proposed_by,
    new.trip_id,
    new.id,
    'new_suggestion',
    'New activity suggestion',
    coalesce(profile.display_name, 'A trip member') ||
      ' suggested "' || new.title || '".'
  from public.trip_members as member
  left join public.profiles as profile on profile.id = new.proposed_by
  where member.trip_id = new.trip_id
    and member.deleted_at is null
    and member.user_id <> new.proposed_by;

  return new;
end;
$$;

drop trigger if exists on_activity_proposal_notify_members
on public.activity_proposals;
create trigger on_activity_proposal_notify_members
  after insert on public.activity_proposals
  for each row execute function public.notify_members_about_suggestion();
