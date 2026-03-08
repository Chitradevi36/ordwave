# frozen_string_literal: true

module Web
  module AccountingHelper
    STATUS_BADGE_CLASSES = {
      # Integration statuses
      "connected"    => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800",
      "disconnected" => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600",
      "error"        => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800",
      "disabled"     => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-400",

      # Sync record statuses
      "pending"      => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800",
      "processing"   => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800",
      "success"      => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800",
      "failed"       => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800",
      "retrying"     => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-orange-100 text-orange-800",
      "skipped"      => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-500",

      # Export file statuses
      "generating"   => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800",
      "ready"        => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800",
    }.freeze

    PRIORITY_BADGE_CLASSES = {
      "high"   => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-50 text-red-700",
      "medium" => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-50 text-yellow-700",
      "low"    => "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-50 text-gray-600",
    }.freeze

    PROVIDER_LABELS = {
      "tally"      => "Tally",
      "zoho_books" => "Zoho Books",
      "busy"       => "Busy",
      "marg"       => "Marg",
      "vyapar"     => "Vyapar",
      "cleartax"   => "ClearTax",
    }.freeze

    # Renders a colored status badge span
    def accounting_status_badge(status)
      css = STATUS_BADGE_CLASSES.fetch(status.to_s, STATUS_BADGE_CLASSES["disabled"])
      content_tag(:span, status.to_s.humanize, class: css)
    end

    # Renders a colored priority badge span
    def sync_priority_badge(priority)
      css = PRIORITY_BADGE_CLASSES.fetch(priority.to_s, PRIORITY_BADGE_CLASSES["low"])
      content_tag(:span, priority.to_s.capitalize, class: css)
    end

    # Human-readable provider name
    def provider_label(provider)
      PROVIDER_LABELS.fetch(provider.to_s, provider.to_s.humanize)
    end

    # Formats a timestamp in a compact human-readable form
    def format_accounting_timestamp(time)
      return "—" if time.blank?

      if time > 24.hours.ago
        time.strftime("Today %H:%M")
      elsif time > 48.hours.ago
        "Yesterday #{time.strftime('%H:%M')}"
      else
        time.strftime("%d %b %Y, %H:%M")
      end
    end

    # Pretty-prints a JSON string or hash for <pre> display
    def pretty_json(value)
      return "—" if value.blank?

      parsed = value.is_a?(String) ? JSON.parse(value) : value
      JSON.pretty_generate(parsed)
    rescue JSON::ParserError
      value.to_s
    end
  end
end
