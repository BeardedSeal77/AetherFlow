'use client'

import Ribbon from '../components/Ribbon'

const DIARY_RIBBON_ITEMS = [
  { key: 'dashboard', url: '/diary/dashboard', displayName: 'Dashboard' },
  { key: 'drivers', url: '/diary/drivers', displayName: 'Drivers Schedule' },
  { key: 'hires', url: '/diary/hires', displayName: 'Hires' },
  { key: 'accounts', url: '/diary/accounts', displayName: 'Accounts' }
]

export default function DiaryLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <>
      <Ribbon 
        items={DIARY_RIBBON_ITEMS}
        basePath="/diary"
        defaultRoute="dashboard"
      />
      {children}
    </>
  )
}