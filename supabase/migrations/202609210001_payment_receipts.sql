alter table public.expense_splits
add column if not exists receipt_path text;

insert into storage.buckets (id, name, public)
values ('expense-receipts', 'expense-receipts', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "members view expense receipts" on storage.objects;
create policy "members view expense receipts"
on storage.objects for select to authenticated
using (
  bucket_id = 'expense-receipts'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "members upload expense receipts" on storage.objects;
create policy "members upload expense receipts"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'expense-receipts'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "members update expense receipts" on storage.objects;
create policy "members update expense receipts"
on storage.objects for update to authenticated
using (
  bucket_id = 'expense-receipts'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
)
with check (
  bucket_id = 'expense-receipts'
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
);

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
    raise exception 'You cannot settle this balance';
  end if;
  if receipt_storage_path is null or trim(receipt_storage_path) = '' then
    raise exception 'Receipt proof is required';
  end if;
  if receipt_storage_path not like expense_record.trip_id::text || '/%' then
    raise exception 'Receipt proof must belong to this trip';
  end if;

  update public.expense_splits
  set settled = true,
      settled_at = now(),
      receipt_path = receipt_storage_path,
      updated_at = now()
  where expense_id = target_expense_id
    and user_id = target_user_id
    and settled = false
    and deleted_at is null;
end;
$$;

revoke execute on function public.settle_expense_split(uuid, uuid, text) from public, anon;
grant execute on function public.settle_expense_split(uuid, uuid, text) to authenticated;
