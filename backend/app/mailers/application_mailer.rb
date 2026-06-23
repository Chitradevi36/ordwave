class ApplicationMailer < ActionMailer::Base
  # default from: "OrdWave <no-reply@ordwave.com>"
  default from: "Ordwave <chitra.rajaguru123@gmail.com>"
  # default from: "OrdWave <#{ENV.fetch('MAILER_FROM', 'no-reply@ordwave.com')}>"
  layout "mailer"
end
