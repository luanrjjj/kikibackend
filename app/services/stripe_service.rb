class StripeService < BaseService
  def self.create_customer(user_data)
    name = user_data.respond_to?(:name) ? user_data.name : user_data[:name]
    email = user_data.respond_to?(:email) ? user_data.email : user_data[:email]

    customer = Stripe::Customer.create({
      name: name,
      email: email,
      metadata: {
        cpf: user_data.respond_to?(:cpf) ? user_data.cpf : user_data[:cpf]
      }
    })
    customer
  rescue Stripe::StripeError => e
    { "error" => e.message }
  end

  def self.create_payment(payment_params)
    customer_id = ensure_customer(payment_params)
    return customer_id if customer_id.is_a?(Hash) && customer_id["error"]

    # Use token if provided, otherwise create one from raw data (unsafe)
    source = if payment_params[:token].present?
               payment_params[:token]
             else
               Stripe::Token.create({
                 card: {
                   number: payment_params[:card_number],
                   exp_month: payment_params[:expiry_date].split('/')[0],
                   exp_year: "20#{payment_params[:expiry_date].split('/')[1]}",
                   cvc: payment_params[:cvv],
                   name: payment_params[:card_holder_name]
                 }
               }).id
             end

    charge = Stripe::Charge.create({
      amount: (payment_params[:value].to_f * 100).to_i,
      currency: 'brl',
      source: source,
      customer: customer_id,
      description: 'Anki App Payment'
    })

    {
      "id" => charge.id,
      "customer" => charge.customer,
      "status" => charge.status
    }
  rescue Stripe::StripeError => e
    { "error" => e.message }
  end

  def self.create_subscription(subscription_params)
    customer_id = ensure_customer(subscription_params)
    return customer_id if customer_id.is_a?(Hash) && customer_id["error"]

    # Use payment_method_id if provided, otherwise create one from raw data (unsafe)
    payment_method_id = if subscription_params[:payment_method_id].present?
                          subscription_params[:payment_method_id]
                        else
                          pm = Stripe::PaymentMethod.create({
                            type: 'card',
                            card: {
                              number: subscription_params[:card_number],
                              exp_month: subscription_params[:expiry_date].split('/')[0],
                              exp_year: "20#{subscription_params[:expiry_date].split('/')[1]}",
                              cvc: subscription_params[:cvv]
                            }
                          })
                          pm.id
                        end

    # Attach to customer if not already attached
    Stripe::PaymentMethod.attach(
      payment_method_id,
      { customer: customer_id }
    )
    # Set as default payment method
    Stripe::Customer.update(
      customer_id,
      invoice_settings: { default_payment_method: payment_method_id }
    )

    price = Stripe::Price.create({
      unit_amount: (subscription_params[:value].to_f * 100).to_i,
      currency: 'brl',
      recurring: { interval: subscription_params[:cycle]&.downcase == 'yearly' ? 'year' : 'month' },
      product_data: { name: "Anki App #{subscription_params[:plan] || 'Subscription'}" }
    })

    subscription = Stripe::Subscription.create({
      customer: customer_id,
      items: [{ price: price.id }],
      expand: ['latest_invoice.payment_intent']
    })

    {
      "id" => subscription.id,
      "customer" => subscription.customer,
      "status" => subscription.status,
      "nextDueDate" => Time.at(subscription.items.data[0].current_period_end).strftime('%Y-%m-%d')
    }
  rescue Stripe::StripeError => e
    { "error" => e.message }
  end

  def self.ensure_customer(params)
    customers = Stripe::Customer.list({ email: params[:email], limit: 1 })

    if customers.data.any?
      customers.data.first.id
    else
      customer = create_customer(params)
      if customer.is_a?(Hash) && customer["error"]
        customer
      else
        customer.id
      end
    end
  end
end
