class TopicosController < ApplicationController
  before_action :set_topico, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @topicos = Topico.left_outer_joins(:disciplina, :assunto)

    # Filtro por assunto e/ou disciplina. Alguns tópicos não têm disciplina_id
    # preenchido; nesse caso vale a disciplina do assunto.
    if params[:assunto_id].present?
      @topicos = @topicos.where(topicos: { assunto_id: params[:assunto_id].to_i })
    end
    if params[:disciplina_id].present?
      @topicos = @topicos.where('topicos.disciplina_id = :d OR assuntos.disciplina_id = :d', d: params[:disciplina_id].to_i)
    end

    # Busca por nome (todas as palavras) ou por ID (#123)
    params[:search].to_s.strip.split(/\s+/).reject(&:blank?).each do |kw|
      clean_kw = kw.delete('#')
      if clean_kw.match?(/\A\d+\z/)
        @topicos = @topicos.where('topicos.id = :id OR topicos.nome ILIKE :term', id: clean_kw.to_i, term: "%#{kw}%")
      else
        @topicos = @topicos.where('topicos.nome ILIKE ?', "%#{Topico.sanitize_sql_like(kw)}%")
      end
    end

    total_count = @topicos.count
    @topicos = @topicos.select('topicos.*, disciplinas.nome AS disciplina_nome, assuntos.nome AS assunto_nome')
                       .order('disciplinas.nome ASC, assuntos.nome ASC, topicos.nome ASC, topicos.id ASC')
                       .offset((page - 1) * per_page)
                       .limit(per_page)

    render json: {
      data: @topicos.map { |t| t.as_json.merge('disciplina_nome' => t['disciplina_nome'], 'assunto_nome' => t['assunto_nome']) },
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def all
    result = Rails.cache.fetch("topicos/all", expires_in: 24.hours) do
      Topico.left_outer_joins(:disciplina, :assunto)
            .select('topicos.*, disciplinas.nome as disciplina_nome, assuntos.nome as assunto_nome')
            .order('disciplinas.nome ASC, assuntos.nome ASC, topicos.nome ASC').to_a
    end
    render json: result
  end

  def show
    render json: @topico
  end

  def create
    @topico = Topico.new(topico_params)

    if @topico.save
      Rails.cache.delete("topicos/all")
      render json: @topico, status: :created, location: @topico
    else
      render json: @topico.errors, status: :unprocessable_entity
    end
  end

  def update
    if @topico.update(topico_params)
      Rails.cache.delete("topicos/all")
      render json: @topico
    else
      render json: @topico.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @topico.destroy!
    Rails.cache.delete("topicos/all")
  end

  private
    def set_topico
      @topico = Topico.find(params[:id])
    end

    def topico_params
      params.require(:topico).permit(:nome, :disciplina_id, :assunto_id)
    end
end
