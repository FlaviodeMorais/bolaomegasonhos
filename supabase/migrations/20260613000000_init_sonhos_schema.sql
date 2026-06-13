-- ============================================================
-- bolaomegasonhos — schema inicial "sonhos"
-- Isolado do schema "public" (usado pelo bolao-mega) no mesmo
-- projeto Supabase.
-- ============================================================

create schema if not exists sonhos;

-- ─── extensões necessárias (uuid) ───────────────────────────
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. USUÁRIOS E CARTEIRA
-- ============================================================

create table sonhos.usuarios (
  id               uuid primary key default gen_random_uuid(),
  nome             text not null,
  email            text not null unique,
  senha_hash       text not null,
  cpf              text,
  telefone         text,
  role             text not null default 'cliente' check (role in ('cliente', 'admin')),
  email_verificado boolean not null default false,
  created_at       timestamptz not null default now()
);

create table sonhos.carteiras (
  usuario_id   uuid primary key references sonhos.usuarios(id) on delete cascade,
  saldo        numeric(12,2) not null default 0,
  atualizado_em timestamptz not null default now()
);

create table sonhos.transacoes_carteira (
  id                  uuid primary key default gen_random_uuid(),
  usuario_id          uuid not null references sonhos.usuarios(id) on delete cascade,
  tipo                text not null check (tipo in ('credito_compra', 'compra_cota', 'premio', 'saque', 'ajuste')),
  valor               numeric(12,2) not null,
  saldo_apos          numeric(12,2) not null,
  status              text not null default 'concluida' check (status in ('pendente', 'concluida', 'cancelada')),
  referencia_externa  text,
  descricao           text,
  created_at          timestamptz not null default now()
);

create index idx_transacoes_carteira_usuario on sonhos.transacoes_carteira(usuario_id);

-- ============================================================
-- 2. LOTERIAS, CONCURSOS E BOLÕES
-- ============================================================

create table sonhos.loterias (
  id                  uuid primary key default gen_random_uuid(),
  codigo              text not null unique, -- 'megasena', 'quina', 'lotofacil', ...
  nome                text not null,
  qtd_dezenas_aposta  integer not null,
  faixa_numerica_min  integer not null default 1,
  faixa_numerica_max  integer not null,
  dias_sorteio        integer[] not null default '{}' -- 0=domingo .. 6=sábado
);

create table sonhos.concursos (
  id                  uuid primary key default gen_random_uuid(),
  loteria_id          uuid not null references sonhos.loterias(id) on delete cascade,
  numero_concurso     integer not null,
  data_sorteio        timestamptz not null,
  premio_estimado     numeric(14,2),
  dezenas_sorteadas   integer[],
  status              text not null default 'aberto' check (status in ('aberto', 'realizado', 'apurado')),
  unique (loteria_id, numero_concurso)
);

create table sonhos.boloes (
  id              uuid primary key default gen_random_uuid(),
  codigo          text not null unique,
  loteria_id      uuid not null references sonhos.loterias(id) on delete restrict,
  concurso_id     uuid not null references sonhos.concursos(id) on delete restrict,
  total_cotas     integer not null,
  cotas_vendidas  integer not null default 0,
  valor_cota      numeric(10,2) not null,
  status          text not null default 'aberto' check (status in ('aberto', 'fechado', 'apurado', 'pago', 'cancelado')),
  taxa_admin_pct  numeric(5,2) not null default 0,
  created_at      timestamptz not null default now()
);

create index idx_boloes_status on sonhos.boloes(status);
create index idx_boloes_concurso on sonhos.boloes(concurso_id);

create table sonhos.jogos_bolao (
  id        uuid primary key default gen_random_uuid(),
  bolao_id  uuid not null references sonhos.boloes(id) on delete cascade,
  dezenas   integer[] not null,
  ordem     integer not null default 0
);

create index idx_jogos_bolao_bolao on sonhos.jogos_bolao(bolao_id);

-- ============================================================
-- 3. COTAS, CARRINHO E PEDIDOS
-- ============================================================

