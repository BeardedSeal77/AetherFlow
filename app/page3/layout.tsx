'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { motion, AnimatePresence } from 'framer-motion'
import { useEffect, useState } from 'react'

export default function Page3Layout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    // Show the navbar when component mounts
    setIsVisible(true)
    
    // Hide the navbar when component unmounts
    return () => setIsVisible(false)
  }, [])

  return (
    <div>
      <AnimatePresence>
        {isVisible && (
          <motion.div 
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="bg-overlay backdrop-blur-md border-t border-highlight/20 shadow-inner rounded-b-lg -mt-2"
          >
            <div className="flex space-x-3 px-6 py-2">
              <Link
                href="/page3"
                className={`px-4 py-1 rounded-md text-sm font-medium transition ${
                  pathname === '/page3'
                    ? 'bg-gold/30 text-gold'
                    : 'bg-highlight/10 hover:bg-highlight/20 text-highlight'
                }`}
              >
                Overview
              </Link>
              <Link
                href="/page3/details"
                className={`px-4 py-1 rounded-md text-sm font-medium transition ${
                  pathname === '/page3/details'
                    ? 'bg-gold/30 text-gold'
                    : 'bg-highlight/10 hover:bg-highlight/20 text-highlight'
                }`}
              >
                Details
              </Link>
              <Link
                href="/page3/settings"
                className={`px-4 py-1 rounded-md text-sm font-medium transition ${
                  pathname === '/page3/settings'
                    ? 'bg-gold/30 text-gold'
                    : 'bg-highlight/10 hover:bg-highlight/20 text-highlight'
                }`}
              >
                Settings
              </Link>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      
      <div className="mt-4">
        {children}
      </div>
    </div>
  )
}