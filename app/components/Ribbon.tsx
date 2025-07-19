// app/components/Ribbon.tsx - DEBUG VERSION
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
    console.log('🎗️ Ribbon Effect Running:', { 
      basePath, 
      pathname, 
      items: items.map(i => ({ key: i.key, url: i.url, name: i.displayName }))
    })

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
        
        // DEBUG: Add logging to button click
        button.onclick = () => {
          console.log('🔥 Button Clicked:', {
            displayName: item.displayName,
            key: item.key,
            url: item.url,
            currentPath: pathname,
            basePath: basePath
          })
          
          // Navigate to the item's URL
          router.push(item.url)
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

  // Handle automatic routing to default route ONLY for exact basePath matches
  useEffect(() => {
    console.log('🚀 Auto-redirect Effect:', {
      pathname,
      basePath,
      isExactMatch: pathname === basePath,
      defaultRoute
    })

    // Only redirect if we're on the EXACT basePath, not sub-paths
    if (pathname === basePath && defaultRoute) {
      const defaultItem = items.find(item => item.key === defaultRoute)
      if (defaultItem) {
        console.log('🎯 Auto-redirecting to:', defaultItem.url)
        router.replace(defaultItem.url)
      }
    }
  }, [pathname, router, basePath, defaultRoute, items])

  return null // This component doesn't render anything directly
}