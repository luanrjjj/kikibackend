class AssuntosController < ApplicationController
  before_action :set_assunto, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @assuntos = Assunto.left_joins(:questaos)
                       .select("assuntos.*, COUNT(questaos.id) AS total_questoes")
                       .group("assuntos.id")

    if params[:disciplina_id].present?
      @assuntos = @assuntos.where(disciplina_id: params[:disciplina_id])
    end

    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        keywords.each do |kw|
          clean_kw = kw.tr('#', '')
          term = "%#{kw}%"
          if clean_kw.match?(/\A\d+\z/)
            @assuntos = @assuntos.where("assuntos.id = :id_val OR assuntos.nome ILIKE :term", id_val: clean_kw.to_i, term: term)
          else
            @assuntos = @assuntos.where("assuntos.nome ILIKE :term", term: term)
          end
        end
      end
    end

    sort_column = params[:sort_by].presence || "total_questoes"
    sort_direction = params[:direction].to_s.downcase == "asc" ? "ASC" : "DESC"

    if sort_column == "nome"
      @assuntos = @assuntos.order(Arel.sql("assuntos.nome #{sort_direction}"))
    elsif sort_column == "id"
      @assuntos = @assuntos.order(Arel.sql("assuntos.id #{sort_direction}"))
    else
      @assuntos = @assuntos.order(Arel.sql("COUNT(questaos.id) #{sort_direction}, assuntos.nome ASC"))
    end

    count_scope = Assunto.all
    if params[:disciplina_id].present?
      count_scope = count_scope.where(disciplina_id: params[:disciplina_id])
    end
    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      keywords.each do |kw|
        clean_kw = kw.tr('#', '')
        term = "%#{kw}%"
        if clean_kw.match?(/\A\d+\z/)
          count_scope = count_scope.where("assuntos.id = :id_val OR assuntos.nome ILIKE :term", id_val: clean_kw.to_i, term: term)
        else
          count_scope = count_scope.where("assuntos.nome ILIKE :term", term: term)
        end
      end
    end
    total_count = count_scope.count

    @assuntos = @assuntos.includes(:disciplina).offset((page - 1) * per_page).limit(per_page)

    data = @assuntos.map do |a|
      a.as_json.merge(
        total_questoes: a.attributes["total_questoes"].to_i,
        disciplina_nome: a.disciplina&.nome
      )
    end

    render json: {
      data: data,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def all
    result = Rails.cache.fetch("assuntos/all", expires_in: 24.hours) do
      Assunto.select(:id, :nome, :disciplina_id).order(:nome).to_a
    end
    render json: result
  end

  def filters
    scope = Assunto.order(:nome)
    scope = scope.where('nome ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    render json: scope.pluck(:id, :nome, :disciplina_id).map { |id, nome, d_id| { id: id, nome: nome, disciplina_id: d_id } }
  end

  def show
    render json: @assunto
  end

  def create
    @assunto = Assunto.new(assunto_params)

    if @assunto.save
      Rails.cache.delete("assuntos/all")
      render json: @assunto, status: :created, location: @assunto
    else
      render json: @assunto.errors, status: :unprocessable_entity
    end
  end

  def update
    if @assunto.update(assunto_params)
      Rails.cache.delete("assuntos/all")
      render json: @assunto
    else
      render json: @assunto.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @assunto.destroy!
    Rails.cache.delete("assuntos/all")
  end

  private
    def set_assunto
      @assunto = Assunto.find(params[:id])
    end

    def assunto_params
      params.require(:assunto).permit(:nome, :disciplina_id)
    end
end