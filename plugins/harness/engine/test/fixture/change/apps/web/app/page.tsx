import { useRouter } from 'next/router'
export default function Page() {
  const k = process.env.NEXT_PUBLIC_STRIPE_SECRET
  return <a href="/about"><img src="/a.png" /></a>
}
