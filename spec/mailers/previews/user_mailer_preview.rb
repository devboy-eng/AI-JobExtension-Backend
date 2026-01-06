# Preview all emails at http://localhost:3000/rails/mailers/user_mailer_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer_mailer/welcome
  def welcome
    UserMailer.welcome
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer_mailer/forgot_password
  def forgot_password
    UserMailer.forgot_password
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer_mailer/payment_confirmation
  def payment_confirmation
    UserMailer.payment_confirmation
  end

end
