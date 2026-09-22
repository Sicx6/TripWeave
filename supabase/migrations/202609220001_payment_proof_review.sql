alter table public.expense_splits
add column if not exists receipt_status text not null default 'none',
add column if not exists receipt_reviewed_by uuid references public.profiles(id),
add column if not exists receipt_reviewed_at timestamptz,
add column if not exists receipt_rejection_reason text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expense_splits_receipt_status_check'
      and conrelid = 'public.expense_splits'::regclass
  ) then
    alter table public.expense_splits
    add constraint expense_splits_receipt_status_check
    check (receipt_status in ('none', 'pending', 'approved', 'rejected'));
  end if;
end
$$;

update public.expense_splits
set receipt_status = 'approved'
where settled = true
  and receipt_path is not null
  and receipt_status = 'none';

create or replace function public.settle_expense_split(
  target_expense_id uuid,
  target_user_id uuid,
  receipt_storage_path text
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
    raise exception 'You cannot submit proof for this balance';
  end if;
  if target_user_id = expense_record.paid_by then
    raise exception 'The payer share does not need payment proof';
  end if;
  if receipt_storage_path is null or trim(receipt_storage_path) = '' then
    raise exception 'Receipt proof is required';
  end if;
  if receipt_storage_path not like expense_record.trip_id::text || '/%' then
    raise exception 'Receipt proof must belong to this trip';
  end if;

  update public.expense_splits
  set settled = false,
      settled_at = null,
      receipt_path = receipt_storage_path,
      receipt_status = 'pending',
      receipt_reviewed_by = null,
      receipt_reviewed_at = null,
      receipt_rejection_reason = null,
      updated_at = now()
  where expense_id = target_expense_id
    and user_id = target_user_id
    and settled = false
    and receipt_status in ('none', 'rejected')
    and deleted_at is null;
  if not found then
    raise exception 'This payment proof is already pending or approved';
  end if;
end;
$$;

create or replace function public.review_expense_payment_proof(
  target_expense_id uuid,
  target_user_id uuid,
  approve_proof boolean,
  rejection_reason text default null
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
  if expense_record.id is null then
    raise exception 'Expense not found';
  end if;
  if auth.uid() <> expense_record.paid_by
    and not public.is_trip_owner(expense_record.trip_id) then
    raise exception 'Only the payer or trip owner can review payment proof';
  end if;
  if not approve_proof
    and (rejection_reason is null or trim(rejection_reason) = '') then
    raise exception 'Give a reason when rejecting payment proof';
  end if;

  update public.expense_splits
  set settled = approve_proof,
      settled_at = case when approve_proof then now() else null end,
      receipt_status = case when approve_proof then 'approved' else 'rejected' end,
      receipt_reviewed_by = auth.uid(),
      receipt_reviewed_at = now(),
      receipt_rejection_reason = case
        when approve_proof then null
        else trim(rejection_reason)
      end,
      updated_at = now()
  where expense_id = target_expense_id
    and user_id = target_user_id
    and receipt_status = 'pending'
    and receipt_path is not null
    and deleted_at is null;
  if not found then
    raise exception 'This payment proof is no longer pending';
  end if;
end;
$$;

revoke execute on function public.review_expense_payment_proof(uuid, uuid, boolean, text)
from public, anon;
grant execute on function public.review_expense_payment_proof(uuid, uuid, boolean, text)
to authenticated;
