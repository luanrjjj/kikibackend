class ReportsController < ApplicationController
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
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Questão não encontrada' }, status: :not_found
  end

  private

  def report_params
    params.require(:report).permit(:error_type, :description)
  end
end
