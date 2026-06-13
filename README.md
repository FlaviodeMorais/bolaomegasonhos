# 🍀 Bolão Mega Sonhos

Plataforma de marketplace de bolões de loteria (Mega-Sena, Quina, Lotofácil e outras),
inspirada no modelo do [Unindo Sonhos](https://www.unindosonhos.com.br): catálogo de
bolões abertos para compra de cotas, carteira digital, carrinho de compras e
apuração/rateio automático de prêmios após o sorteio.

Projeto sucessor/companheiro do [bolao-mega](https://github.com/FlaviodeMorais/bolao-mega),
reaproveitando sua stack e padrões validados.

## Stack

- **Next.js 14** (App Router) + **React 18** + **TypeScript estrito**
- **Supabase** (PostgreSQL) — schema dedicado `sonhos`, no mesmo projeto do bolao-mega
- **Mercado Pago** (PIX) para créditos na carteira e checkout
- CSS puro (custom properties / design tokens), sem framework de CSS

## Documentação

- [docs/ARQUITETURA.md](docs/ARQUITETURA.md) — arquitetura detalhada, modelo de dados e roadmap por etapas

## Como rodar localmente

```bash
npm install
cp .env.example .env.local   # preencher com as credenciais do Supabase/Mercado Pago
npm run dev
```

Abrir [http://localhost:3000](http://localhost:3000).

## Banco de dados

As migrations vivem em [`supabase/migrations/`](supabase/migrations/) e são aplicadas
automaticamente em produção via integração GitHub do Supabase a cada push na `master`.
e suas tabelas (usuários, carteira, loterias, concursos, bolões, cotas, pedidos, rateios, saques).

## Status

🚧 Em desenvolvimento — Etapa 0 (setup do projeto) concluída. Veja o roadmap completo em
[docs/ARQUITETURA.md](docs/ARQUITETURA.md#4-roadmap-por-etapas).
