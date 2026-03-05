module Pricing
  # Core scheme (trade promotion) engine.
  #
  # Inputs:
  #   retailer:   Customer instance
  #   branch_id:  Integer
  #   cart_lines: Array of Structs or hashes:
  #               { product_id:, product:, qty:, base_unit_price:, base_discount_pct:,
  #                 category_id: }
  #   context:    { route_id:, beat_id:, date: }
  #
  # Output (ApplyResult struct):
  #   priced_lines:     [{product_id, qty, base_price, scheme_discount_pct,
  #                       final_price, scheme_tags}]
  #   freebies:         [{product_id, qty_free, scheme_id, scheme_code}]
  #   order_discounts:  [{scheme_id, amount}]
  #   totals:           {subtotal, scheme_discount_total, order_scheme_discount, grand_total}
  #   explain:          {applied: [...], not_applied: [...]}
  #
  class ApplySchemesService
    ApplyResult = Struct.new(
      :priced_lines,
      :freebies,
      :order_discounts,
      :totals,
      :explain,
      keyword_init: true
    )

    CartLine = Struct.new(
      :product_id, :product, :qty, :base_unit_price,
      :base_discount_pct, :category_id,
      keyword_init: true
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(retailer:, branch_id:, cart_lines:, context: {})
      @retailer   = retailer
      @branch_id  = branch_id
      @cart_lines = cart_lines.map { |l| coerce_line(l) }
      @date       = context[:date]&.to_date || Date.current
      @route_id   = context[:route_id]
      @beat_id    = context[:beat_id]
      @org_id     = retailer.organization_id

      # Working copies — scheme_discount_pct accumulates
      @line_results = @cart_lines.map do |l|
        {
          product_id:         l.product_id,
          qty:                l.qty,
          base_price:         l.base_unit_price,
          scheme_discount_pct: 0.0,
          scheme_tags:        []
        }
      end

      @freebies        = []
      @order_discounts = []
      @applied         = []
      @not_applied     = []
    end

    def call
      schemes = Scheme.eligible(
        organization_id: @org_id,
        branch_id:       @branch_id,
        date:            @date
      )

      # Track exclusivity by stack group
      exclusive_taken = false

      schemes.each do |scheme|
        # Skip if a higher-priority exclusive scheme already fired
        next if exclusive_taken

        result = evaluate_scheme(scheme)

        if result[:applied]
          apply_scheme(scheme, result[:match_data])
          @applied << { scheme_id: scheme.id, code: scheme.code, name: scheme.name,
                        message: result[:message] }
          exclusive_taken = true if scheme.exclusive
        else
          @not_applied << { scheme_id: scheme.id, code: scheme.code, name: scheme.name,
                            reason: result[:reason] }
        end
      end

      build_result
    end

    private

    # ── Evaluation ────────────────────────────────────────────────────────────

    def evaluate_scheme(scheme)
      # 1. Scope check
      scope_check = evaluate_scope(scheme)
      return { applied: false, reason: scope_check } unless scope_check.nil?

      # 2. Conditions
      scheme.conditions.each do |cond|
        reason = evaluate_condition(cond)
        return { applied: false, reason: reason } if reason
      end

      # 3. Scheme-type specific check
      case scheme.scheme_type
      when 'buy_x_get_y'
        match = evaluate_buy_x_get_y(scheme)
        return match if match[:applied] == false
        { applied: true, match_data: match[:data], message: match[:message] }
      when 'slab_discount', 'order_value_discount'
        match = evaluate_slab(scheme)
        return match if match[:applied] == false
        { applied: true, match_data: match[:data], message: match[:message] }
      when 'item_discount'
        { applied: true, match_data: {}, message: "Item discount applied" }
      else
        { applied: false, reason: "Unknown scheme type" }
      end
    end

    def evaluate_scope(scheme)
      case scheme.applies_to
      when 'all'
        nil
      when 'retailer_segment'
        # Check if any condition has retailer_inclusion matching this retailer's tier
        nil # base: pass — tier checked via conditions
      when 'specific_retailers'
        incl = scheme.conditions.find { |c| c.condition_type == 'retailer_inclusion' }
        if incl
          ids = Array(incl.value['customer_ids']).map(&:to_i)
          return "Retailer not in scheme scope" unless ids.include?(@retailer.id)
        end
        nil
      when 'route'
        route_cond = scheme.conditions.find { |c| c.condition_type == 'retailer_inclusion' }
        # route-based: use @route_id
        return "No route context" unless @route_id
        # If the condition stores route_ids use it; otherwise pass through
        nil
      when 'beat'
        return "No beat context" unless @beat_id
        nil
      end
    end

    def evaluate_condition(cond)
      case cond.condition_type
      when 'min_order_value'
        threshold = cond.value['amount'].to_f
        return "Order value #{subtotal.round(2)} < minimum #{threshold}" if subtotal < threshold
      when 'min_total_qty'
        threshold = cond.value['qty'].to_f
        total_qty = @cart_lines.sum(&:qty).to_f
        return "Total qty #{total_qty} < minimum #{threshold}" if total_qty < threshold
      when 'product_inclusion'
        ids = Array(cond.value['product_ids']).map(&:to_i)
        matching = @cart_lines.any? { |l| ids.include?(l.product_id) }
        return "No qualifying products in cart" unless matching
      when 'product_exclusion'
        ids = Array(cond.value['product_ids']).map(&:to_i)
        # exclusion doesn't block the scheme — it filters which lines it applies to
        nil
      when 'category_inclusion'
        ids = Array(cond.value['category_ids']).map(&:to_i)
        matching = @cart_lines.any? { |l| ids.include?(l.category_id) }
        return "No qualifying categories in cart" unless matching
      when 'retailer_inclusion'
        ids = Array(cond.value['customer_ids']).map(&:to_i)
        return "Retailer not in inclusion list" unless ids.include?(@retailer.id)
      when 'retailer_exclusion'
        ids = Array(cond.value['customer_ids']).map(&:to_i)
        return "Retailer excluded from this scheme" if ids.include?(@retailer.id)
      end
      nil
    end

    def evaluate_buy_x_get_y(scheme)
      reward = scheme.rewards.first
      return { applied: false, reason: "No reward configured" } unless reward

      trigger_qty   = reward.free_per_x.to_i
      free_per_set  = reward.free_qty_per_trigger.to_i
      return { applied: false, reason: "free_per_x not set" } if trigger_qty.zero?

      # Find qualifying lines (product_inclusion condition)
      incl = scheme.conditions.find { |c| c.condition_type == 'product_inclusion' }
      qualifying_ids = incl ? Array(incl.value['product_ids']).map(&:to_i) : @cart_lines.map(&:product_id)

      matching_lines = @cart_lines.select { |l| qualifying_ids.include?(l.product_id) }
      total_qty      = matching_lines.sum(&:qty).to_f

      sets         = (total_qty / trigger_qty).floor
      return { applied: false, reason: "Qty #{total_qty} < trigger #{trigger_qty}" } if sets.zero?

      qty_free     = sets * free_per_set
      free_product = reward.target_product_id || matching_lines.first&.product_id

      {
        applied: true,
        message: "Buy #{trigger_qty} get #{free_per_set}: #{sets} set(s), #{qty_free} free",
        data:    { type: :freebie, product_id: free_product, qty_free: qty_free }
      }
    end

    def evaluate_slab(scheme)
      reward = scheme.rewards.first
      return { applied: false, reason: "No reward configured" } unless reward

      # Slab: check if order subtotal meets the minimum (from conditions)
      # The slab threshold is encoded as min_order_value condition
      min_cond = scheme.conditions.find { |c| c.condition_type == 'min_order_value' }
      if min_cond
        threshold = min_cond.value['amount'].to_f
        return { applied: false, reason: "Order value #{subtotal.round(2)} < slab #{threshold}" } if subtotal < threshold
      end

      {
        applied: true,
        message: "Slab discount: #{reward.reward_value}#{reward.reward_type == 'percent_off' ? '%' : '₹'} off",
        data:    { type: :slab, reward: reward }
      }
    end

    # ── Application ────────────────────────────────────────────────────────────

    def apply_scheme(scheme, match_data)
      case match_data[:type]
      when :freebie
        @freebies << {
          product_id: match_data[:product_id],
          qty_free:   match_data[:qty_free],
          scheme_id:  scheme.id,
          scheme_code: scheme.code,
          scheme_name: scheme.name
        }
        # Tag the triggering lines
        tag_lines_for_scheme(scheme, "buy_x_get_y")

      when :slab
        reward = match_data[:reward]
        apply_reward_to_lines_or_order(scheme, reward)

      else
        # item_discount: apply each reward to its target lines
        scheme.rewards.each { |r| apply_reward_to_lines_or_order(scheme, r) }
      end
    end

    def apply_reward_to_lines_or_order(scheme, reward)
      case reward.target_scope
      when 'order'
        apply_order_level_reward(scheme, reward)
      when 'line'
        apply_line_level_reward(scheme, reward)
      when 'product'
        apply_product_level_reward(scheme, reward)
      end
    end

    def apply_order_level_reward(scheme, reward)
      case reward.reward_type
      when 'percent_off'
        discount_amount = (subtotal * reward.reward_value / 100.0).round(2)
        discount_amount = [discount_amount, reward.max_reward_value.to_f].min if reward.max_reward_value
        @order_discounts << { scheme_id: scheme.id, scheme_code: scheme.code,
                               scheme_name: scheme.name, amount: discount_amount }
      when 'amount_off'
        discount_amount = [reward.reward_value.to_f, reward.max_reward_value&.to_f || reward.reward_value.to_f].min
        @order_discounts << { scheme_id: scheme.id, scheme_code: scheme.code,
                               scheme_name: scheme.name, amount: discount_amount.round(2) }
      end
      tag_lines_for_scheme(scheme, reward.reward_type)
    end

    def apply_line_level_reward(scheme, reward)
      # Determine which lines to discount
      incl_cond = scheme.conditions.find { |c| c.condition_type == 'product_inclusion' }
      excl_cond = scheme.conditions.find { |c| c.condition_type == 'product_exclusion' }
      cat_cond  = scheme.conditions.find { |c| c.condition_type == 'category_inclusion' }

      @line_results.each_with_index do |lr, idx|
        l = @cart_lines[idx]
        next if incl_cond && !Array(incl_cond.value['product_ids']).map(&:to_i).include?(l.product_id)
        next if excl_cond && Array(excl_cond.value['product_ids']).map(&:to_i).include?(l.product_id)
        next if cat_cond  && !Array(cat_cond.value['category_ids']).map(&:to_i).include?(l.category_id)

        case reward.reward_type
        when 'percent_off'
          lr[:scheme_discount_pct] += reward.reward_value.to_f
        when 'amount_off'
          # Convert amount off per line to equivalent discount pct
          line_base = l.base_unit_price * l.qty
          pct = line_base.positive? ? (reward.reward_value.to_f / line_base * 100.0).round(4) : 0.0
          lr[:scheme_discount_pct] += pct
        when 'fixed_price'
          # Override unit price to fixed_price (encode as negative delta)
          pct = l.base_unit_price.positive? ? ((l.base_unit_price - reward.reward_value.to_f) / l.base_unit_price * 100.0).round(4) : 0.0
          lr[:scheme_discount_pct] += [pct, 0.0].max
        end

        lr[:scheme_tags] << {
          scheme_id:    scheme.id,
          scheme_code:  scheme.code,
          scheme_name:  scheme.name,
          reward_type:  reward.reward_type,
          discount_pct: reward.reward_value
        }
      end
    end

    def apply_product_level_reward(scheme, reward)
      target_id = reward.target_product_id
      return unless target_id

      @line_results.each_with_index do |lr, idx|
        next unless @cart_lines[idx].product_id == target_id

        case reward.reward_type
        when 'percent_off'
          lr[:scheme_discount_pct] += reward.reward_value.to_f
        when 'free_qty'
          @freebies << {
            product_id:  target_id,
            qty_free:    reward.reward_value.to_f,
            scheme_id:   scheme.id,
            scheme_code: scheme.code,
            scheme_name: scheme.name
          }
        end

        lr[:scheme_tags] << {
          scheme_id:   scheme.id,
          scheme_code: scheme.code,
          scheme_name: scheme.name,
          reward_type: reward.reward_type,
          discount_pct: reward.reward_value
        }
      end
    end

    def tag_lines_for_scheme(scheme, reward_type)
      @line_results.each do |lr|
        lr[:scheme_tags] << {
          scheme_id:   scheme.id,
          scheme_code: scheme.code,
          scheme_name: scheme.name,
          reward_type: reward_type
        }
      end
    end

    # ── Result builder ────────────────────────────────────────────────────────

    def build_result
      priced_lines = @line_results.each_with_index.map do |lr, idx|
        l           = @cart_lines[idx]
        total_disc  = [l.base_discount_pct.to_f + lr[:scheme_discount_pct], 100.0].min
        final_price = (l.base_unit_price * (1 - total_disc / 100.0)).round(2)
        {
          product_id:          l.product_id,
          qty:                 l.qty,
          base_price:          l.base_unit_price,
          base_discount_pct:   l.base_discount_pct,
          scheme_discount_pct: lr[:scheme_discount_pct].round(4),
          final_price:         final_price,
          scheme_tags:         lr[:scheme_tags]
        }
      end

      line_scheme_discount = priced_lines.sum do |pl|
        pl[:base_price] * pl[:qty] * (pl[:scheme_discount_pct] / 100.0)
      end.round(2)

      order_scheme_discount = @order_discounts.sum { |od| od[:amount] }.round(2)

      ApplyResult.new(
        priced_lines:    priced_lines,
        freebies:        @freebies,
        order_discounts: @order_discounts,
        totals: {
          subtotal:               subtotal.round(2),
          scheme_discount_total:  (line_scheme_discount + order_scheme_discount).round(2),
          line_scheme_discount:   line_scheme_discount,
          order_scheme_discount:  order_scheme_discount
        },
        explain: {
          applied:     @applied,
          not_applied: @not_applied
        }
      )
    end

    def subtotal
      @subtotal ||= @cart_lines.sum do |l|
        base_disc = l.base_discount_pct.to_f
        l.base_unit_price * l.qty * (1 - base_disc / 100.0)
      end
    end

    def coerce_line(l)
      if l.is_a?(CartLine)
        l
      else
        h = l.is_a?(Hash) ? l.transform_keys(&:to_sym) : l.to_h.transform_keys(&:to_sym)
        CartLine.new(
          product_id:       h[:product_id].to_i,
          product:          h[:product],
          qty:              h[:qty].to_f,
          base_unit_price:  h[:base_unit_price].to_f,
          base_discount_pct: h[:base_discount_pct].to_f,
          category_id:      h[:category_id]&.to_i
        )
      end
    end
  end
end
