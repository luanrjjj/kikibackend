class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    @url  = 'https://apoloconcursos.com.br/login'
    mail(to: @user.email, subject: 'Bem-vindo ao Apolo Anki!')
  end

  def password_reset_email(password_reset)
    @user = password_reset.user
    @password_reset = password_reset
    @url  = "#{ENV['SESSION_BASE_NEW_URL']}/reset-password?token=#{@password_reset.token}&email=#{CGI.escape(@user.email)}"
    
    mail(to: @user.email, subject: 'Redefinição de Senha - Apolo Anki')
  end
end
