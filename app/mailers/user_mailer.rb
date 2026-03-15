class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    @url  = 'https://apoloconcursos.com.br/login'
    mail(to: @user.email, subject: 'Bem-vindo ao Apolo Anki!')
  end

  def password_reset_email(user)
    @user = user
    @url  = "#{ENV['SESSION_BASE_NEW_URL']}/reset-password?token=#{@user.reset_password_token}"
    mail(to: @user.email, subject: 'Redefinição de Senha - Apolo Anki')
  end
end
