import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Bolão Mega Sonhos',
  description: 'Plataforma de bolões da Mega-Sena, Quina e Lotofácil com carteira digital e rateio automático de prêmios.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  )
}
