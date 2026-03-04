class SessionsController < Devise::SessionsController
  # Web sessions (cookie-based)
  
  def new
    # Render login page
    super
  end

  def create
    # Standard Devise login
    super
  end

  def destroy
    # Standard Devise logout
    super
  end
end
