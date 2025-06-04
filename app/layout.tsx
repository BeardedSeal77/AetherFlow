// app/layout.tsx
import { Inter } from 'next/font/google'
import './globals.css'
import Navbar from '@/components/Navbar'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'My Site',
  description: 'My Next.js + Flask application',
  icons: {
    icon: '/images/favicon.png',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <meta charSet="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </head>
      <body className={`bg-base text-text rounded-xl ${inter.className}`}>
        <Navbar />
        <main className="p-6">
          {children}
        </main>
      </body>
    </html>
  )
}