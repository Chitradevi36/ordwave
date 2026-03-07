module Api
  module V2
    # API v2 base controller.
    # Clients MUST send the header:  Accept-Version: v2
    # to receive v2 responses; otherwise a 406 Not Acceptable is returned.
    #
    # v2 controllers inherit from this class, which itself inherits v1's
    # full stack (auth, multi-tenancy, Pundit, pagination, error handling).
    class BaseController < Api::V1::BaseController
      before_action :require_v2_header!

      private

      def require_v2_header!
        version = request.headers["Accept-Version"]
        return if version.to_s.strip == "v2"

        render json: {
          errors: [
            "This endpoint requires the header 'Accept-Version: v2'. " \
            "Use /api/v1/ for the stable API."
          ]
        }, status: :not_acceptable
      end
    end
  end
end
