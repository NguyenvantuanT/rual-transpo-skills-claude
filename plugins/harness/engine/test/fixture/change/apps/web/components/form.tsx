'use client'
import { prisma } from '@/lib/db'
export function Form({ items }: { items: string[] }) {
  return <ul>{items.map((x, i) => <li key={i}>{x}</li>)}</ul>
}
