// Tipos do domínio bolaomegasonhos — refletem o schema "sonhos" (supabase/migrations/20260613000000_init_sonhos_schema.sql)

export type Role = 'cliente' | 'admin'

export interface Usuario {
  id: string
  nome: string
  email: string
  cpf: string | null
  telefone: string | null
  role: Role
  email_verificado: boolean
  created_at: string
}

export interface Carteira {
  usuario_id: string
  saldo: number
  atualizado_em: string
}

export type TipoTransacao = 'credito_compra' | 'compra_cota' | 'premio' | 'saque' | 'ajuste'
export type StatusTransacao = 'pendente' | 'concluida' | 'cancelada'

export interface TransacaoCarteira {
  id: string
  usuario_id: string
  tipo: TipoTransacao
  valor: number
  saldo_apos: number
  status: StatusTransacao
  referencia_externa: string | null
  descricao: string | null
  created_at: string
}

export interface Loteria {
  id: string
  codigo: string
  nome: string
  qtd_dezenas_aposta: number
  faixa_numerica_min: number
  faixa_numerica_max: number
  dias_sorteio: number[]
}

export type StatusConcurso = 'aberto' | 'realizado' | 'apurado'

export interface Concurso {
  id: string
  loteria_id: string
  numero_concurso: number
  data_sorteio: string
  premio_estimado: number | null
  dezenas_sorteadas: number[] | null
  status: StatusConcurso
}

export type StatusBolao = 'aberto' | 'fechado' | 'apurado' | 'pago' | 'cancelado'

export interface Bolao {
  id: string
  codigo: string
  loteria_id: string
  concurso_id: string
  total_cotas: number
  cotas_vendidas: number
  valor_cota: number
  status: StatusBolao
  taxa_admin_pct: number
  created_at: string
}

export interface JogoBolao {
  id: string
  bolao_id: string
  dezenas: number[]
  ordem: number
}

export type StatusCota = 'reservada' | 'confirmada' | 'cancelada'

export interface Cota {
  id: string
  bolao_id: string
  usuario_id: string
  quantidade: number
  valor_unitario: number
  status: StatusCota
  pedido_item_id: string | null
  created_at: string
}

export type StatusPedido = 'pendente' | 'pago' | 'cancelado' | 'expirado'
export type FormaPagamento = 'carteira' | 'pix' | 'cartao'

export interface Pedido {
  id: string
  usuario_id: string
  status: StatusPedido
  valor_total: number
  forma_pagamento: FormaPagamento
  mp_payment_id: string | null
  pix_code: string | null
  created_at: string
  pago_em: string | null
}

export interface ItemPedido {
  id: string
  pedido_id: string
  bolao_id: string
  quantidade_cotas: number
  valor_unitario: number
  subtotal: number
}

export type FaixaPremio = 'sena' | 'quina' | 'quadra' | 'terno' | 'duque'

export interface Rateio {
  id: string
  bolao_id: string
  usuario_id: string
  jogo_id: string | null
  faixa_premio: FaixaPremio
  acertos: number
  valor_premio: number
  transacao_carteira_id: string | null
  created_at: string
}

export type StatusSaque = 'solicitado' | 'processando' | 'pago' | 'rejeitado'

export interface Saque {
  id: string
  usuario_id: string
  valor: number
  chave_pix: string
  status: StatusSaque
  created_at: string
  processado_em: string | null
}
