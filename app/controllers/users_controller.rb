class UsersController < ApplicationController
  before_action :authenticate_admin!

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 25).to_i, 1].max
    
    @users = User.all
    if params[:search].present?
      @users = @users.where("name ILIKE ? OR email ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    total_count = @users.count
    total_pages = (total_count.to_f / per_page).ceil
    @users = @users.order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @users,
      meta: {
        current_page: page,
        per_page: per_page,
        total_pages: total_pages,
        total_count: total_count
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
