module GoogleOauth
  class TokenVerifyService
    # Verify Google OAuth ID token and extract user data
    #
    # @param id_token [String] Google ID token from frontend
    # @param client_id [String] Google OAuth client ID (from ENV)
    # @return [Hash] User data { email:, name:, sub: (UID), picture: }
    # @raise [GoogleOauth::TokenInvalidError]
    
    def self.call(id_token:, client_id: nil)
      new(id_token: id_token, client_id: client_id).call
    end

    def initialize(id_token:, client_id: nil)
      @id_token = id_token
      @client_id = client_id || ENV['GOOGLE_OAUTH_CLIENT_ID']
    end

    def call
      verifier = Google::Auth::IDTokens
      
      payload = verifier.verify_oidc(@id_token, aud: @client_id)
      
      # Verify the token is not expired
      raise TokenInvalidError, 'Token expired' if Time.at(payload['exp']) < Time.now
      
      # Extract relevant user data
      {
        email: payload['email'],
        name: payload['name'],
        sub: payload['sub'],      # Unique Google UID
        picture: payload['picture'],
        email_verified: payload['email_verified']
      }
    rescue StandardError => e
      Rails.logger.warn("Google OAuth token verification failed: #{e.class} - #{e.message}")
      raise TokenInvalidError, "Invalid token: #{e.message}"
    end
  end

  class TokenInvalidError < StandardError; end
end
