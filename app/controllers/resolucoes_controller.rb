class ResolucoesController < ApplicationController
  before_action :authenticate_admin!, only: %i[ index global_stats ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    resolucoes = Resolucao.includes(:user, :questao, :caderno)
                          .order(created_at: :desc)
                          .offset((page - 1) * per_page)
                          .limit(per_page)

    render json: {
      data: resolucoes.as_json(include: {
        user: { only: [:id, :email, :name] },
        questao: { only: [:id, :enunciado] },
        caderno: { only: [:id, :nome] }
      }),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Resolucao.count,
        total_pages: (Resolucao.count.to_f / per_page).ceil
      }
    }
  end

  def global_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30
    render json: EstatisticasService.global(days.days.ago)
  end

  def create
    @questao = Questao.find_by!(id: params[:resolucao][:questao_id])

    # Limite de resoluções do plano (limit_resolutions_free; sem a variável, ilimitado)
    limite = current_user.limite_resolucoes
    if limite && current_user.resolucoes.originais.count >= limite
      return render_upgrade_required(
        'limit_resolutions_free',
        message: "Você resolveu as #{limite} questões do plano gratuito. Assine para continuar resolvendo sem limite.",
        limite: limite
      )
    end

    is_correct = @questao.correta == params[:resolucao][:resposta]

    @resolucao = current_user.resolucoes.new(resolucao_params)
    @resolucao.correta = is_correct

    if @resolucao.save
      render json: {
        resolucao: @resolucao,
        correta: is_correct,
        resposta_correta: @questao.correta
      }, status: :created
    else
      render json: @resolucao.errors, status: :unprocessable_entity
    end
  end

  def stats
    start_date, end_date = calculate_date_range
    render json: estatisticas.por_dia(start_date, end_date)
  end

  def discipline_stats
    start_date, end_date = calculate_date_range
    render json: estatisticas.por_disciplina(start_date, end_date)
  end

  def subject_stats
    start_date, end_date = calculate_date_range
    render json: estatisticas.por_assunto(start_date, end_date, disciplina_id: params[:disciplina_id])
  end

  def hierarchical_stats
    return render_upgrade_required('show_stats_table_by_assunto_basic') unless current_user.pode?('show_stats_table_by_assunto_basic')

    start_date, end_date = calculate_date_range
    render json: estatisticas.hierarquia(start_date, end_date)
  end

  def gerar_caderno_stats
    return render_upgrade_required('create_notebook_basic') unless current_user.pode?('create_notebook_basic')

    disciplina_ids = Array(params[:disciplina_ids]).map(&:to_i).reject(&:zero?)
    assunto_ids = Array(params[:assunto_ids]).map(&:to_s).reject(&:blank?)
    topico_ids = Array(params[:topico_ids]).map(&:to_i).reject(&:zero?)
    only_errors = ActiveModel::Type::Boolean.new.cast(params[:only_errors])

    clean_assunto_ids = assunto_ids.reject { |id| id.start_with?('sem-assunto-') }.map(&:to_i).reject(&:zero?)

    if disciplina_ids.empty? && clean_assunto_ids.empty? && topico_ids.empty?
      return render json: { error: 'invalid_params', message: 'Selecione ao menos um tópico ou matéria.' }, status: :unprocessable_entity
    end

    periodo = (calculate_date_range if only_errors && (params[:start_date].present? || params[:days].present?))
    ids = estatisticas.questoes_para_caderno(
      disciplina_ids: disciplina_ids,
      assunto_ids: clean_assunto_ids,
      topico_ids: topico_ids,
      only_errors: only_errors,
      periodo: periodo
    )

    if ids.empty?
      msg = only_errors ? 'Nenhuma questão errada encontrada para os tópicos selecionados.' : 'Nenhuma questão encontrada para os tópicos selecionados.'
      return render json: { error: 'no_questions', message: msg }, status: :unprocessable_entity
    end

    max_limit = current_user.variaveis['max_caderno_questoes'].to_i
    max_limit = 10_000 if max_limit <= 0

    if ids.length > max_limit
      return render json: {
        error: 'max_caderno_questoes_exceeded',
        message: "Excedeu a quantidade máxima de #{max_limit} questões permitidas por caderno.",
        max_caderno_questoes: max_limit,
        questoes_count: ids.length
      }, status: :unprocessable_entity
    end

    # Pasta "Estatística"
    pasta = current_user.pasta_cadernos.where('LOWER(nome) = ?', 'estatística').first ||
            current_user.pasta_cadernos.create!(nome: 'Estatística')

    tipo_label = only_errors ? 'Erros' : 'Revisão'
    timestamp = Time.current.strftime('%d/%m/%Y %H:%M')
    default_nome = params[:caderno_nome].presence || "Estatísticas - #{tipo_label} (#{timestamp})"

    caderno = current_user.cadernos.create!(
      nome: default_nome,
      pasta_caderno_id: pasta.id,
      questoes_ids: ids,
      filtros: {
        origem: 'estatisticas',
        only_errors: only_errors,
        disciplina_ids: disciplina_ids,
        assunto_ids: clean_assunto_ids,
        topico_ids: topico_ids,
        questoes_count: ids.length
      }
    )

    render json: {
      id: caderno.id,
      nome: caderno.nome,
      pasta_id: pasta.id,
      pasta_nome: pasta.nome,
      questoes_count: ids.length,
      message: "Caderno criado com sucesso com #{ids.length} questões na pasta #{pasta.nome}!"
    }, status: :created
  end

  def export_excel_stats
    return render_upgrade_required('excel_stats_export_advanced') unless current_user.pode?('excel_stats_export_advanced')

    render json: { status: 'ok', message: 'Permissão concedida para exportação.' }
  end

  def notebook_stats
    caderno_id = params[:caderno_id]
    return render json: { error: "Caderno ID is required" }, status: :bad_request if caderno_id.blank?

    caderno = Caderno.find_by(id: caderno_id)
    return render json: { error: "Caderno not found" }, status: :not_found unless caderno

    render json: estatisticas.caderno(caderno)
  end

  def question_stats
    questao_id = params[:questao_id]
    return render json: { error: "Questao ID is required" }, status: :bad_request if questao_id.blank?

    render json: estatisticas.questao(questao_id)
  end

  private

  def estatisticas
    @estatisticas ||= EstatisticasService.new(current_user)
  end

  def calculate_date_range
    EstatisticasService.periodo(days: params[:days], start_date: params[:start_date], end_date: params[:end_date])
  end

  def resolucao_params
    params.require(:resolucao).permit(:questao_id, :caderno_id, :resposta)
  end
end
