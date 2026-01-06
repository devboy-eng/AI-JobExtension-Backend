class UserMailer < ApplicationMailer

  def welcome(user)
    @user = user
    mail(
      to: @user.email,
      subject: "Welcome to JobExtension - Your Resume Optimization Journey Starts Now!"
    )
  end

  def forgot_password(user, reset_url, ip_address = nil)
    @user = user
    @reset_url = reset_url
    @ip_address = ip_address
    
    mail(
      to: @user.email,
      subject: "Reset Your JobExtension Password"
    )
  end

  def payment_confirmation(user, order_id, amount, coins_purchased, payment_method = nil)
    @user = user
    @order_id = order_id
    @amount = amount
    @coins_purchased = coins_purchased
    @payment_method = payment_method
    
    mail(
      to: @user.email,
      subject: "Payment Confirmed - #{coins_purchased} Coins Added to Your Account!"
    )
  end
  
  def resume_optimization_complete(user, job_title, company, ats_score)
    @user = user
    @job_title = job_title
    @company = company
    @ats_score = ats_score
    
    mail(
      to: @user.email,
      subject: "Resume Optimization Complete for #{job_title} at #{company} (ATS Score: #{ats_score}%)"
    )
  end
end
