class ConcursosController < ApplicationController
  before_action :set_concurso, only: %i[ show update destroy create_s3_folder upload_edital toggle_blocked ]
  before_action :authenticate_admin!, only: %i[ create update destroy create_s3_folder upload_edital destroy_by_name parse_json toggle_blocked ]
  skip_before_action :authenticate_user!, only: [:public_index, :show]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @concursos = Concurso.all

    if params[:is_blocked].present?
      blocked_val = ActiveModel::Type::Boolean.new.cast(params[:is_blocked])
      @concursos = @concursos.where(is_blocked: blocked_val)
    end
    
    if params[:banca_id].present?
      @concursos = @concursos.where(banca_id: params[:banca_id])
    end

    if params[:orgao_id].present?
      @concursos = @concursos.where(orgao_id: params[:orgao_id])
    end

    if params[:estagio].present?
      @concursos = @concursos.where("concursos.estagio ILIKE ?", "%#{params[:estagio]}%")
    end

    if params[:esfera].present?
      @concursos = @concursos.left_joins(:orgao).where("orgaos.esfera ILIKE ?", "%#{params[:esfera]}%")
    end

    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        @concursos = @concursos.left_joins(:orgao, :banca)
        keywords.each do |kw|
          clean_kw = kw.tr('#', '')
          term = "%#{kw}%"
          if clean_kw.match?(/\A\d+\z/)
            @concursos = @concursos.where(
              "concursos.id = :id_val OR concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              id_val: clean_kw.to_i,
              term: term
            )
          else
            @concursos = @concursos.where(
              "concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              term: term
            )
          end
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

    @concursos = Concurso.unblocked

    search_query = params[:search].presence || params[:nome].presence
    if search_query.present?
      keywords = search_query.to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        @concursos = @concursos.left_joins(:orgao, :banca)
        keywords.each do |kw|
          clean_kw = kw.tr('#', '')
          term = "%#{kw}%"
          if clean_kw.match?(/\A\d+\z/)
            @concursos = @concursos.where(
              "concursos.id = :id_val OR concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              id_val: clean_kw.to_i,
              term: term
            )
          else
            @concursos = @concursos.where(
              "concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              term: term
            )
          end
        end
      end
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
      @concursos = @concursos.left_joins(:orgao).where(orgaos: { esfera: esferas })
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
        provas: { only: [:id, :nome, :ano, :prova_url, :prova_url_ref, :pdfs_folder_url, :edital_url, :escolaridade] }
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
    if @concurso.is_blocked? && !admin_user?
      render json: { error: "Concurso não encontrado" }, status: :not_found
      return
    end

    response_data = @concurso.as_json(include: {
      banca: { only: [:id, :nome, :sigla, :logo] },
      orgao: { except: [:created_at, :updated_at] },
      provas: { only: [:id, :nome, :ano, :prova_url, :prova_url_ref, :pdfs_folder_url, :edital_url, :escolaridade] },
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
    has_filters = params[:search].present? || params[:banca_id].present? || params[:orgao_id].present? || params[:esfera].present? || params[:estagio].present?

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

    @concursos = @concursos.where(banca_id: params[:banca_id]) if params[:banca_id].present?
    @concursos = @concursos.where(orgao_id: params[:orgao_id]) if params[:orgao_id].present?
    @concursos = @concursos.where("concursos.estagio ILIKE ?", "%#{params[:estagio]}%") if params[:estagio].present?
    @concursos = @concursos.left_joins(:orgao).where("orgaos.esfera ILIKE ?", "%#{params[:esfera]}%") if params[:esfera].present?
    
    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        @concursos = @concursos.left_joins(:orgao, :banca)
        keywords.each do |kw|
          clean_kw = kw.tr('#', '')
          term = "%#{kw}%"
          if clean_kw.match?(/\A\d+\z/)
            @concursos = @concursos.where(
              "concursos.id = :id_val OR concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              id_val: clean_kw.to_i,
              term: term
            )
          else
            @concursos = @concursos.where(
              "concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              term: term
            )
          end
        end
      end
    end

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
    @concursos = Concurso.select("concursos.id, concursos.nome, concursos.is_blocked").order(:nome)
    unless params[:include_blocked].to_s == 'true' || admin_user?
      @concursos = @concursos.unblocked
    end
    
    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        @concursos = @concursos.left_joins(:orgao, :banca)
        keywords.each do |kw|
          clean_kw = kw.tr('#', '')
          term = "%#{kw}%"
          if clean_kw.match?(/\A\d+\z/)
            @concursos = @concursos.where(
              "concursos.id = :id_val OR concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              id_val: clean_kw.to_i,
              term: term
            )
          else
            @concursos = @concursos.where(
              "concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR orgaos.sede ILIKE :term OR orgaos.esfera ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              term: term
            )
          end
        end
      end
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
      render_validation_errors(@concurso, "Erro ao criar concurso")
    end
  end

  def update
    if @concurso.update(concurso_params)
      render json: @concurso
    else
      render_validation_errors(@concurso, "Erro ao atualizar concurso")
    end
  end

  def destroy
    @concurso.destroy!
  end

  def toggle_blocked
    Concurso.reset_column_information unless Concurso.column_names.include?('is_blocked')

    result = Concurso.connection.select_one(
      ActiveRecord::Base.sanitize_sql_array([
        "UPDATE concursos SET is_blocked = NOT COALESCE(is_blocked, false), updated_at = NOW() WHERE id = ? RETURNING *",
        @concurso.id
      ])
    )

    if result
      @concurso.reload
      render json: @concurso
    else
      render json: { error: "Erro ao atualizar concurso" }, status: :unprocessable_entity
    end
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

  # POST /concursos/parse_json
  def parse_json
    raw_payload = params[:json_data].presence || params[:concurso_json].presence || request.request_parameters

    parsed = if raw_payload.is_a?(String)
      begin
        JSON.parse(raw_payload)
      rescue JSON::ParserError => e
        render json: { error: "JSON inválido: #{e.message}" }, status: :unprocessable_entity
        return
      end
    elsif raw_payload.respond_to?(:to_unsafe_h)
      raw_payload.to_unsafe_h
    elsif raw_payload.is_a?(Hash)
      raw_payload
    else
      render json: { error: "Formato de dados não reconhecido" }, status: :unprocessable_entity
      return
    end

    if parsed.key?("json_data") && (parsed["json_data"].is_a?(Hash) || parsed["json_data"].is_a?(String))
      inner = parsed["json_data"]
      parsed = inner.is_a?(String) ? (JSON.parse(inner) rescue parsed) : inner
    end

    nome = parsed["concurso_nome"].presence || parsed["nome"].presence || ""
    edital_nome = parsed["edital_nome"].presence || ""
    edital_url = parsed["edital_url"].presence || ""

    prazos = parsed["prazos"] || {}
    inscricoes_ate = prazos["inscricoes_ate"].presence || parsed["inscricoes_ate"].presence || ""
    raw_estagio = prazos["estagio"].presence || parsed["estagio"].presence || ""
    estagio = normalize_estagio(raw_estagio)

    create_missing = [true, "true", 1, "1"].include?(params[:create_missing])

    db_orgao_id = parsed.dig("banco_dados", "orgao_id") || parsed["orgao_id"]
    orgao_data = parsed["orgao"]
    matched_orgao = find_orgao(orgao_data, db_orgao_id)

    if matched_orgao.nil? && create_missing && orgao_data.is_a?(Hash) && orgao_data["nome"].present?
      matched_orgao = Orgao.create(
        nome: orgao_data["nome"],
        sigla: orgao_data["sigla"],
        esfera: orgao_data["esfera"],
        sede: [orgao_data["municipio"], orgao_data["uf"]].compact.reject(&:blank?).join("/")
      )
    end

    db_banca_id = parsed.dig("banco_dados", "banca_id") || parsed["banca_id"]
    banca_data = parsed["banca"]
    matched_banca = find_banca(banca_data, db_banca_id)

    if matched_banca.nil? && create_missing && banca_data.is_a?(Hash) && banca_data["nome"].present?
      matched_banca = Banca.create(
        nome: banca_data["nome"],
        sigla: banca_data["sigla"].presence || banca_data["nome"].slice(0, 10)
      )
    end

    cargos = parsed["cargos"] || []

    render json: {
      success: true,
      data: {
        nome: nome,
        edital_nome: edital_nome,
        edital_url: edital_url,
        inscricoes_ate: inscricoes_ate,
        estagio: estagio,
        orgao_id: matched_orgao&.id,
        banca_id: matched_banca&.id,
        cargos: cargos,
        matched_orgao: matched_orgao ? { id: matched_orgao.id, nome: matched_orgao.nome, sigla: matched_orgao.sigla, esfera: matched_orgao.esfera } : nil,
        matched_banca: matched_banca ? { id: matched_banca.id, nome: matched_banca.nome, sigla: matched_banca.sigla } : nil,
        unmatched_orgao: matched_orgao ? nil : orgao_data,
        unmatched_banca: matched_banca ? nil : banca_data
      }
    }
  rescue StandardError => e
    Rails.logger.error "ConcursosController#parse_json Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    render json: { error: "Erro ao processar JSON do concurso: #{e.message}" }, status: :unprocessable_entity
  end

  private
    def set_concurso
      Concurso.reset_column_information unless Concurso.column_names.include?('is_blocked')
      @concurso = Concurso.find(params[:id])
    end

    def concurso_params
      concurso_p = params[:concurso].presence || params
      permitted = concurso_p.permit(:nome, :inscricoes_ate, :edital_nome, :banca_id, :orgao_id, :edital_url, :estagio, :is_blocked)
      if concurso_p.key?(:cargos)
        raw_cargos = concurso_p[:cargos]
        permitted[:cargos] = if raw_cargos.is_a?(String)
          begin
            JSON.parse(raw_cargos)
          rescue JSON::ParserError
            raw_cargos
          end
        elsif raw_cargos.respond_to?(:to_unsafe_h)
          raw_cargos.to_unsafe_h
        elsif raw_cargos.is_a?(Array)
          raw_cargos.map { |item| item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item }
        else
          raw_cargos
        end
      end
      permitted
    end

    def find_orgao(orgao_data, db_id = nil)
      if db_id.present?
        found = Orgao.find_by(id: db_id)
        return found if found
      end
      return nil unless orgao_data.is_a?(Hash)

      sigla = orgao_data["sigla"].to_s.strip
      nome = orgao_data["nome"].to_s.strip
      norm_sigla = sigla.gsub(/[-_\s.]/, "").upcase

      if sigla.present?
        found = Orgao.where("UPPER(sigla) = ?", sigla.upcase).first
        return found if found
      end

      if norm_sigla.present?
        found = Orgao.where("REGEXP_REPLACE(UPPER(sigla), '[-_\\s.]', '', 'g') = ?", norm_sigla).first
        return found if found
      end

      if nome.present?
        found = Orgao.where("LOWER(TRIM(nome)) = ?", nome.downcase).first
        return found if found
      end

      if sigla.present?
        found = Orgao.where("sigla ILIKE ?", "%#{sigla}%").first
        return found if found
      end

      if nome.present?
        found = Orgao.where("nome ILIKE ?", "%#{nome}%").first
        return found if found
      end

      nil
    end

    def find_banca(banca_data, db_id = nil)
      if db_id.present?
        found = Banca.find_by(id: db_id)
        return found if found
      end
      return nil unless banca_data.is_a?(Hash)

      sigla = banca_data["sigla"].to_s.strip
      nome = banca_data["nome"].to_s.strip
      norm_sigla = sigla.gsub(/[-_\s.]/, "").upcase

      if sigla.present?
        found = Banca.where("UPPER(sigla) = ?", sigla.upcase).first
        return found if found
      end

      if norm_sigla.present?
        found = Banca.where("REGEXP_REPLACE(UPPER(sigla), '[-_\\s.]', '', 'g') = ?", norm_sigla).first
        return found if found
      end

      if nome.present?
        found = Banca.where("LOWER(TRIM(nome)) = ?", nome.downcase).first
        return found if found
      end

      if sigla.present?
        found = Banca.where("sigla ILIKE ?", "%#{sigla}%").first
        return found if found
      end

      if nome.present?
        found = Banca.where("nome ILIKE ?", "%#{nome}%").first
        return found if found
      end

      nil
    end

    def normalize_estagio(raw)
      val = raw.to_s.strip.downcase
      case val
      when 'aberto'
        'aberto'
      when 'inscrições abertas', 'inscricoes abertas'
        'inscrições abertas'
      when 'inscrições encerradas', 'inscricoes encerradas'
        'inscrições encerradas'
      when 'encerrado'
        'encerrado'
      when 'previsto'
        'previsto'
      when 'autorizado'
        'autorizado'
      when 'comissão formada', 'comissao formada'
        'comissão formada'
      when 'banca definida'
        'banca definida'
      when 'edital publicado'
        'edital publicado'
      when 'em andamento'
        'em andamento'
      else
        val.presence || 'aberto'
      end
    end
end
