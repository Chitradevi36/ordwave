module Visits
  # Returns the day's call plan for a sales rep on a given date.
  #
  # Result structure:
  #   { schedules: [{ schedule:, customers: [{ customer:, due:, due_reason:, override: }] }] }
  #
  class GetTodaysPlanService
    PlanResult = Struct.new(:success?, :plan, :errors)

    FREQ_DAYS = Customer::VISIT_FREQ_DAYS

    # weekday: 0=Mon…6=Sun (Ruby's wday is 0=Sun, so we remap)
    ISO_WEEKDAY = { 0 => 6, 1 => 0, 2 => 1, 3 => 2, 4 => 3, 5 => 4, 6 => 5 }.freeze

    def initialize(sales_rep:, branch:, date: Date.current)
      @sales_rep = sales_rep
      @branch    = branch
      @date      = date
    end

    def call
      weekday  = ISO_WEEKDAY[@date.wday]
      schedules = BeatSchedule
                    .active
                    .for_rep(@sales_rep.id)
                    .for_weekday(weekday)
                    .for_branch(@branch.id)
                    .includes(beat: :route,
                              beat_retailers: :customer)

      plan = schedules.map { |sched| build_schedule_plan(sched) }

      PlanResult.new(true, plan, [])
    end

    private

    def build_schedule_plan(schedule)
      force_excludes = schedule.beat_retailers.select { |br| br.visit_override == 'force_exclude' }.map(&:customer_id).to_set
      force_includes = schedule.beat_retailers.select { |br| br.visit_override == 'force_include' }

      # Base customers from route
      route_customers = if schedule.beat.route_id
                          Customer.active.where(route_id: schedule.beat.route_id)
                                  .includes(:beat_retailers)
                        else
                          Customer.none
                        end

      retailer_map = schedule.beat_retailers.index_by(&:customer_id)

      customer_entries = []

      route_customers.each do |cust|
        next if force_excludes.include?(cust.id)

        br     = retailer_map[cust.id]
        seq    = br&.sequence_number || 999
        due, reason = compute_due(cust)
        customer_entries << { customer: cust, due: due, due_reason: reason, override: 'default', sequence: seq }
      end

      # Add force_includes not already from route
      force_includes.each do |br|
        cust = br.customer
        next if customer_entries.any? { |e| e[:customer].id == cust.id }

        due, reason = compute_due(cust)
        customer_entries << { customer: cust, due: true, due_reason: 'force_include', override: 'force_include', sequence: br.sequence_number }
      end

      customer_entries.sort_by! { |e| e[:sequence] }

      { schedule: schedule, customers: customer_entries }
    end

    def compute_due(customer)
      return [false, nil] if customer.visit_frequency.blank?
      return [true, 'never_visited'] if customer.last_visited_at.nil?

      if customer.next_due_on.present? && customer.next_due_on <= @date
        return [true, 'next_due_reached']
      end

      days = FREQ_DAYS[customer.visit_frequency]
      if days && customer.last_visited_at.to_date + days <= @date
        return [true, customer.visit_frequency]
      end

      [false, nil]
    end
  end
end
