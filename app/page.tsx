export default function HomePage() {
  return (
    <main
      style={{
        minHeight: '100svh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 'var(--s4)',
        textAlign: 'center',
        padding: 'var(--s6)',
      }}
    >
      <h1 style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--navy)' }}>
        🍀 Bolão Mega Sonhos
      </h1>
      <p style={{ color: 'var(--gray-600)', maxWidth: 480 }}>
        Plataforma em construção. Catálogo de bolões, carteira digital, carrinho
        de compras e rateio automático de prêmios.
      </p>
    </main>
  )
}
