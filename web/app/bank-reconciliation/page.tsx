'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function BankReconciliationRedirect() {
  const router = useRouter()
  useEffect(() => { router.replace('/collections?section=bank') }, [router])
  return null
}
