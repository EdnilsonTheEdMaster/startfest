# StartFest

Site mobile-first para divulgar eventos e receber listas de convidados. A interface foi iniciada com Vite + TypeScript; o projeto original continha apenas este README, sem framework ou convenções de aplicação existentes.

## Desenvolvimento

```sh
npm install
npm run dev
```

Copie `.env.example` para `.env.local` e preencha `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` para carregar eventos publicados do Supabase e habilitar inscrições. A chave anon é pública e protegida pelas políticas RLS; nunca coloque a service-role key no frontend. Sem essas variáveis, a página mostra eventos demonstrativos e mantém o envio desabilitado.

```sh
npm run build
```

## GitHub Pages

The Pages workflow builds the site on pushes to `main` and the StartFest feature branch, and on pull requests it runs the build without deploying. In the repository settings, choose **Settings > Pages > Build and deployment > Source: GitHub Actions**. The production build uses the `/startfest/` base path; local development keeps `/`. The page works with demo events until the public Supabase URL and anon key are configured.

## Supabase

1. Aplique a migration em `supabase/migrations/20261120120000_create_event_guest_lists.sql`.
2. Configure os segredos da função `submit-guest-list`: `SUPABASE_SERVICE_ROLE_KEY`, `RATE_LIMIT_SECRET` (segredo aleatório) e `ALLOWED_ORIGINS` (origens exatas separadas por vírgula, sem curingas).
3. Implante a função com `supabase functions deploy submit-guest-list`.
4. Configure as mesmas origens permitidas para a URL de produção do site; em desenvolvimento, inclua a origem local usada pelo Vite.

A função valida cada pessoa, exige consentimento, limita listas a dez pessoas e aplica limite de envios por janela usando um identificador HMAC do IP. Escritas são atômicas e acessíveis somente à função com a chave de serviço; o navegador nunca recebe essa chave. RLS permite leitura pública apenas de eventos publicados e reserva os dados pessoais da lista aos usuários autenticados cujo `app_metadata.role` seja `admin`.

As tabelas `guest_list_submissions` e `guest_list_entries` separam cada envio de seus convidados e permitem agregações futuras por evento e tipo de entrada. O MVP não inclui painel administrativo nem dados de contato dos convidados.

## Conteúdo e identidade visual

Os três eventos incluídos são demonstrativos e estão espelhados na migration; substitua-os pela programação oficial antes de publicar. `public/startfest-logo.jpeg` usa o logo fornecido; `public/favicon.png` é um recorte otimizado da mesma arte. A paleta foi amostrada diretamente do arquivo: preto `#0A0A0A`, verde `#053F0C`, dourado `#E9B142` e branco `#F4F1EC`.
