class ReportsController < ApplicationController
  before_action :authenticate_admin!, only: [:index, :show, :update, :destroy]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    reports = Report.includes(:user, :questao)
                   .order(created_at: :desc)
                   .offset((page - 1) * per_page)
                   .limit(per_page)

    render json: {
      data: reports.as_json(include: {
        user: { only: [:id, :email, :nome] },
        questao: { only: [:id, :enunciado] }
      }),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Report.count,
        total_pages: (Report.count.to_f / per_page).ceil
      }
    }
  end

  def show
    @report = Report.includes(:user, :questao).find(params[:id])
    render json: @report.as_json(include: {
      user: { only: [:id, :email, :nome] },
      questao: { only: [:id, :enunciado] }
    })
  end

  def create
    @questao = Questao.find_by(id: params[:questao_id])
    return render json: { error: 'Questão não encontrada' }, status: :not_found unless @questao
    
    @report = current_user.reports.new(report_params)
    @report.questao = @questao

    if @report.save
      render json: @report, status: :created
    else
      render json: { errors: @report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @report = Report.find(params[:id])
    if @report.update(report_update_params)
      render json: @report
    else
      render json: { errors: @report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @report = Report.find(params[:id])
    @report.destroy
    head :no_content
  end

  private

  def report_params
    params.require(:report).permit(:error_type, :description)
  end

  def report_update_params
    params.require(:report).permit(:status)
  end
end
