export interface EventListing {
  id: string;
  slug: string;
  title: string;
  venue: string;
  neighborhood: string | null;
  startsAt: string;
  endsAt: string | null;
  description: string;
  category: string;
  imageUrl?: string | null;
}

export const demoEvents: EventListing[] = [
  {
    id: "8a9b4701-5d62-40de-8b2f-94a605103a01",
    slug: "noite-startfest",
    title: "Noite de estreia",
    venue: "Casa Aurora",
    neighborhood: "Pinheiros",
    startsAt: "2026-12-05T21:00:00-03:00",
    endsAt: "2026-12-06T04:00:00-03:00",
    description: "Uma noite para abrir a temporada do jeito certo: música, encontros e pista acesa.",
    category: "Festa",
  },
  {
    id: "8a9b4701-5d62-40de-8b2f-94a605103a02",
    slug: "festival-frequencia",
    title: "Festival Frequência",
    venue: "Galpão 88",
    neighborhood: "Barra Funda",
    startsAt: "2026-12-12T20:00:00-03:00",
    endsAt: "2026-12-13T05:00:00-03:00",
    description: "Diferentes sons, uma só pista. Chegue cedo e encontre sua frequência.",
    category: "Festival",
  },
  {
    id: "8a9b4701-5d62-40de-8b2f-94a605103a03",
    slug: "sunset-na-cidade",
    title: "Sunset na cidade",
    venue: "Terraço Horizonte",
    neighborhood: "Moema",
    startsAt: "2026-12-19T16:00:00-03:00",
    endsAt: "2026-12-19T23:00:00-03:00",
    description: "Fim de tarde, bons drinks e a trilha sonora perfeita para prolongar o encontro.",
    category: "Sunset",
  },
];
