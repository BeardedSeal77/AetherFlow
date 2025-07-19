// app/layout.tsx
import { Inter } from 'next/font/google'
import './globals.css'
import Navbar from './components/Navbar'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'ToolHire System',
  description: 'Tool hire company diary and logistics system',
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
      <body className={`bg-base text-text ${inter.className}`}>
        {/* Level 1: Main Navbar - appears on ALL pages */}
        <Navbar />
        
        {/* Main content area - no padding since pages handle their own layout */}
        <main>
          {children}
        </main>
      </body>
    </html>
  )
}