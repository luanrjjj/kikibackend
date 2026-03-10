class ProvasController < ApplicationController
  before_action :set_prova, only: %i[ show update destroy questaos ]
  before_action :authenticate_admin!, only: %i[ index all]

  # GET /provas
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @provas = Prova.includes(:orgao, :banca, :concurso)
                   .offset((page - 1) * per_page)
                   .limit(per_page)

    render json: {
      data: @provas.as_json(prova_json_options),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Prova.count,
        total_pages: (Prova.count.to_f / per_page).ceil
      }
    }
  end

  def paginated_by_ano
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @provas = Prova.includes(:orgao, :banca, :concurso)
                    .order(ano: :desc)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

    render json: {
      data: @provas.as_json(prova_json_options),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Prova.count,
        total_pages: (Prova.count.to_f / per_page).ceil
      }
    }
  end

  # GET /provas/all
  def all
    render json: Prova.order(:nome).as_json(except: %i[created_at updated_at validado_admin])
  end

  def questaos
    @questaos = @prova.questaos.order(:numero_questao).includes(:assunto, :disciplina, :texto)
    render json: QuestaoSerializer.new(@questaos).serializable_hash
  end

  # GET /provas/1
  def show
    stats = @prova.questaos
                  .left_joins(:disciplina, :assunto)
                  .group('disciplinas.nome', 'assuntos.nome')
                  .count

    summary = stats.each_with_object({}) do |((d_nome, a_nome), count), hash|
      disciplina = d_nome || "Sem Disciplina"
      assunto = a_nome || "Sem Assunto"
      hash[disciplina] ||= { total: 0, assuntos: [] }
      hash[disciplina][:total] += count
      hash[disciplina][:assuntos] << { nome: assunto, total: count }
    end

    render json: @prova.as_json(prova_json_options).merge(
      questaos_summary: {
        total: @prova.questaos.count,
        disciplinas: summary.map { |name, data| { nome: name, **data } }
      }
    )
  end

  # POST /provas
  def create
    @prova = Prova.new(prova_params)

    if @prova.save
      render json: @prova, status: :created, location: @prova
    else
      render json: @prova.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /provas/1
  def update
    if @prova.update(prova_params)
      render json: @prova
    else
      render json: @prova.errors, status: :unprocessable_entity
    end
  end

  # DELETE /provas/1
  def destroy
    @prova.destroy!
  end

  private
    def set_prova
      @prova = Prova.find(params[:id])
    end

    def prova_params
      params.require(:prova).permit(:nome, :orgao_id, :banca_id, :concurso_id, :ano, :escolaridade, :pdfs_folder_url)
    end

    def prova_json_options
      {
        include: {
          orgao: { except: %i[created_at updated_at] },
          banca: { except: %i[created_at updated_at] },
          concurso: { except: %i[created_at updated_at validado_admin] }
        },
        except: %i[created_at updated_at validado_admin]
      }
    end

    def authenticate_admin!
      token = request.headers['Authorization']&.split(' ')&.last
      verification = User.verify_admin_token(token)

      if verification == :unauthorized
        render json: { error: 'Unauthorized' }, status: :unauthorized
      elsif verification == :forbidden
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
end