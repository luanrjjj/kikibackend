class ConcursosController < ApplicationController
  before_action :set_concurso, only: %i[ show update destroy create_s3_folder upload_edital ]
  skip_before_action :authenticate_user!, only: [:public_index]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @concursos = Concurso.all
    
    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        @concursos = @concursos.left_joins(:orgao, :banca)
        keywords.each do |kw|
          term = "%#{kw}%"
          @concursos = @concursos.where(
            "concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
            term: term
          )
        end
      end
    end

    total_count = @concursos.count
    @concursos = @concursos.includes(:banca, :orgao)
                         .order(inscricoes_ate: :desc)
                         .offset((page - 1) * per_page)
                         .limit(per_page)

    render json: {
      data: @concursos.as_json(include: [:banca, :orgao, :provas]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def public_index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 10).to_i, 1].max

    @concursos = Concurso.all

    if params[:nome].present?
      @concursos = @concursos.where("concursos.nome ILIKE ?", "%#{params[:nome]}%")
    end

    if params[:banca_id].present?
      banca_ids = params[:banca_id].is_a?(Array) ? params[:banca_id] : [params[:banca_id]]
      @concursos = @concursos.where(banca_id: banca_ids)
    end

    if params[:ano].present?
      anos = params[:ano].is_a?(Array) ? params[:ano] : [params[:ano]]
      @concursos = @concursos.where(id: Concurso.joins(:provas).where(provas: { ano: anos }).select(:id))
    end

    if params[:esfera].present?
      esferas = params[:esfera].is_a?(Array) ? params[:esfera] : [params[:esfera]]
      @concursos = @concursos.joins(:orgao).where(orgaos: { esfera: esferas })
    end

    total_count = @concursos.count

    order_clause = if params[:sort_by] == 'created_at'
                     { created_at: params[:direction] || :desc }
                   else
                     Arel.sql("CASE WHEN inscricoes_ate >= CURRENT_DATE THEN 0 ELSE 1 END, CASE WHEN inscricoes_ate >= CURRENT_DATE THEN inscricoes_ate END ASC, inscricoes_ate DESC NULLS LAST")
                   end

    @concursos = @concursos.includes(:banca, :orgao, :provas)
                         .order(order_clause)
                         .offset((page - 1) * per_page)
                         .limit(per_page)

    render json: {
      data: @concursos.as_json(include: {
        banca: { only: [:id, :nome, :sigla, :logo] },
        orgao: { except: [:created_at, :updated_at] },
        provas: { only: [:id, :nome, :ano] }
      }),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def show
    response_data = @concurso.as_json(include: {
      banca: { only: [:id, :nome, :sigla, :logo] },
      orgao: { except: [:created_at, :updated_at] },
      provas: { only: [:id, :nome, :ano] },
      edital_verts: { only: [:id, :cargo, :prova_id, :texto_json_disciplina, :texto_verticalizado] },
      guias: { only: [:id, :nome] }
    })

    response_data['similar_concursos'] = @concurso.similar_concursos(5).as_json(include: {
      banca: { only: [:id, :nome, :sigla, :logo] },
      orgao: { except: [:created_at, :updated_at] }
    })

    render json: response_data
  end

  def stats
    has_filters = params[:search].present?

    if !has_filters
      cached_stats = Rails.cache.read("admin/stats/concursos/global")
      if cached_stats
        Rails.logger.info "[Cache] Hit admin/stats/concursos/global"
        render json: cached_stats
        return
      else
        Rails.logger.info "[Cache] Miss admin/stats/concursos/global"
      end
    end

    @concursos = Concurso.all

    # Filter by name if search present
    @concursos = @concursos.where("nome ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    total_count = @concursos.count

    # Calculate by_year using provas associated with the concursos
    by_year = Concurso.joins(:provas)
                     .where(id: @concursos.pluck(:id))
                     .group('provas.ano')
                     .distinct
                     .count('concursos.id')
                     .sort.to_h

    render_data = {
      total_count: total_count,
      by_year: by_year,
      updated_at: Time.current
    }

    # Cache global results if no filters were applied
    Rails.cache.write("admin/stats/concursos/global", render_data) if !has_filters

    render json: render_data
  end

  def all
    @concursos = Concurso.select(:id, :nome).order(:nome)
    
    if params[:search].present?
      @concursos = @concursos.where("nome ILIKE ?", "%#{params[:search]}%")
    end

    # If search is present, we limit to 50. If not, we return everything (for backward compatibility if needed)
    # but ideally we should always limit or use pagination for very large sets.
    @concursos = @concursos.limit(50) if params[:search].present?

    render json: @concursos
  end

  def create
    @concurso = Concurso.new(concurso_params)

    if @concurso.save
      render json: @concurso, status: :created, location: @concurso
    else
      render json: @concurso.errors, status: :unprocessable_entity
    end
  end

  def update
    if @concurso.update(concurso_params)
      render json: @concurso
    else
      render json: @concurso.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @concurso.destroy!
  end

  def create_s3_folder
    if @concurso.pdf_folder_url.present?
      render json: { error: "Este concurso já possui uma pasta vinculada." }, status: :bad_request
      return
    end

    # Create a safe folder name from concurso name
    folder_name = @concurso.nome.parameterize
    
    begin
      url = SpacesService.create_folder(folder_name)
      @concurso.update!(pdf_folder_url: url)
      render json: @concurso.as_json(include: [:banca, :orgao, :provas])
    rescue StandardError => e
      render json: { error: "Erro ao criar pasta no Spaces: #{e.message}" }, status: :internal_server_error
    end
  end

  def upload_edital
    if params[:file].blank?
      render json: { error: "Arquivo não fornecido." }, status: :bad_request
      return
    end

    folder_name = @concurso.nome.parameterize
    file = params[:file]
    key = "concursos_pdfs/#{folder_name}/edital_#{Time.now.to_i}_#{file.original_filename}"

    begin
      url = SpacesService.upload_file(key, file)
      @concurso.update!(edital_url: url)
      render json: @concurso.as_json(include: [:banca, :orgao, :provas])
    rescue StandardError => e
      render json: { error: "Erro ao fazer upload do edital: #{e.message}" }, status: :internal_server_error
    end
  end

  # DELETE /concursos/destroy_by_name?nome=XXX
  def destroy_by_name
    if params[:nome].blank?
      render json: { error: "Nome é obrigatório" }, status: :bad_request
      return
    end

    @concursos = Concurso.where(nome: params[:nome])
    count = @concursos.count

    if count == 0
      render json: { message: "Nenhum concurso encontrado com o nome: #{params[:nome]}" }, status: :not_found
      return
    end

    @concursos.destroy_all

    render json: {
      message: "Sucesso ao deletar concursos",
      count: count,
      nome: params[:nome]
    }, status: :ok
  end

  private
    def set_concurso
      @concurso = Concurso.find(params[:id])
    end

    def concurso_params
      params.require(:concurso).permit(:nome, :inscricoes_ate, :edital_nome, :banca_id, :orgao_id, :cargos, :edital_url, :estagio)
    end
end
