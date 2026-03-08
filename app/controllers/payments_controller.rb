class PaymentsController < ApplicationController
  def create
    payment = AsaasService.create_payment(payment_params.merge(email: current_user.email))
    render json: payment
  end

  private

  def payment_params
    params.require(:payment).permit(:card_number, :expiry_date, :cvv, :card_holder_name, :value, :email)
  end
end

