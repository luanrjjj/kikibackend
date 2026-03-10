class PaymentsController < ApplicationController
  def create
    payment = AsaasService.create_payment(
      payment_params.merge(
        email: current_user.email,
        name: current_user.name
      )
    )
    render json: payment
  end

  def subscribe
    subscription = AsaasService.create_subscription(
      payment_params.merge(
        email: current_user.email,
        name: current_user.name
      )
    )

    if subscription["id"]
      current_user.update(
        asaas_customer_id: subscription["customer"],
        subscription_status: "ACTIVE",
        plan: payment_params[:plan] || "MONTHLY",
        current_period_end: Time.at(subscription["current_cycle_end"] / 1000).to_i
      )
    end

    render json: subscription
  end

  private

  def payment_params
    params.require(:payment).permit(:card_number, :expiry_date, :cvv, :card_holder_name, :value, :email, :cpf, :cycle, :plan, :phone, :cep)
  end
end
