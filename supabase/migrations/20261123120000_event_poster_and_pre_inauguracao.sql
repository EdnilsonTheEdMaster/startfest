alter table public.events
  add column image_url text,
  alter column neighborhood drop not null;

insert into public.events (
  slug, title, venue, neighborhood, starts_at, description, category, status, image_url
) values (
  'pre-inauguracao-resenha-start-2026',
  'Pré-inauguração Resenha Start',
  'Resenha Start',
  null,
  '2026-12-19 22:00:00-03',
  'Pré-inauguração exclusiva para amigos e chegados.',
  'Pré-inauguração',
  'published',
  'eventos/pre-inauguracao-resenha-start.jpeg'
)
on conflict (slug) do nothing;
