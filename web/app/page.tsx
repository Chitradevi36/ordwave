import Link from "next/link";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-background-subtle">
      <div className="text-center">
        <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-2xl bg-primary">
          <span className="text-2xl font-bold text-white">OD</span>
        </div>
        <h1 className="text-4xl font-bold text-text-primary">OmniDist OMS</h1>
        <p className="mt-2 text-lg text-text-secondary">
          Offline-first, Credit-first OMS for FMCG Distributors
        </p>
        <div className="mt-8 flex gap-4 justify-center">
          <Link
            href="/dashboard"
            className="rounded-lg bg-primary px-6 py-3 text-sm font-medium text-white hover:bg-primary-700 transition-colors"
          >
            Go to Dashboard
          </Link>
          <Link
            href="/login"
            className="rounded-lg border border-border px-6 py-3 text-sm font-medium text-text-primary hover:bg-background-subtle transition-colors"
          >
            Sign In
          </Link>
        </div>
      </div>
    </main>
  );
}
