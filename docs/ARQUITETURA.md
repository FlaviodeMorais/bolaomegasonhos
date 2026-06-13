# Arquitetura e Roadmap — Bolão Mega Sonhos

## Visão Geral

O `bolao-mega` (projeto original) é uma aplicação de **bolão único por vez**, com um
admin central que cadastra participantes manualmente e gerencia cotas/pagamentos via
PIX (Mercado Pago + fallback local) e notificações por WhatsApp.

O **bolaomegasonhos**, inspirado no [unindosonhos.com.br](https://www.unindosonhos.com.br),
é uma **plataforma de marketplace de bolões** onde:

- Usuários se cadastram, têm carteira digital (saldo) e carrinho de compras.
- Vários bolões (de diferentes loterias e concursos) ficam disponíveis simultaneamente
  para compra de cotas.
- Após o sorteio, a apuração e o rateio de prêmios são automáticos, creditando o saldo
  na carteira do usuário.
- Existe um painel admin para gerenciar loterias, concursos, bolões, jogos apostados,
  usuários e saques.

**Decisões de stack:**
- Next.js 14 (App Router) + React 18 + TypeScript estrito + Supabase + Mercado Pago +
  CSS puro (sem Tailwind), reaproveitando os padrões validados no bolao-mega.
- Banco de dados: mesmo projeto Supabase do bolao-mega, em um **schema dedicado
  (`sonhos`)**, isolado do schema `public`.

---

## 1. Modelo de Dados (schema `sonhos` no Supabase)

Todas as tabelas vivem no schema `sonhos`, com migrations versionadas em
`db/migrations/*.sql` (diferente do bolao-mega, que não tinha migrations rastreadas).
Schema inicial completo: [`db/migrations/0001_init_sonhos_schema.sql`](../db/migrations/0001_init_sonhos_schema.sql).

### 1.1 Usuários e Carteira
- **`usuarios`**: id (uuid), nome, email (unique), senha_hash, cpf (opcional), telefone, role (`cliente` | `admin`), email_verificado, created_at.
- **`carteiras`**: usuario_id (FK, 1:1), saldo (numeric), atualizado_em.
- **`transacoes_carteira`**: id, usuario_id, tipo (`credito_compra` | `compra_cota` | `premio` | `saque` | `ajuste`), valor, saldo_apos, status (`pendente` | `concluida` | `cancelada`), referencia_externa (mp_payment_id), descricao, created_at.

### 1.2 Loterias, Concursos e Bolões
- **`loterias`**: id, codigo (`megasena`, `quina`, `lotofacil`, ...), nome, qtd_dezenas_aposta (ex: 6 para Mega), faixa_numerica (1-60), dias_sorteio.
- **`concursos`**: id, loteria_id (FK), numero_concurso, data_sorteio, premio_estimado, dezenas_sorteadas (int[], null até apurar), status (`aberto` | `realizado` | `apurado`).
- **`boloes`**: id, codigo (ex: `QN-52378604`), loteria_id, concurso_id (FK), total_cotas, cotas_vendidas, valor_cota, status (`aberto` | `fechado` | `apurado` | `pago` | `cancelado`), taxa_admin_pct, created_at.
- **`jogos_bolao`**: id, bolao_id (FK), dezenas (int[]), ordem — cada linha é uma das combinações apostadas dentro do bolão (equivalente ao "Ver o jogo" do Unindo Sonhos).

### 1.3 Cotas, Carrinho e Pedidos
- **`cotas`**: id, bolao_id (FK), usuario_id (FK), quantidade, valor_unitario, status (`reservada` | `confirmada` | `cancelada`), pedido_item_id (FK), created_at.
- **`pedidos`**: id, usuario_id, status (`pendente` | `pago` | `cancelado` | `expirado`), valor_total, forma_pagamento (`carteira` | `pix` | `cartao`), mp_payment_id, pix_code, created_at, pago_em.
- **`itens_pedido`**: id, pedido_id (FK), bolao_id (FK), quantidade_cotas, valor_unitario, subtotal.

### 1.4 Resultados e Rateio
- **`rateios`**: id, bolao_id (FK), usuario_id (FK), jogo_id (FK, opcional), faixa_premio (`sena` | `quina` | `quadra` | `terno` | `duque`), acertos, valor_premio, transacao_carteira_id (FK), created_at.
- **`saques`**: id, usuario_id, valor, chave_pix, status (`solicitado` | `processando` | `pago` | `rejeitado`), created_at, processado_em.

### 1.5 Config/Auditoria
- **`config`**: key/value (mesmo padrão do bolao-mega, para parâmetros globais: taxa padrão, tokens, etc).
- **`eventos_auditoria`**: id, usuario_id (nullable, admin), acao, entidade, entidade_id, payload (jsonb), created_at — log mínimo de ações sensíveis (alteração de saldo, apuração, saques).

---

## 2. Arquitetura de Aplicação

### 2.1 Autenticação
Reaproveita o padrão `jose` + `bcryptjs` do bolao-mega, estendido para multiusuário:
- Cookie `session_token` (httpOnly), JWT com `{ sub: usuario_id, role, exp }`, TTL configurável (ex.: 7 dias com refresh silencioso).
- `lib/auth.ts`: `criarSessao()`, `verificarSessao()`, `hashSenha()`, `compararSenha()`.
- Middleware leve (`middleware.ts`) para proteger rotas `/conta/*`, `/carrinho/*`, `/admin/*` redirecionando para login quando necessário — diferente do bolao-mega (que verificava token manualmente em cada rota), aqui centralizamos no middleware para reduzir repetição.
- Admin = usuário com `role = 'admin'`; sem "senha única" — qualquer usuário pode ser promovido a admin via `config`/seed.

### 2.2 Catálogo de Bolões (`/boloes`)
- Listagem server-rendered (RSC) com filtros (loteria, dia do sorteio, faixa de valor da cota) via query params — espelha a UX do Unindo Sonhos.
- Cada card mostra: loteria, concurso, prêmio estimado, contagem regressiva (client component), cotas vendidas/total, valor da cota, botão "Adicionar ao carrinho" com seletor de quantidade.
- Modal "Ver o jogo": busca `jogos_bolao` do bolão e exibe as combinações; aba "Informações do bolão" com dados do `concursos`/`boloes`.

### 2.3 Carteira Digital (`/carteira`)
- Saldo exibido no header (componente client com fetch periódico/SWR).
- `/carteira/comprar-creditos`: valores predefinidos + campo customizado → cria `pedido` (tipo crédito) → gera cobrança PIX via Mercado Pago (reusa `lib/mercadopago.ts`).
- `/carteira/extrato`: lista `transacoes_carteira` paginada.
- `/carteira/saque`: usuário solicita saque (cria `saques`, status `solicitado`); admin processa manualmente no painel (fase inicial — automação de saque fica para fase posterior).

### 2.4 Carrinho e Checkout (`/carrinho`)
- Carrinho client-side (localStorage + sincronização com `pedidos`/`itens_pedido` pendente no backend ao iniciar checkout).
- Checkout: escolher forma de pagamento — **saldo da carteira** (débito imediato em `transacoes_carteira`) **ou PIX/cartão** via Mercado Pago.
- Ao confirmar pagamento (webhook ou débito de saldo), `pedidos.status = 'pago'`, gera/atualiza `cotas` (status `confirmada`) e incrementa `boloes.cotas_vendidas`.

### 2.5 Apuração e Rateio Automático (motor central — diferencial do projeto)
- **Cron `/api/cron/sincronizar-concursos`**: busca resultados oficiais na API da Caixa e popula `concursos.dezenas_sorteadas`, `status = 'realizado'`.
- **Cron `/api/cron/apurar-boloes`**: para cada `bolao` com concurso `realizado` e status `fechado`:
  1. Para cada `jogo_bolao`, compara `dezenas` com `dezenas_sorteadas` → calcula acertos/faixa de prêmio.
  2. Calcula valor de prêmio por faixa (regra simplificada inicial: tabela de premiação fixa configurável em `config`, evoluindo depois para puxar prêmio real da Caixa).
  3. Distribui o prêmio proporcionalmente às `cotas` de cada usuário no bolão, cria `rateios` e `transacoes_carteira` (tipo `premio`), credita `carteiras.saldo`.
  4. Marca `boloes.status = 'apurado'` (depois `pago` quando todos os rateios forem confirmados).
- Esse motor é o coração do produto e deve ter testes automatizados dedicados (cálculo de rateio é sensível — dinheiro real).

### 2.6 Painel Admin (`/admin`)
- Gestão de loterias/concursos (cadastro manual + sync automático).
- Gestão de bolões: criar bolão (escolher loteria/concurso, definir cotas/valor), cadastrar `jogos_bolao` (combinações apostadas — manual ou geração aleatória).
- Gestão de usuários (busca, ajuste manual de saldo com auditoria).
- Gestão de saques (aprovar/rejeitar, marcar como pago).
- Dashboard com métricas (cotas vendidas, arrecadação, bolões apurados).

---

## 3. Estrutura de Pastas

```
bolaomegasonhos/
├── app/
│   ├── (site)/
│   │   ├── page.tsx                # Home institucional
│   │   ├── como-funciona/page.tsx
│   │   └── quem-somos/page.tsx
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   └── cadastro/page.tsx
│   ├── boloes/
│   │   ├── page.tsx                # Catálogo + filtros
│   │   └── [codigo]/page.tsx       # Detalhe
│   ├── carrinho/page.tsx
│   ├── carteira/
│   │   ├── page.tsx                # Saldo + ações
│   │   ├── comprar-creditos/page.tsx
│   │   ├── extrato/page.tsx
│   │   └── saque/page.tsx
│   ├── conta/
│   │   ├── page.tsx                # Perfil
│   │   └── meus-boloes/page.tsx    # Cotas do usuário + histórico
│   ├── admin/
│   │   ├── page.tsx                # Dashboard
│   │   ├── loterias/
│   │   ├── concursos/
│   │   ├── boloes/
│   │   ├── usuarios/
│   │   └── saques/
│   ├── api/
│   │   ├── auth/{login,cadastro,logout}/route.ts
│   │   ├── boloes/route.ts
│   │   ├── boloes/[codigo]/route.ts
│   │   ├── carrinho/route.ts
│   │   ├── carteira/{extrato,comprar-creditos,saque}/route.ts
│   │   ├── pix/route.ts
│   │   ├── webhook/mercadopago/route.ts
│   │   ├── cron/{sincronizar-concursos,apurar-boloes}/route.ts
│   │   └── admin/{loterias,concursos,boloes,usuarios,saques}/route.ts
│   ├── layout.tsx
│   ├── globals.css
│   └── manifest.ts
├── components/
│   ├── catalog/ (BolaoCard, FiltroBoloes, ModalJogos)
│   ├── cart/ (CarrinhoResumo, ItemCarrinho)
│   ├── wallet/ (SaldoBadge, ExtratoTabela)
│   ├── admin/
│   └── ui/ (Button, Modal, Input, Badge — design system compartilhado)
├── lib/
│   ├── supabase.ts          # client com schema 'sonhos'
│   ├── auth.ts
│   ├── mercadopago.ts
│   ├── wallet.ts            # débito/crédito atômico de saldo
│   ├── loteria/
│   │   ├── apuracao.ts      # cálculo de acertos/faixas
│   │   └── caixa-api.ts     # sync de concursos oficiais
│   └── types.ts
├── db/
│   └── migrations/
│       └── 0001_init_sonhos_schema.sql
├── middleware.ts
├── public/
├── next.config.js
├── tsconfig.json
├── vercel.json
├── package.json
└── README.md
```

---

## 4. Roadmap por Etapas

| Etapa | Entregável | Principais arquivos/áreas |
|---|---|---|
| **0 — Setup** | Scaffold Next.js + configs + README + doc de arquitetura + migration inicial do schema `sonhos` | raiz do projeto, `db/migrations/0001_init_sonhos_schema.sql` |
| **1 — Autenticação** | Cadastro/login/logout, sessão JWT, middleware de rotas protegidas | `lib/auth.ts`, `app/(auth)/*`, `app/api/auth/*`, `middleware.ts` |
| **2 — Domínio core** | CRUD admin de loterias, concursos e bolões (incl. `jogos_bolao`) | `app/admin/{loterias,concursos,boloes}`, `app/api/admin/*` |
| **3 — Catálogo público** | `/boloes` com filtros, cards, modal "ver jogo" | `app/boloes/*`, `components/catalog/*` |
| **4 — Carteira digital** | Saldo, extrato, comprar créditos (PIX/Mercado Pago) | `app/carteira/*`, `lib/wallet.ts`, `lib/mercadopago.ts` |
| **5 — Carrinho/checkout** | Carrinho, pedidos, pagamento via saldo ou PIX, geração de cotas | `app/carrinho/*`, `app/api/carrinho/*`, `app/api/webhook/mercadopago` |
| **6 — Apuração automática** | Sync de concursos (API Caixa) + motor de rateio | `app/api/cron/*`, `lib/loteria/*` (com testes unitários do cálculo) |
| **7 — Saques e notificações** | Fluxo de saque + emails/WhatsApp de eventos (compra, prêmio, saque) | `app/carteira/saque`, `app/admin/saques`, integração de notificação |
| **8 — Admin completo** | Dashboard métricas, gestão de usuários/saldo com auditoria | `app/admin/*`, `eventos_auditoria` |
| **9 — Polimento & deploy** | Testes E2E críticos, revisão de segurança, deploy Vercel, monitoramento | CI, `vercel.json`, observabilidade |

Cada etapa a partir da 1 é conduzida como um ciclo próprio de planejamento + implementação,
permitindo revisão incremental antes de avançar.

---

## 5. Status da Etapa 0 (Setup)

- [x] Estrutura de pastas do projeto Next.js 14 + TS estrito
- [x] `package.json`, `tsconfig.json`, `next.config.js`, `.gitignore`, `.env.example`
- [x] `lib/supabase.ts` apontando para o schema `sonhos`
- [x] `lib/types.ts` com os tipos do domínio
- [x] `db/migrations/0001_init_sonhos_schema.sql`
- [x] `app/layout.tsx` + `app/globals.css` (design tokens) + `app/page.tsx` placeholder
- [x] `README.md` + este documento
- [ ] Repositório conectado ao remoto e push inicial (a cargo do usuário)
- [ ] Execução da migration no Supabase (a cargo do usuário, após revisão)
