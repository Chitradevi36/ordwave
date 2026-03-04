# Passed to every Pundit policy instead of bare current_user,
# so policies can check both the user AND the current organization.
UserContext = Struct.new(:user, :organization, keyword_init: true)
