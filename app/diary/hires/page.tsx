'use client'

import { useRouter } from 'next/navigation'
import AuthCheck from '../../auth/AuthCheck'

export default function HiresPage() {
  const router = useRouter()

  const hiresActions = [
    {
      title: 'New Equipment Hire',
      description: 'Create a new equipment hire for a customer',
      icon: '➕',
      href: '/diary/hires/new',
      color: 'bg-green'
    },
    {
      title: 'View All Hires',
      description: 'View and manage all current hires',
      icon: '📋',
      href: '/diary/hires/view',
      color: 'bg-blue'
    },
    {
      title: 'Equipment Allocation',
      description: 'Allocate specific equipment to pending hires',
      icon: '🎯',
      href: '/diary/hires/allocate',
      color: 'bg-iris'
    },
    {
      title: 'Off-Hires',
      description: 'Process equipment returns and off-hires',
      icon: '📤',
      href: '/diary/hires/off-hire',
      color: 'bg-gold'
    },
    {
      title: 'Breakdowns & Swaps',
      description: 'Handle equipment breakdowns and swaps',
      icon: '🔧',
      href: '/diary/hires/breakdowns',
      color: 'bg-red'
    },
    {
      title: 'Hire Reports',
      description: 'Generate reports on equipment hires',
      icon: '📊',
      href: '/diary/hires/reports',
      color: 'bg-pine'
    }
  ]

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <h1 className="text-2xl font-bold text-gold">Hires Management</h1>
            <p className="text-subtle mt-1">
              Manage equipment hires, allocations, off-hires, and breakdowns
            </p>
          </div>
        </div>

        {/* Hires Actions */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {hiresActions.map((action, index) => (
              <div
                key={index}
                onClick={() => router.push(action.href)}
                className="bg-surface border border-highlight-low rounded-lg p-6 hover:border-gold cursor-pointer transition-colors"
              >
                <div className="text-center">
                  <div className="text-4xl mb-3">{action.icon}</div>
                  <h3 className="font-semibold text-text mb-2">{action.title}</h3>
                  <p className="text-sm text-subtle">{action.description}</p>
                </div>
              </div>
            ))}
          </div>

          {/* Recent Hires Summary */}
          <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="bg-surface border border-highlight-low rounded-lg p-6">
              <h3 className="font-semibold text-text mb-2">Pending Allocation</h3>
              <div className="text-3xl font-bold text-gold mb-2">12</div>
              <p className="text-sm text-subtle">Hires awaiting equipment allocation</p>
            </div>
            
            <div className="bg-surface border border-highlight-low rounded-lg p-6">
              <h3 className="font-semibold text-text mb-2">Out on Hire</h3>
              <div className="text-3xl font-bold text-blue mb-2">45</div>
              <p className="text-sm text-subtle">Equipment currently on hire</p>
            </div>
            
            <div className="bg-surface border border-highlight-low rounded-lg p-6">
              <h3 className="font-semibold text-text mb-2">Due Back Today</h3>
              <div className="text-3xl font-bold text-gold mb-2">8</div>
              <p className="text-sm text-subtle">Equipment due for collection</p>
            </div>
          </div>

          {/* Quick Filters */}
          <div className="mt-8 bg-surface border border-highlight-low rounded-lg p-6">
            <h2 className="text-xl font-semibold text-text mb-4">Quick Filters</h2>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <button className="p-3 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-left">
                <div className="font-medium text-text">Urgent Hires</div>
                <div className="text-sm text-subtle">3 items</div>
              </button>
              <button className="p-3 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-left">
                <div className="font-medium text-text">Today's Deliveries</div>
                <div className="text-sm text-subtle">15 items</div>
              </button>
              <button className="p-3 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-left">
                <div className="font-medium text-text">Overdue Returns</div>
                <div className="text-sm text-subtle">2 items</div>
              </button>
              <button className="p-3 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-left">
                <div className="font-medium text-text">Problem Hires</div>
                <div className="text-sm text-subtle">1 item</div>
              </button>
            </div>
          </div>
        </div>
      </div>
    </AuthCheck>
  )
}