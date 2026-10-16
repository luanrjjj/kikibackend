class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :mcp_usos_diarios, class_name: 'McpUsoDiario', dependent: :delete_all
  has_many :pagamentos, dependent: :destroy
  has_many :password_resets, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :cadernos, dependent: :destroy
  has_many :pasta_cadernos, dependent: :destroy
  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy
  has_many :comentarios, dependent: :destroy
  has_many :voto_comentarios, dependent: :destroy
  has_many :anotacaos, class_name: 'Anotacao', dependent: :destroy
  has_many :explicacao_ia_avaliacoes, class_name: 'ExplicacaoIaAvaliacao', dependent: :delete_all
  has_many :filtros, dependent: :destroy
  has_many :reports, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def generate_password_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!
  end

  def password_reset_period_valid?
    reset_password_sent_at > 2.hours.ago
  end

  def reset_password!(new_password)
    self.reset_password_token = nil
    self.password = new_password
    save!
  end

  def subscribed?
    admin? || (subscription_status&.upcase == 'ACTIVE' && current_period_end.present? && current_period_end > Time.current)
  end

  def assinatura
    if admin?
      'Administrador'
    elsif subscribed?
      plan.present? ? plan.titleize : 'Premium'
    else
      'Gratuito'
    end
  end

  def total_resolucoes
    resolucoes.originais.count
  end

  def percentual_acerto
    total = resolucoes.originais.count
    return 0 if total.zero?
    
    (resolucoes.originais.where(correta: true).count.to_f / total * 100).round(1)
  end

  # Exportações para o Anki feitas nesta semana (segunda a domingo).
  def exportacoes_da_semana
    exports.validas.where(created_at: Time.current.all_week).count
  end

  # Limite semanal de exportações do plano; nil quando ilimitado.
  def limite_exportacoes_semana
    limite = variaveis['anki_export_by_week_free']
    limite.is_a?(Integer) ? limite : nil
  end

  def can_export?
    limite = limite_exportacoes_semana
    limite.nil? || exportacoes_da_semana < limite
  end

  # Limite de resoluções de questões do plano; nil quando ilimitado.
  def limite_resolucoes
    limite = variaveis['limit_resolutions_free']
    limite.is_a?(Integer) ? limite : nil
  end

  # Nível do plano em uso: :admin, :free, :basic ou :advanced.
  # Quem não tem assinatura ativa (inclusive expirada) fica no :free.
  def plano_nivel
    return :admin if admin?

    subscribed? ? Plano.nivel_da_assinatura(plan) : :free
  end

  # Se o plano do usuário libera o recurso (ver Plano para a lista).
  def pode?(recurso)
    admin? || variaveis[recurso.to_s] == true
  end

  # Permissões e limites do plano do usuário, como hash
  # ({ 'create_notebook_basic' => true, 'limit_resolutions_free' => 100, ... }).
  # Recurso ausente é false; limite ausente é ilimitado.
  def variaveis
    @variaveis ||= calcular_variaveis
  end

  def reload(*)
    @variaveis = nil
    super
  end

  def payment_gateway
    if stripe_customer_id.present?
      'Stripe'
    elsif asaas_customer_id.present?
      'Asaas'
    else
      nil
    end
  end

  def to_session_json
    as_json(
      except: [:password_digest, :reset_password_token, :reset_password_sent_at, :stripe_customer_id, :asaas_customer_id, :created_at, :updated_at],
      methods: [:variaveis, :payment_gateway, :plano_nivel]
    )
  end

  def self.verify_admin_token(token)
    session = Session.includes(:user).find_by(token: token)

    return :unauthorized if session.nil? || session.expires_at < Time.current
    return :forbidden unless session.user.admin?
    :authorized
  end

  private

  def calcular_variaveis
    vars =
      if admin?
        Plano::RECURSOS_BOOLEANOS.index_with { true }
      else
        Plano.variaveis_do_nivel(plano_nivel)
      end

    vars['max_caderno_questoes'] = max_caderno_questoes_do_plano(vars['max_caderno_questoes'])
    vars
  end

  def max_caderno_questoes_do_plano(valor_do_plano)
    return valor_do_plano if valor_do_plano.is_a?(Integer) && valor_do_plano.positive? && !admin?

    global = ConfigGlobalApolo.find_by(nome_da_variavel: 'max_caderno_questoes')&.valor_da_variavel
    global.present? && global.to_i > 0 ? global.to_i : 10_000
  end
end
