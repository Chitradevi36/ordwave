export default function GlobalLoading() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background-subtle">
      <div className="flex flex-col items-center gap-4">
        {/* Brand spinner */}
        <div className="relative h-12 w-12">
          <div className="absolute inset-0 rounded-full border-4 border-primary-100" />
          <div className="absolute inset-0 rounded-full border-4 border-transparent border-t-primary animate-spin" />
        </div>
        <p className="text-sm text-text-secondary animate-pulse">Loading…</p>
      </div>
    </div>
  );
}
