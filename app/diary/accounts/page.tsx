'use client'

import { useRouter } from 'next/navigation'
import AuthCheck from '../../auth/AuthCheck'

export default function AccountsPage() {
  const router = useRouter()

  const accountsActions = [
    {
      title: 'Account Statements',
      description: 'Create and manage customer account statements',
      icon: '📄',
      href: '/diary/accounts/statements',
      color: 'bg-blue'
    },
    {
      title: 'Quotes',
      description: 'Generate and manage customer quotes',
      icon: '💰',
      href: '/diary/accounts/quotes',
      color: 'bg-green'
    },
    {
      title: 'Price Lists',
      description: 'Manage equipment and service price lists',
      icon: '📋',
      href: '/diary/accounts/price-lists',
      color: 'bg-iris'
    },
    {
      title: 'Refunds',
      description: 'Process customer refunds and credits',
      icon: '💸',
      href: '/diary/accounts/refunds',
      color: 'bg-gold'
    },
    {
      title: 'Coring Jobs',
      description: 'Manage outsourced coring work',
      icon: '🔩',
      href: '/diary/accounts/coring',
      color: 'bg-pine'
    },
    {
      title: 'Misc Tasks',
      description: 'Other accounting and administrative tasks',
      icon: '📝',
      href: '/diary/accounts/misc',
      color: 'bg-rose'
    }
  ]

  const pendingTasks = [
    { type: 'Statement', customer: 'ABC Construction Ltd', due: 'Today', priority: 'high' },
    { type: 'Quote', customer: 'Metro Building Services', due: 'Tomorrow', priority: 'normal' },
    { type: 'Refund', customer: 'City Contractors', due: 'Overdue', priority: 'urgent' },
    { type: 'Price Update', customer: 'Internal', due: 'This Week', priority: 'low' },
  ]

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'text-red bg-red/10 border-red'
      case 'high': return 'text-gold bg-gold/10 border-gold'
      case 'normal': return 'text-blue bg-blue/10 border-blue'
      case 'low': return 'text-subtle bg-subtle/10 border-subtle'
      default: return 'text-subtle bg-subtle/10 border-subtle'
    }
  }

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <h1 className="text-2xl font-bold text-gold">Accounts Management</h1>
            <p className="text-subtle mt-1">
              Manage statements, quotes, price lists, refunds, and administrative tasks
            </p>
          </div>
        </div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            
            {/* Accounts Actions */}
            <div className="lg:col-span-2">
              <h2 className="text-xl font-semibold text-text mb-4">Account Functions</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {accountsActions.map((action, index) => (
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
            </div>

            {/* Pending Tasks */}
            <div>
              <h2 className="text-xl font-semibold text-text mb-4">Pending Tasks</h2>
              <div className="bg-surface border border-highlight-low rounded-lg p-6">
                <div className="space-y-4">
                  {pendingTasks.map((task, index) => (
                    <div key={index} className={`border rounded-lg p-4 ${getPriorityColor(task.priority)}`}>
                      <div className="flex justify-between items-start mb-2">
                        <div className="font-semibold text-text">{task.type}</div>
                        <span className={`px-2 py-1 rounded text-xs font-medium ${getPriorityColor(task.priority)}`}>
                          {task.priority.toUpperCase()}
                        </span>
                      </div>
                      <div className="text-sm text-subtle mb-1">{task.customer}</div>
                      <div className="text-sm text-text">Due: {task.due}</div>
                    </div>
                  ))}
                </div>
                
                <button className="w-full mt-4 p-3 bg-gold text-base rounded-lg hover:bg-gold/80 transition-colors">
                  View All Tasks
                </button>
              </div>
            </div>
          </div>

          {/* Summary Cards */}
          <div className="mt-8 grid grid-cols-1 md:grid-cols-4 gap-6">
            <div className="bg-surface border border-highlight-low rounded-lg p-6 text-center">
              <div className="text-2xl mb-2">📄</div>
              <div className="text-2xl font-bold text-blue mb-1">23</div>
              <div className="text-sm text-subtle">Pending Statements</div>
            </div>
            
            <div className="bg-surface border border-highlight-low rounded-lg p-6 text-center">
              <div className="text-2xl mb-2">💰</div>
              <div className="text-2xl font-bold text-green mb-1">8</div>
              <div className="text-sm text-subtle">Active Quotes</div>
            </div>
            
            <div className="bg-surface border border-highlight-low rounded-lg p-6 text-center">
              <div className="text-2xl mb-2">💸</div>
              <div className="text-2xl font-bold text-gold mb-1">3</div>
              <div className="text-sm text-subtle">Pending Refunds</div>
            </div>
            
            <div className="bg-surface border border-highlight-low rounded-lg p-6 text-center">
              <div className="text-2xl mb-2">🔩</div>
              <div className="text-2xl font-bold text-pine mb-1">5</div>
              <div className="text-sm text-subtle">Coring Jobs</div>
            </div>
          </div>

          {/* Recent Activity */}
          <div className="mt-8 bg-surface border border-highlight-low rounded-lg p-6">
            <h2 className="text-xl font-semibold text-text mb-4">Recent Activity</h2>
            <div className="text-center py-8 text-subtle">
              <div className="text-4xl mb-3">📊</div>
              <p>Recent account activity will be displayed here</p>
              <p className="text-sm mt-2">Statements, quotes, payments, and other account events</p>
            </div>
          </div>
        </div>
      </div>
    </AuthCheck>
  )
}