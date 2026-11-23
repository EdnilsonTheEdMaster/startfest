update public.events
set neighborhood = 'Não informado'
where slug = 'pre-inauguracao-resenha-start-2026'
  and neighborhood is null;
