class PaymentsController < ApplicationController
  def create
    # CEP validation (Brazilian format: 00000-000 or 00000000)
    unless payment_params[:cep] =~ /\A\d{5}-?\d{3}\z/
      return render json: { error: "CEP inválido. Informe um CEP válido com 8 dígitos." }, status: :unprocessable_entity
    end

    payment = AsaasService.create_payment(
      payment_params.merge(
        email: current_user.email,
        name: current_user.name
      )
    )
    render json: payment
  end

  def subscribe
    # CEP validation (Brazilian format: 00000-000 or 00000000)
    unless payment_params[:cep] =~ /\A\d{5}-?\d{3}\z/
      return render json: { error: "CEP inválido. Informe um CEP válido com 8 dígitos." }, status: :unprocessable_entity
    end

    subscription = AsaasService.create_subscription(
      payment_params.merge(
        email: current_user.email,
        name: current_user.name
      )
    )
    puts "Subscription response: #{subscription.inspect}"

    if subscription["id"]
      current_user.update(
        asaas_customer_id: subscription["customer"],
        subscription_status: "ACTIVE",
        plan: payment_params[:plan] || "MONTHLY",
        current_period_end: Date.parse(subscription["nextDueDate"]),
        cpf: payment_params[:cpf],
        telefone: payment_params[:phone],
        cep: payment_params[:cep],
        endereco: payment_params[:address],
        endereco_numero: payment_params[:address_number],
        cidade: payment_params[:city],
        estado: payment_params[:state]
      )
    end

    render json: subscription
  end

  private

  def payment_params
    params.require(:payment).permit(
      :card_number, :expiry_date, :cvv, :card_holder_name,
      :value, :email, :cpf, :cycle, :plan, :phone, :cep,
      :address, :address_number, :city, :state
    )
  end
end
