-- Pavement: let people delete their own account (App Store rule for apps with sign-up).
-- Deleting the auth user cascades to profiles, spots and friendships (all "on delete cascade").
create function public.delete_my_account() returns void
language sql security definer set search_path = '' as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
