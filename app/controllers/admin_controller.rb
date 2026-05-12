class AdminController < ApplicationController
  before_action :authenticate_admin!

  def refresh_stats
    RefreshAdminStatsJob.perform_async
    render json: { message: "Job de atualização de estatísticas enfileirado com sucesso!" }, status: :ok
  rescue StandardError => e
    render json: { error: "Erro ao enfileirar job", message: e.message }, status: :internal_server_error
  end
end
