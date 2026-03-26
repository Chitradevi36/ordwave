/**
 * Shared per-route loading skeleton. Drop this into any route folder as
 * `loading.tsx` to provide an instant loading state via React Suspense.
 */
export default function RouteLoading() {
  return (
    <div className="flex flex-col gap-4 p-4 md:p-6 animate-pulse">
      {/* Header skeleton */}
      <div className="flex items-center justify-between">
        <div className="h-8 w-48 rounded-md bg-background-subtle" />
        <div className="h-9 w-28 rounded-md bg-background-subtle" />
      </div>
      {/* Table / content skeleton */}
      <div className="rounded-xl border border-border bg-white p-4 space-y-3">
        <div className="h-4 w-full rounded bg-background-subtle" />
        <div className="h-4 w-5/6 rounded bg-background-subtle" />
        <div className="h-4 w-4/6 rounded bg-background-subtle" />
        <div className="h-4 w-5/6 rounded bg-background-subtle" />
        <div className="h-4 w-3/6 rounded bg-background-subtle" />
        <div className="h-4 w-full rounded bg-background-subtle" />
        <div className="h-4 w-4/6 rounded bg-background-subtle" />
      </div>
    </div>
  );
}
