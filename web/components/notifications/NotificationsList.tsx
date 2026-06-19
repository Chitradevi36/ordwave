import React from 'react'

export default function NotificationsList({ items }: any) {
  if (!items || items.length === 0) return <div className="p-4">No notifications</div>
  return (
    <div className="p-4">
      <h1 className="text-xl font-bold">Notifications</h1>
      <ul>
        {items.map((n: any) => (
          <li key={n.id} className={`p-2 border-b ${n.read ? 'opacity-60' : ''}`}>
            <div className="font-semibold">{n.title}</div>
            <div className="text-sm">{n.body}</div>
            <div className="text-xs text-gray-500">{n.created_at}</div>
          </li>
        ))}
      </ul>
    </div>
  )
}
