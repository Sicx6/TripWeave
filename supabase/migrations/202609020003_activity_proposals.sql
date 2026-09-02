create type public.proposal_status as enum (
  'proposed',
  'voting',
  'approved',
  'rejected',
  'scheduled',
  'completed',
  'cancelled'
);

create table public.activity_proposals (
  id uuid primary key,
  trip_id uuid not null references public.trips(id) on delete cascade,
  proposed_by uuid not null references public.profiles(id),
  title text not null check (char_length(trim(title)) between 2 and 120),
  category text not null check (char_length(trim(category)) between 2 and 40),
  location text not null check (char_length(trim(location)) between 2 and 160),
  proposed_at timestamptz not null,
  estimated_cost numeric(12, 2) not null default 0 check (estimated_cost >= 0),
  description text not null default '' check (char_length(description) <= 2000),
  image_url text,
  status public.proposal_status not null default 'proposed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz
);

create table public.activity_votes (
  proposal_id uuid not null references public.activity_proposals(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  support boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (proposal_id, user_id)
);

create table public.activity_comments (
  id uuid primary key,
  proposal_id uuid not null references public.activity_proposals(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  deleted_at timestamptz
);

create index activity_proposals_trip_idx
on public.activity_proposals(trip_id, proposed_at) where deleted_at is null;
create index activity_proposals_status_idx
on public.activity_proposals(status) where deleted_at is null;
create index activity_comments_proposal_idx
on public.activity_comments(proposal_id, created_at) where deleted_at is null;

alter table public.activity_proposals enable row level security;
alter table public.activity_votes enable row level security;
alter table public.activity_comments enable row level security;

create or replace function public.proposal_trip_id(target_proposal_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select trip_id
  from public.activity_proposals
  where id = target_proposal_id and deleted_at is null;
$$;

create policy "members view activity proposals"
on public.activity_proposals for select to authenticated
using (public.is_trip_member(trip_id));

create policy "members create activity proposals"
on public.activity_proposals for insert to authenticated
with check (public.is_trip_member(trip_id) and proposed_by = auth.uid());

create policy "owners decide activity proposals"
on public.activity_proposals for update to authenticated
using (public.is_trip_owner(trip_id))
with check (public.is_trip_owner(trip_id));

create policy "members view activity votes"
on public.activity_votes for select to authenticated
using (public.is_trip_member(public.proposal_trip_id(proposal_id)));

create policy "members cast their vote"
on public.activity_votes for insert to authenticated
with check (
  user_id = auth.uid()
  and public.is_trip_member(public.proposal_trip_id(proposal_id))
);

create policy "members change their vote"
on public.activity_votes for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.is_trip_member(public.proposal_trip_id(proposal_id))
);

create policy "members view activity comments"
on public.activity_comments for select to authenticated
using (public.is_trip_member(public.proposal_trip_id(proposal_id)));

create policy "members add activity comments"
on public.activity_comments for insert to authenticated
with check (
  user_id = auth.uid()
  and public.is_trip_member(public.proposal_trip_id(proposal_id))
);

create policy "authors update activity comments"
on public.activity_comments for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.bump_proposal_version()
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

create trigger before_activity_proposal_update
  before update on public.activity_proposals
  for each row execute procedure public.bump_proposal_version();

insert into storage.buckets (id, name, public)
values ('activity-images', 'activity-images', true)
on conflict (id) do nothing;

create policy "activity images are publicly readable"
on storage.objects for select
using (bucket_id = 'activity-images');

create policy "members upload activity images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'activity-images'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
);

create policy "members update activity images"
on storage.objects for update to authenticated
using (
  bucket_id = 'activity-images'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
)
with check (
  bucket_id = 'activity-images'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
);
