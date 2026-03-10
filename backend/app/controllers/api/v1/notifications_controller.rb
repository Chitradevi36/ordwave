# frozen_string_literal: true

module Api
  module V1
    # Handles in-app notifications for the authenticated user.
    #
    # GET    /api/v1/notifications          — paginated list (filterable)
    # PATCH  /api/v1/notifications/:id/read — mark single as read
    # POST   /api/v1/notifications/read_all — mark all unread as read
    # DELETE /api/v1/notifications/:id      — dismiss (soft delete)
    class NotificationsController < BaseController
      before_action :set_notification, only: %i[read destroy]

      # GET /api/v1/notifications
      def index
        scope = policy_scope(Notification)
                  .not_dismissed
                  .order(created_at: :desc)

        scope = scope.unread                    if params[:unread] == 'true'
        scope = scope.by_type(params[:type])    if params[:type].present?
        scope = scope.high_priority             if params[:severity] == 'high'

        total_unread = policy_scope(Notification).not_dismissed.unread.count

        notifications = scope.limit(50)
        authorize notifications, policy_class: NotificationPolicy

        render json: {
          data:        notifications.map { |n| serialize(n) },
          meta: {
            total_unread: total_unread
          }
        }
      end

      # PATCH /api/v1/notifications/:id/read
      def read
        authorize @notification, :read?
        @notification.mark_read!
        render json: { data: serialize(@notification) }
      end

      # POST /api/v1/notifications/read_all
      def read_all
        authorize Notification, :read_all?

        policy_scope(Notification)
          .not_dismissed
          .unread
          .update_all(read_at: Time.current)

        render json: { ok: true }
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        authorize @notification, :dismiss?
        @notification.dismiss!
        render json: { ok: true }
      end

      private

      def set_notification
        @notification = policy_scope(Notification).find(params[:id])
      end

      def serialize(n)
        {
          id:                n.id,
          notification_type: n.notification_type,
          title:             n.title,
          body:              n.body,
          deep_link_url:     n.deep_link_url,
          severity:          n.severity,
          read:              n.read?,
          read_at:           n.read_at&.iso8601,
          actor:             n.actor ? { id: n.actor.id, name: n.actor.full_name } : nil,
          created_at:        n.created_at.iso8601
        }
      end
    end
  end
end
