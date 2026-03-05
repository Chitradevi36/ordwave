# Sidekiq server-side middleware that restores CurrentAttributes from job args
# so that Auditable callbacks and other Current.user references work in jobs.
#
# Jobs should enqueue user/org IDs via their `perform` signature:
#   def perform(user_id:, organization_id:, ...)
# and this middleware will hydrate Current automatically.
class SidekiqCurrentAttributesMiddleware
  def call(_worker, job, _queue)
    user_id  = job["user_id"]  || job.dig("args", 0, "user_id")
    org_id   = job["organization_id"] || job.dig("args", 0, "organization_id")

    Current.user         = User.find_by(id: user_id)  if user_id
    Current.organization = Organization.find_by(id: org_id) if org_id

    yield
  ensure
    # Reset after job — prevent leakage between jobs on the same thread
    Current.reset
  end
end
