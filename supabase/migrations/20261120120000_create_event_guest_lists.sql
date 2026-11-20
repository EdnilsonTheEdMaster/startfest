create extension if not exists pgcrypto with schema extensions;

create table public.events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null check (char_length(title) between 2 and 120),
  venue text not null check (char_length(venue) between 2 and 120),
  neighborhood text not null check (char_length(neighborhood) between 2 and 100),
  starts_at timestamptz not null,
  ends_at timestamptz,
  description text not null check (char_length(description) between 2 and 500),
  category text not null check (char_length(category) between 2 and 40),
  status text not null default 'draft' check (status in ('draft', 'published', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table public.guest_list_submissions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  event_id uuid not null references public.events(id) on delete restrict,
  consent_version text not null,
  consented_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.guest_list_entries (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.guest_list_submissions(id) on delete cascade,
  guest_name text not null check (char_length(guest_name) between 2 and 80),
  ticket_type text not null check (ticket_type in ('standard', 'vip', 'couple')),
  created_at timestamptz not null default now()
);

create index guest_list_submissions_event_created_idx
  on public.guest_list_submissions (event_id, created_at desc);
create index guest_list_entries_submission_idx
  on public.guest_list_entries (submission_id);
create index events_published_starts_at_idx
  on public.events (starts_at)
  where status = 'published';

create table public.guest_list_rate_limits (
  rate_key text primary key check (rate_key ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  updated_at timestamptz not null default now()
);

alter table public.events enable row level security;
alter table public.guest_list_submissions enable row level security;
alter table public.guest_list_entries enable row level security;
alter table public.guest_list_rate_limits enable row level security;

create policy "Anyone can read published events"
  on public.events
  for select
  to anon, authenticated
  using (status = 'published');

create policy "Admins can manage events"
  on public.events
  for all
  to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Admins can read guest list submissions"
  on public.guest_list_submissions
  for select
  to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Admins can read guest list entries"
  on public.guest_list_entries
  for select
  to authenticated
  using (
    (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

grant select on public.events to anon, authenticated;
grant insert, update, delete on public.events to authenticated;
grant select on public.guest_list_submissions, public.guest_list_entries to authenticated;
grant all on public.events, public.guest_list_submissions, public.guest_list_entries, public.guest_list_rate_limits to service_role;

create or replace function public.consume_guest_list_rate_limit(p_key text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  current_count integer;
begin
  if p_key !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid rate limit key' using errcode = '22023';
  end if;

  insert into public.guest_list_rate_limits as current_window (
    rate_key,
    window_started_at,
    request_count
  )
  values (p_key, now(), 1)
  on conflict (rate_key) do update
    set window_started_at = case
          when current_window.window_started_at <= now() - interval '10 minutes' then now()
          else current_window.window_started_at
        end,
        request_count = case
          when current_window.window_started_at <= now() - interval '10 minutes' then 1
          else current_window.request_count + 1
        end,
        updated_at = now()
  returning request_count into current_count;

  return current_count <= 5;
end;
$$;

create or replace function public.create_guest_list_submission(
  p_event_id uuid,
  p_request_id uuid,
  p_consent_version text,
  p_guests jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  submission_id uuid;
  existing_event_id uuid;
  guest jsonb;
  guest_name text;
  ticket_type text;
begin
  if jsonb_typeof(p_guests) is distinct from 'array' then
    raise exception 'Guest list must be an array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_guests) not between 1 and 10 then
    raise exception 'Guest list must contain between 1 and 10 people' using errcode = '22023';
  end if;
  if p_consent_version is null or p_consent_version !~ '^[a-z0-9-]{1,40}$' then
    raise exception 'Valid consent is required' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from public.events
    where id = p_event_id
      and status = 'published'
      and starts_at > now()
  ) then
    raise exception 'Event is not accepting guest lists' using errcode = '22023';
  end if;

  insert into public.guest_list_submissions (request_id, event_id, consent_version)
  values (p_request_id, p_event_id, p_consent_version)
  on conflict (request_id) do nothing
  returning id into submission_id;

  if submission_id is null then
    select id, event_id
      into submission_id, existing_event_id
      from public.guest_list_submissions
      where request_id = p_request_id;
    if existing_event_id is distinct from p_event_id then
      raise exception 'Request identifier already used' using errcode = '23505';
    end if;
    return submission_id;
  end if;

  for guest in select value from jsonb_array_elements(p_guests) as guest_rows(value)
  loop
    guest_name := btrim(guest ->> 'name');
    ticket_type := guest ->> 'ticketType';
    if guest_name is null
      or char_length(guest_name) not between 2 and 80
      or guest_name ~ '[[:cntrl:]]'
      or ticket_type is null
      or ticket_type not in ('standard', 'vip', 'couple') then
      raise exception 'Guest details are invalid' using errcode = '22023';
    end if;

    insert into public.guest_list_entries (submission_id, guest_name, ticket_type)
    values (submission_id, guest_name, ticket_type);
  end loop;

  return submission_id;
end;
$$;

revoke all on function public.consume_guest_list_rate_limit(text) from public, anon, authenticated;
revoke all on function public.create_guest_list_submission(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.consume_guest_list_rate_limit(text) to service_role;
grant execute on function public.create_guest_list_submission(uuid, uuid, text, jsonb) to service_role;

insert into public.events (
  id, slug, title, venue, neighborhood, starts_at, ends_at, description, category, status
) values
  (
    '8a9b4701-5d62-40de-8b2f-94a605103a01',
    'noite-startfest',
    'Noite de estreia',
    'Casa Aurora',
    'Pinheiros',
    '2026-12-05 21:00:00-03',
    '2026-12-06 04:00:00-03',
    'Uma noite para abrir a temporada do jeito certo: música, encontros e pista acesa.',
    'Festa',
    'published'
  ),
  (
    '8a9b4701-5d62-40de-8b2f-94a605103a02',
    'festival-frequencia',
    'Festival Frequência',
    'Galpão 88',
    'Barra Funda',
    '2026-12-12 20:00:00-03',
    '2026-12-13 05:00:00-03',
    'Diferentes sons, uma só pista. Chegue cedo e encontre sua frequência.',
    'Festival',
    'published'
  ),
  (
    '8a9b4701-5d62-40de-8b2f-94a605103a03',
    'sunset-na-cidade',
    'Sunset na cidade',
    'Terraço Horizonte',
    'Moema',
    '2026-12-19 16:00:00-03',
    '2026-12-19 23:00:00-03',
    'Fim de tarde, bons drinks e a trilha sonora perfeita para prolongar o encontro.',
    'Sunset',
    'published'
  )
on conflict (id) do nothing;
