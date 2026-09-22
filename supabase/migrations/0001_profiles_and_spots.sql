-- Pavement: profiles, spots and server-side Octane.
-- Apply in Supabase → SQL Editor. Safe to read top to bottom; each block explains itself.
-- Octane is always calculated here on the server, so a modified app can't award itself points.

-- Car tiers (seeded by 0002_seed_car_tiers.sql, generated from Data/cars by Tools/build_cars.py)
create table public.car_tiers (
  car_id text primary key,
  tier   text not null check (tier in ('legendary','exotic','rare','niche','occasional','common')),
  octane integer not null check (octane > 0)
);

-- One profile per account
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text unique check (username ~ '^[a-z0-9_]{3,20}$'),
  octane     integer not null default 0,
  created_at timestamptz not null default now()
);

-- Every spot. Photos stay on the phone; only this record is stored.
create table public.spots (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  car_id     text not null references public.car_tiers (car_id),
  spotted_at timestamptz not null default now(),
  latitude   double precision check (latitude between -90 and 90),
  longitude  double precision check (longitude between -180 and 180),
  octane     integer not null default 0
);
create index spots_user_idx on public.spots (user_id, spotted_at desc);
create index spots_car_idx  on public.spots (car_id);

-- Create a profile automatically for each new account
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Octane for a new spot: the tier's value, or 0 when re-snapping the same model within
-- 10 minutes and 200 m (same rule as the app's OctaneRules). Then add it to the profile.
create function public.award_octane() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  base integer;
  is_repeat boolean;
begin
  new.user_id := auth.uid();                -- can't spot on someone else's behalf
  if new.spotted_at > now() + interval '5 minutes' then
    new.spotted_at := now();                -- no future-dated spots
  end if;
  select octane into base from public.car_tiers where car_id = new.car_id;
  select exists (
    select 1 from public.spots s
    where s.user_id = new.user_id and s.car_id = new.car_id
      and abs(extract(epoch from (s.spotted_at - new.spotted_at))) < 600
      and (new.latitude is null or s.latitude is null or
           -- rough distance in metres (equirectangular; fine at 200 m scale)
           sqrt(power((s.latitude - new.latitude) * 111320, 2) +
                power((s.longitude - new.longitude) * 111320 * cos(radians(new.latitude)), 2)) < 200)
  ) into is_repeat;
  new.octane := case when is_repeat then 0 else coalesce(base, 0) end;
  update public.profiles set octane = octane + new.octane where id = new.user_id;
  return new;
end $$;
create trigger spots_award_octane before insert on public.spots
  for each row execute function public.award_octane();

-- Spot rarity ("how many people found it"): counts only, never who or where.
create function public.car_spot_counts()
returns table (car_id text, spotters bigint, spots bigint)
language sql stable security definer set search_path = '' as $$
  select car_id, count(distinct user_id), count(*) from public.spots group by car_id
$$;

-- Row Level Security
alter table public.car_tiers enable row level security;
alter table public.profiles  enable row level security;
alter table public.spots     enable row level security;

create policy "Anyone signed in can read tiers" on public.car_tiers
  for select to authenticated using (true);
create policy "Anyone signed in can read profiles" on public.profiles
  for select to authenticated using (true);
create policy "Users update their own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "Users read their own spots" on public.spots
  for select to authenticated using (user_id = auth.uid());
create policy "Users add their own spots" on public.spots
  for insert to authenticated with check (user_id = auth.uid());

-- "Automatically expose new tables" is off, so grant exactly what the app needs.
grant select on public.car_tiers to authenticated;
grant select on public.profiles to authenticated;
grant update (username) on public.profiles to authenticated;   -- Octane can't be edited by users
grant select, insert on public.spots to authenticated;
-- Postgres (and Supabase) let everyone call new functions by default, so revoke first.
revoke all on function public.car_spot_counts() from public, anon;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.award_octane() from public, anon, authenticated;
grant execute on function public.car_spot_counts() to authenticated;
