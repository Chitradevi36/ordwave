# frozen_string_literal: true

module Notifications
  # Creates one Notification row per recipient and optionally queues a push job.
  #
  # Usage:
  #   Notifications::CreateService.call(
  #     organization: org,
  #     recipients:   [user1, user2],
  #     actor:        current_user,          # optional
  #     notifiable:   sales_order,           # optional polymorphic object
  #     type:         'order_submitted',
  #     title:        'New order #ORD-1042 needs approval',
  #     body:         'Placed by Fresh Mart – ₹12,500',   # optional
  #     deep_link:    '/approvals',                        # optional
  #     severity:     'high'                               # low | medium | high
  #   )
  #
  class CreateService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, recipients:, type:, title:,
                   actor: nil, notifiable: nil, body: nil,
                   deep_link: nil, severity: 'medium')
      @organization = organization
      @recipients   = Array(recipients).compact.uniq
      @actor        = actor
      @notifiable   = notifiable
      @type         = type
      @title        = title
      @body         = body
      @deep_link    = deep_link
      @severity     = severity
    end

    def call
      notifications = @recipients.filter_map do |user|
        Notification.create!(
          organization:      @organization,
          user:              user,
          actor:             @actor,
          notifiable:        @notifiable,
          notification_type: @type,
          title:             @title,
          body:              @body,
          deep_link_url:     @deep_link,
          severity:          @severity
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[Notifications::CreateService] Failed for user #{user.id}: #{e.message}")
        nil
      end

      notifications
    end
  end
end
