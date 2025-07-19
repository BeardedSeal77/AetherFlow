// app/diary/hires/layout.tsx
'use client'

import { useEffect } from 'react'
import { usePathname, useRouter } from 'next/navigation'

const HIRES_RIBBON_ITEMS = [
  { key: 'dashboard', url: '/diary/hires', displayName: 'Dashboard' },
  { key: 'view', url: '/diary/hires/view', displayName: 'View All' },
  { key: 'allocate', url: '/diary/hires/allocate', displayName: 'Allocate' },
  { key: 'new', url: '/diary/hires/new', displayName: 'New Hire' },
  { key: 'off-hire', url: '/diary/hires/off-hire', displayName: 'Off-Hires' },
  { key: 'breakdowns', url: '/diary/hires/breakdowns', displayName: 'Breakdowns' },
  { key: 'reports', url: '/diary/hires/reports', displayName: 'Reports' }
]

export default function HiresLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const router = useRouter()

  useEffect(() => {
    // Only add sub-ribbon when we're in the hires section
    if (!pathname.startsWith('/diary/hires')) return

    // Get or create the sub-ribbon container (Level 3)
    let subRibbonContainer = document.getElementById('sub-ribbon-container')
    
    if (!subRibbonContainer) {
      // Create sub-ribbon container if it doesn't exist
      const ribbonContainer = document.getElementById('ribbon-container')
      if (ribbonContainer) {
        subRibbonContainer = document.createElement('div')
        subRibbonContainer.id = 'sub-ribbon-container'
        subRibbonContainer.className = 'bg-overlay/30 border-t border-highlight-low/50'
        ribbonContainer.parentNode?.insertBefore(subRibbonContainer, ribbonContainer.nextSibling)
      }
    }

    if (subRibbonContainer) {
      subRibbonContainer.style.display = 'block'
      subRibbonContainer.innerHTML = ''
      
      // Create hires sub-ribbon (Level 3)
      const subRibbon = document.createElement('div')
      subRibbon.className = 'flex justify-between items-center px-6 py-2'
      
      // Navigation items
      const navGroup = document.createElement('div')
      navGroup.className = 'flex space-x-2'
      
      HIRES_RIBBON_ITEMS.forEach(item => {
        const button = document.createElement('button')
        button.textContent = item.displayName
        button.className = `px-3 py-1.5 rounded text-sm transition-colors ${
          pathname === item.url || (pathname === '/diary/hires' && item.key === 'dashboard')
            ? 'bg-blue text-white shadow-sm' 
            : 'text-subtle hover:bg-highlight-low hover:text-text'
        }`
        button.onclick = () => {
          router.push(item.url)
        }
        navGroup.appendChild(button)
      })
      
      // Add breadcrumb
      const breadcrumb = document.createElement('div')
      breadcrumb.className = 'text-xs text-subtle'
      const currentPage = HIRES_RIBBON_ITEMS.find(item => pathname === item.url)
      breadcrumb.textContent = `Diary › Hires${currentPage ? ` › ${currentPage.displayName}` : ''}`
      
      subRibbon.appendChild(navGroup)
      subRibbon.appendChild(breadcrumb)
      subRibbonContainer.appendChild(subRibbon)
    }
    
    // Cleanup function
    return () => {
      if (!pathname?.startsWith('/diary/hires')) {
        const subRibbonContainer = document.getElementById('sub-ribbon-container')
        if (subRibbonContainer) {
          subRibbonContainer.style.display = 'none'
          subRibbonContainer.innerHTML = ''
        }
      }
    }
  }, [pathname, router])

  return <>{children}</>
}