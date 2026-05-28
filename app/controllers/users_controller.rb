class UsersController < ApplicationController
  before_action :authenticate_admin!

  def index
    @users = User.all.order(created_at: :desc)
    
    # Pagination (simple)
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @users = @users.page(page).per(per_page)

    render json: {
      users: @users,
      meta: {
        current_page: @users.current_page,
        total_pages: @users.total_pages,
        total_count: @users.total_count
      }
    }
  end

  def show
    @user = User.find(params[:id])
    render json: @user
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      render json: @user
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :admin, :subscription_status, :plan, :current_period_end,
      :name, :email, :cpf, :telefone, :cep, :cidade, :estado, :endereco,
      :stripe_customer_id, :asaas_customer_id
    )
  end
end
