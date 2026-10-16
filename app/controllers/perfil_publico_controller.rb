# Perfil estatístico público (kikiapps#1).
#
# GET   /perfil_publico/:fake_id   — público; só responde se o dono ativou public_stats
# PATCH /perfil_publico/configuracao — o usuário logado liga/desliga o perfil público
class PerfilPublicoController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  PERIODOS = [7, 30, 90, 3650].freeze

  def show
    user = User.find_by(fake_id: params[:fake_id].to_s)

    unless user&.public_stats?
      return render json: {
        error: 'perfil_privado',
        message: 'Este perfil não existe ou não é público.'
      }, status: :not_found
    end

    days = params[:days].to_i
    days = 30 unless PERIODOS.include?(days)
    inicio, fim = EstatisticasService.periodo(days: days)
    stats = EstatisticasService.new(user)

    por_disciplina = stats.por_disciplina(inicio, fim).map do |row|
      total = row['total_resolucoes'].to_i
      acertos = row['total_acertos'].to_i
      {
        disciplina_id: row['disciplina_id'],
        disciplina_nome: row['disciplina_nome'],
        total_resolucoes: total,
        total_acertos: acertos,
        total_erros: row['total_erros'].to_i,
        taxa_acerto: EstatisticasService.taxa(acertos, total)
      }
    end

    render json: {
      perfil: {
        fake_id: user.fake_id,
        nome: user.nome_publico,
        membro_desde: user.created_at&.to_date
      },
      periodo: { days: days, inicio: inicio.to_date, fim: fim.to_date },
      resumo: stats.resumo(inicio, fim),
      por_dia: stats.por_dia(inicio, fim),
      por_disciplina: por_disciplina
    }
  end

  def update
    # params.require trataria `false` como ausente (false.blank? == true)
    unless params.key?(:public_stats)
      return render json: { error: 'public_stats é obrigatório' }, status: :bad_request
    end

    current_user.update!(public_stats: ActiveModel::Type::Boolean.new.cast(params[:public_stats]) == true)

    render json: {
      public_stats: current_user.public_stats,
      fake_id: current_user.fake_id,
      path: "/perfil/#{current_user.fake_id}"
    }
  end
end
