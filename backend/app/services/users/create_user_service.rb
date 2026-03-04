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
      user = User.new(
        email:      @email,
        password:   @password,
        first_name: @first_name,
        last_name:  @last_name,
        phone:      @phone,
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
