class AsaasService < BaseService
  def self.create_customer(user_data)
    # Support both user object and hash
    name = user_data.respond_to?(:name) ? user_data.name : user_data[:name]
    email = user_data.respond_to?(:email) ? user_data.email : user_data[:email]
    cpf = user_data.respond_to?(:cpf) ? user_data.cpf : user_data[:cpf]
    phone = user_data.respond_to?(:phone) ? user_data[:phone] : nil
    cep = user_data.respond_to?(:cep) ? user_data[:cep] : nil

    response = conn(asaas_url).post('v3/customers') do |req|
      req.headers['access_token'] ="$aact_hmlg_000MzkwODA2MWY2OGM3MWRlMDU2NWM3MzJlNzZmNGZhZGY6OjgzZTU0YTE2LWZjMWEtNGFlZC04MmU5LTYyNzUxZTU5MjFkOTo6JGFhY2hfOTc5YTI5YzQtZmQwNS00MGIzLTg4ZTAtYjBkYzFiMDk3Nzdk"

      req.body = {
        name: name,
        email: email,
        cpfCnpj: cpf,
        mobilePhone: phone,
        postalCode: cep
      }.compact.to_json
    end
    response.body
  end

  def self.create_payment(payment_params)
    customer_id = ensure_customer(payment_params)
    return customer_id if customer_id.is_a?(Hash) && customer_id[:error]

    response = conn(asaas_url).post('v3/payments') do |req|
      req.headers['access_token'] ="$aact_hmlg_000MzkwODA2MWY2OGM3MWRlMDU2NWM3MzJlNzZmNGZhZGY6OjgzZTU0YTE2LWZjMWEtNGFlZC04MmU5LTYyNzUxZTU5MjFkOTo6JGFhY2hfOTc5YTI5YzQtZmQwNS00MGIzLTg4ZTAtYjBkYzFiMDk3Nzdk"
      req.body = {
        customer: customer_id,
        billingType: 'CREDIT_CARD',
        dueDate: Time.now.strftime('%Y-%m-%d'),
        value: payment_params[:value],
        description: 'Anki App Payment',
        creditCard: {
          holderName: payment_params[:card_holder_name],
          number: payment_params[:card_number],
          expiryMonth: payment_params[:expiry_date].split('/')[0],
          expiryYear: "20#{payment_params[:expiry_date].split('/')[1]}",
          cvv: payment_params[:cvv]
        },
        creditCardHolderInfo: {
          name: payment_params[:card_holder_name],
          email: payment_params[:email],
          cpfCnpj: payment_params[:cpf],
          phone: payment_params[:phone],
          cep: payment_params[:cep]
        }
      }.to_json
    end
    response.body
  end

  def self.create_subscription(subscription_params)
    customer_id = ensure_customer(subscription_params)
    return customer_id if customer_id.is_a?(Hash) && customer_id[:error]

    response = conn(asaas_url).post('v3/subscriptions') do |req|
      req.headers['access_token'] ="$aact_hmlg_000MzkwODA2MWY2OGM3MWRlMDU2NWM3MzJlNzZmNGZhZGY6OjgzZTU0YTE2LWZjMWEtNGFlZC04MmU5LTYyNzUxZTU5MjFkOTo6JGFhY2hfOTc5YTI5YzQtZmQwNS00MGIzLTg4ZTAtYjBkYzFiMDk3Nzdk"
      req.body = {
        customer: customer_id,
        billingType: 'CREDIT_CARD',
        nextDueDate: Time.now.strftime('%Y-%m-%d'),
        value: subscription_params[:value],
        cycle: subscription_params[:cycle] || 'MONTHLY',
        description: 'Anki App Subscription',
        creditCard: {
          holderName: subscription_params[:card_holder_name],
          number: subscription_params[:card_number],
          expiryMonth: subscription_params[:expiry_date].split('/')[0],
          expiryYear: "20#{subscription_params[:expiry_date].split('/')[1]}",
          ccv: subscription_params[:cvv]
        },
        creditCardHolderInfo: {
          name: subscription_params[:card_holder_name],
          email: subscription_params[:email],
          cpfCnpj: subscription_params[:cpf],
          phone: subscription_params[:phone],
          postalCode: subscription_params[:cep],
        }
      }.to_json
    end
    response.body
  end

  def self.ensure_customer(params)
    customer_response = get_customer_by_email(params[:email])

    if customer_response.success? && customer_response.body['data'] && customer_response.body['data'].any?
      customer_response.body['data'][0]['id']
    else
      new_customer = create_customer(params)
      if new_customer['id']
        new_customer['id']
      else
        { error: 'Não foi possível criar o cliente no Asaas', details: new_customer['errors'] }
      end
    end
  end

  def self.get_customer_by_email(email)
    conn(asaas_url).get("v3/customers?email=#{email}") do |req|
      req.headers['access_token'] ="aact_hmlg_000MzkwODA2MWY2OGM3MWRlMDU2NWM3MzJlNzZmNGZhZGY6OjgzZTU0YTE2LWZjMWEtNGFlZC04MmU5LTYyNzUxZTU5MjFkOTo6JGFhY2hfOTc5YTI5YzQtZmQwNS00MGIzLTg4ZTAtYjBkYzFiMDk3Nzdk"

    end
  end

  private

  def self.asaas_key
    ENV['ASAAS_SECRET_KEY'] || ENV['ASAAS_API_KEY']
  end

  def self.asaas_url
    ENV['ASAAS_URL'] || 'https://sandbox.asaas.com/api/'
  end
end
