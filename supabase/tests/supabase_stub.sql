-- Minimal stand-in for the parts of Supabase the migrations rely on.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
-- Same shape as Supabase's: the user id comes from the request's token, either as a single
-- setting (used by the SQL tests) or from the JWT claims JSON (used by PostgREST).
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
-- PostgREST connects as `authenticator` and switches to anon/authenticated per request.
create role authenticator noinherit login password 'pavement-test';
grant anon, authenticated to authenticator;
grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
