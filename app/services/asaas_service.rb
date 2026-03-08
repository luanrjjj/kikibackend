class AsaasService < BaseService
  def self.create_customer(user)
    conn(ENV['ASAAS_URL']).post('v3/customers') do |req|
      req.headers['access_token'] = ENV['ASAAS_API_KEY']
      req.body = {
        name: user.name,
        email: user.email,
        cpfCnpj: user.cpf
      }.to_json
    end
  end

  def self.create_payment(payment_params)
    customer = get_customer_by_email(payment_params[:email])
    return { error: 'Customer not found' } unless customer

    conn(ENV['ASAAS_URL']).post('v3/payments') do |req|
      req.headers['access_token'] = ENV['ASAAS_API_KEY']
      req.body = {
        customer: customer['data'][0]['id'],
        billingType: 'CREDIT_CARD',
        dueDate: Time.now.strftime('%Y-%m-%d'),
        value: payment_params[:value],
        description: 'Anki App Subscription',
        creditCard: {
          holderName: payment_params[:card_holder_name],
          number: payment_params[:card_number],
          expiryMonth: payment_params[:expiry_date].split('/')[0],
          expiryYear: "20#{payment_params[:expiry_date].split('/')[1]}",
          ccv: payment_params[:cvv]
        }
      }.to_json
    end
  end

  def self.get_customer_by_email(email)
    conn(ENV['ASAAS_URL']).get("v3/customers?email=#{email}") do |req|
      req.headers['access_token'] = ENV['ASAAS_API_KEY']
    end
  end
end
