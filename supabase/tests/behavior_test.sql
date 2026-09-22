-- Behavior test for the migrations, run against a local Postgres with a Supabase stand-in
-- (see Tools/test_database.sh). Three users try legitimate things and cheating; every check
-- raises an error if the database lets something through that it shouldn't.
\set ON_ERROR_STOP 1
set client_min_messages = warning;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@test.invalid'),
  ('00000000-0000-0000-0000-00000000000b', 'bo@test.invalid'),
  ('00000000-0000-0000-0000-00000000000c', 'cy@test.invalid');

do $$ begin
  assert (select count(*) from profiles) = 3, 'a profile is created for each new account';
end $$;

-- ---------- Ana spots cars ----------
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';

insert into spots (car_id, latitude, longitude, octane) values ('honda-civic', 41.88, -87.63, 99999);
do $$ begin
  assert (select octane from spots order by spotted_at desc limit 1) = 10, 'server ignores the Octane the app sends';
  assert (select octane from profiles where id = auth.uid()) = 10, 'profile total goes up by the tier value';
end $$;

insert into spots (car_id, latitude, longitude) values ('honda-civic', 41.8801, -87.63);
do $$ begin
  assert (select octane from spots order by spotted_at desc limit 1) = 0, 're-snapping the same car within 10 min / 200 m earns 0';
end $$;

insert into spots (car_id, latitude, longitude) values ('honda-civic', 41.95, -87.63);   -- ~8 km away
do $$ begin
  assert (select octane from spots order by spotted_at desc limit 1) = 10, 'same model somewhere else earns full Octane';
end $$;

insert into spots (car_id, spotted_at) values ('mclaren-f1', now() + interval '3 days');
do $$ begin
  assert (select spotted_at from spots where car_id = 'mclaren-f1') <= now() + interval '5 minutes', 'future-dated spots are clamped to now';
  assert (select octane from profiles where id = auth.uid()) = 2020, 'Legendary adds 2000';
end $$;

-- Spotting on someone else's behalf is impossible: user_id is always forced to the caller.
insert into spots (car_id, user_id) values ('toyota-corolla', '00000000-0000-0000-0000-00000000000b');
do $$ begin
  assert (select user_id from spots where car_id = 'toyota-corolla') = auth.uid(), 'spots always belong to the signed-in user';
end $$;

-- A car that isn't in the catalog is rejected.
do $$ begin
  begin
    insert into spots (car_id) values ('made-up-hypercar');
    raise exception 'unknown car was accepted';
  exception when foreign_key_violation then null;
  end;
end $$;

-- Users can't edit their own Octane.
do $$ begin
  begin
    update profiles set octane = 1000000 where id = auth.uid();
    raise exception 'user was able to set their own Octane';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Usernames: valid ones save, invalid ones are refused.
update profiles set username = 'ana_spots' where id = auth.uid();
do $$ begin
  begin
    update profiles set username = 'Bad Name!' where id = auth.uid();
    raise exception 'invalid username was accepted';
  exception when check_violation then null;
  end;
end $$;

-- ---------- Bo can't see Ana's spots until they're friends ----------
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$ begin
  assert (select count(*) from spots) = 0, 'strangers see none of your spots';
  assert (select count(*) from profiles) = 3, 'usernames and Octane are visible to signed-in users (for finding friends)';
end $$;

-- Bo can't insert a friendship pretending to be Ana, or pre-accepted.
do $$ begin
  begin
    insert into friendships (requester, addressee) values ('00000000-0000-0000-0000-00000000000a', auth.uid());
    raise exception 'forged friend request was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into friendships (addressee, status) values ('00000000-0000-0000-0000-00000000000a', 'accepted');
    raise exception 'pre-accepted friendship was accepted';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Ana sends Bo a request.
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
insert into friendships (addressee) values ('00000000-0000-0000-0000-00000000000b');

-- Cy can't accept a request meant for Bo (nothing visible to update).
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000c';
update friendships set status = 'accepted' where requester = '00000000-0000-0000-0000-00000000000a';
do $$ begin
  assert (select count(*) from friendships) = 0, 'third parties cannot see other people''s requests';
end $$;
reset role;
do $$ begin
  assert (select status from friendships) = 'pending', 'a third party could not accept someone else''s request';
end $$;

-- Pending isn't enough.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$ begin
  assert (select count(*) from spots) = 0, 'a pending request does not reveal spots';
end $$;

-- Bo accepts; now Bo sees Ana's spots, Cy still doesn't.
update friendships set status = 'accepted' where requester = '00000000-0000-0000-0000-00000000000a';
do $$ begin
  assert (select count(*) from spots) = 5, 'friends can see each other''s spots';
end $$;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000c';
do $$ begin
  assert (select count(*) from spots) = 0, 'non-friends still see nothing';
end $$;

-- Community counts reveal numbers only.
do $$ begin
  assert (select spotters from car_spot_counts() where car_id = 'honda-civic') = 1, 'spot counts count people';
  assert (select spots from car_spot_counts() where car_id = 'honda-civic') = 3, 'spot counts count spots';
end $$;

-- is_friend only answers about yourself: Cy can't learn that Ana and Bo are friends.
do $$ begin
  assert not public.is_friend('00000000-0000-0000-0000-00000000000a'), 'Cy is not friends with Ana';
  assert not exists (select 1 from friendships), 'Cy sees none of Ana and Bo''s friendship rows';
end $$;

-- ---------- Signed-out visitors (anon) see nothing ----------
reset role;
set role anon;
do $$ begin
  begin
    perform count(*) from spots;
    raise exception 'anon could read spots';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from car_spot_counts();
    raise exception 'anon could read spot counts';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---------- Ana deletes her account ----------
reset role;
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select public.delete_my_account();
reset role;
do $$ begin
  assert not exists (select 1 from auth.users where email = 'ana@test.invalid'), 'account deleted';
  assert not exists (select 1 from profiles where id = '00000000-0000-0000-0000-00000000000a'), 'profile deleted';
  assert (select count(*) from spots) = 0, 'all her spots deleted';
  assert (select count(*) from friendships) = 0, 'her friendships deleted';
  assert (select count(*) from profiles) = 2, 'other users untouched';
end $$;

-- Deleting only ever affects yourself.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select public.delete_my_account();
reset role;
do $$ begin
  assert exists (select 1 from auth.users where email = 'cy@test.invalid'), 'deleting your account never deletes someone else';
end $$;

\echo ALL DATABASE CHECKS PASSED
