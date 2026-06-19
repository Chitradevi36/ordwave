module Users
  class CreateUserService
    Result = Struct.new(:success?, :user, :errors, keyword_init: true)

    def initialize(email:, password:, first_name:, last_name:, phone: nil)
      @email      = email
      @password   = password
      @first_name = first_name
      @last_name  = last_name
      @phone      = phone
    end

    def call
      # Enforce presence of phone for user creation to ensure sign-in via phone is possible
      if @phone.to_s.strip.empty?
        return Result.new(success?: false, user: nil, errors: ['phone is required'])
      end

      unless @phone.to_s.strip.match?(/\A[0-9]{10}\z/)
        return Result.new(success?: false, user: nil, errors: ['phone must be a 10-digit number'])
      end

      user = User.new(
        email:      @email,
        password:   @password,
        first_name: @first_name,
        last_name:  @last_name,
        phone:      @phone.to_s.strip,
        active:     true
      )

      if user.save
        Result.new(success?: true, user: user, errors: [])
      else
        Result.new(success?: false, user: nil, errors: user.errors.full_messages)
      end
    end
  end
end
