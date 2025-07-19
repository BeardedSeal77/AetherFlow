'use client'

import { usePathname, useRouter } from 'next/navigation'
import { useEffect } from 'react'

interface RibbonItem {
  key: string
  url: string
  displayName: string
}

interface RibbonProps {
  items: RibbonItem[]
  basePath: string
  defaultRoute?: string
}

export default function Ribbon({ items, basePath, defaultRoute }: RibbonProps) {
  const pathname = usePathname()
  const router = useRouter()

  useEffect(() => {
    // Show the ribbon
    const container = document.getElementById('ribbon-container')
    if (container) {
      container.style.display = 'block'
      
      // Clear existing content
      container.innerHTML = ''
      
      // Create ribbon content
      const ribbon = document.createElement('div')
      ribbon.className = 'flex justify-between items-center px-6 py-3'
      
      // Navigation items
      const navGroup = document.createElement('div')
      navGroup.className = 'flex space-x-4'
      
      items.forEach(item => {
        const button = document.createElement('button')
        button.textContent = item.displayName
        button.className = `px-3 py-2 rounded-lg text-sm transition-colors ${
          pathname === item.url || (pathname === basePath && item.key === defaultRoute)
            ? 'bg-gold/30 text-gold' 
            : 'text-text hover:bg-overlay'
        }`
        button.onclick = () => {
          if (pathname === basePath && item.key === defaultRoute) {
            router.replace(item.url)
          } else {
            router.push(item.url)
          }
        }
        navGroup.appendChild(button)
      })
      
      ribbon.appendChild(navGroup)
      container.appendChild(ribbon)
    }
    
    // Cleanup function to hide ribbon when leaving the section
    return () => {
      if (!pathname?.startsWith(basePath)) {
        const container = document.getElementById('ribbon-container')
        if (container) {
          container.style.display = 'none'
        }
      }
    }
  }, [pathname, router, items, basePath, defaultRoute])

  // Handle automatic routing to default route
  useEffect(() => {
    if (pathname === basePath && defaultRoute) {
      const defaultItem = items.find(item => item.key === defaultRoute)
      if (defaultItem) {
        router.replace(defaultItem.url)
      }
    }
  }, [pathname, router, basePath, defaultRoute, items])

  return null // This component doesn't render anything directly
}