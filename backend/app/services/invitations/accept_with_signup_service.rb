module Invitations
  class AcceptWithSignupService
    Result = Struct.new(:success?, :user, :membership, :token, :errors, keyword_init: true)

    def initialize(token:, password:, password_confirmation:)
      @token = token
      @password = password
      @password_confirmation = password_confirmation
    end

    def call
      digest     = Invitation.digest(@token)
      invitation = Invitation.pending.find_by(token_digest: digest)

      return error_result(['Invitation not found or already used']) unless invitation
      return error_result(['Invitation has expired']) if invitation.expired?

      # Check if user already exists
      user = User.find_by(email: invitation.email)
      return error_result(['Email already has an account. Please sign in instead.']) if user.present?

      user = nil
      membership = nil
      jwt_token = nil

      ActiveRecord::Base.transaction do
        # Create new user
        user = User.create!(
          email: invitation.email,
          password: @password,
          password_confirmation: @password_confirmation,
          first_name: 'New',
          last_name: 'User',
          active: true,
          plan: 'starter'
        )

        # Assign target branch
        target_branch = invitation.branch || invitation.organization.branches.active.first
        return error_result(['Organization has no active branch']) unless target_branch

        # Create membership
        membership = Membership.create!(
          user: user,
          organization: invitation.organization,
          branch: target_branch,
          role: invitation.role,
          active: true
        )

        # Accept invitation
        invitation.update!(status: 'accepted', accepted_at: Time.current)

        # Generate JWT token
        jwt_token = generate_jwt_token(user)
      end

      Result.new(
        success?: true,
        user: user,
        membership: membership,
        token: jwt_token,
        errors: []
      )
    rescue ActiveRecord::RecordInvalid => e
      error_result(e.record.errors.full_messages)
    end

    private

    def error_result(errors)
      Result.new(success?: false, user: nil, membership: nil, token: nil, errors: errors)
    end

    def generate_jwt_token(user)
      jti = SecureRandom.uuid
      payload = {
        sub:   user.id,
        aud:   'user',
        email: user.email,
        jti:   jti,
        exp:   24.hours.from_now.to_i,
        iat:   Time.current.to_i
      }
      JWT.encode(payload, jwt_secret, 'HS256')
    end

    def jwt_secret
      ENV.fetch('DEVISE_JWT_SECRET_KEY', Rails.application.secret_key_base)
    end
  end
end