create table sonhos.pedidos (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid not null references sonhos.usuarios(id) on delete cascade,
  status          text not null default 'pendente' check (status in ('pendente', 'pago', 'cancelado', 'expirado')),
  valor_total     numeric(12,2) not null,
  forma_pagamento text not null check (forma_pagamento in ('carteira', 'pix', 'cartao')),
  mp_payment_id   text,
  pix_code        text,
  created_at      timestamptz not null default now(),
  pago_em         timestamptz
);

create index idx_pedidos_usuario on sonhos.pedidos(usuario_id);

create table sonhos.itens_pedido (
  id                uuid primary key default gen_random_uuid(),
  pedido_id         uuid not null references sonhos.pedidos(id) on delete cascade,
  bolao_id          uuid not null references sonhos.boloes(id) on delete restrict,
  quantidade_cotas  integer not null,
  valor_unitario    numeric(10,2) not null,
  subtotal          numeric(12,2) not null
);

create index idx_itens_pedido_pedido on sonhos.itens_pedido(pedido_id);

create table sonhos.cotas (
  id              uuid primary key default gen_random_uuid(),
  bolao_id        uuid not null references sonhos.boloes(id) on delete restrict,
  usuario_id      uuid not null references sonhos.usuarios(id) on delete restrict,
  quantidade      integer not null,
  valor_unitario  numeric(10,2) not null,
  status          text not null default 'reservada' check (status in ('reservada', 'confirmada', 'cancelada')),
  pedido_item_id  uuid references sonhos.itens_pedido(id) on delete set null,
  created_at      timestamptz not null default now()
);

create index idx_cotas_bolao on sonhos.cotas(bolao_id);
create index idx_cotas_usuario on sonhos.cotas(usuario_id);

-- ============================================================
-- 4. RESULTADOS E RATEIO
-- ============================================================

create table sonhos.rateios (
  id                      uuid primary key default gen_random_uuid(),
  bolao_id                uuid not null references sonhos.boloes(id) on delete restrict,
  usuario_id              uuid not null references sonhos.usuarios(id) on delete restrict,
  jogo_id                 uuid references sonhos.jogos_bolao(id) on delete set null,
  faixa_premio            text not null check (faixa_premio in ('sena', 'quina', 'quadra', 'terno', 'duque')),
  acertos                 integer not null,
  valor_premio            numeric(12,2) not null,
  transacao_carteira_id   uuid references sonhos.transacoes_carteira(id) on delete set null,
  created_at              timestamptz not null default now()
);

create index idx_rateios_bolao on sonhos.rateios(bolao_id);
create index idx_rateios_usuario on sonhos.rateios(usuario_id);

create table sonhos.saques (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid not null references sonhos.usuarios(id) on delete cascade,
  valor           numeric(12,2) not null,
  chave_pix       text not null,
  status          text not null default 'solicitado' check (status in ('solicitado', 'processando', 'pago', 'rejeitado')),
  created_at      timestamptz not null default now(),
  processado_em   timestamptz
);

create index idx_saques_usuario on sonhos.saques(usuario_id);

-- ============================================================
-- 5. CONFIG E AUDITORIA
-- ============================================================

create table sonhos.config (
  key         text primary key,
  value       text not null,
  updated_at  timestamptz not null default now()
);

create table sonhos.eventos_auditoria (
  id          uuid primary key default gen_random_uuid(),
  usuario_id  uuid references sonhos.usuarios(id) on delete set null,
  acao        text not null,
  entidade    text not null,
  entidade_id text,
  payload     jsonb,
  created_at  timestamptz not null default now()
);

create index idx_eventos_auditoria_entidade on sonhos.eventos_auditoria(entidade, entidade_id);

-- ============================================================
-- 6. SEED inicial — loterias suportadas
-- ============================================================

insert into sonhos.loterias (codigo, nome, qtd_dezenas_aposta, faixa_numerica_min, faixa_numerica_max, dias_sorteio) values
  ('megasena',  'Mega-Sena',  6, 1, 60, '{2,4,6}'),
  ('quina',     'Quina',      5, 1, 80, '{0,1,2,3,4,5,6}'),
  ('lotofacil', 'Lotofácil', 15, 1, 25, '{0,1,2,3,4,5,6}');
