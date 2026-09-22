-- Pavement: friends. Apply after 0001 and 0002.
-- A friendship starts as a request (pending) and becomes friends when the other person accepts.

create table public.friendships (
  requester  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  addressee  uuid not null references auth.users (id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- True when the signed-in user and `other` are friends (either direction, accepted).
-- It only ever answers about yourself, so it can't be used to map other people's friendships.
create function public.is_friend(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and ((requester = auth.uid() and addressee = other) or (requester = other and addressee = auth.uid()))
  )
$$;

alter table public.friendships enable row level security;

create policy "See your own friendships" on public.friendships
  for select to authenticated using (auth.uid() in (requester, addressee));
create policy "Send requests as yourself" on public.friendships
  for insert to authenticated with check (requester = auth.uid() and status = 'pending');
create policy "Accept requests sent to you" on public.friendships
  for update to authenticated using (addressee = auth.uid()) with check (addressee = auth.uid() and status = 'accepted');
create policy "Either side can remove" on public.friendships
  for delete to authenticated using (auth.uid() in (requester, addressee));

-- Friends can see each other's spots (for collections and rare-find alerts).
create policy "Friends read each other's spots" on public.spots
  for select to authenticated using (public.is_friend(user_id));

grant select, insert, delete on public.friendships to authenticated;
grant update (status) on public.friendships to authenticated;
-- Postgres (and Supabase) let everyone call new functions by default: signed-in users only.
revoke all on function public.is_friend(uuid) from public, anon;
grant execute on function public.is_friend(uuid) to authenticated;
