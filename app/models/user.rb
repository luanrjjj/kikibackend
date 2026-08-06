class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :pagamentos, dependent: :destroy
  has_many :password_resets, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :cadernos, dependent: :destroy
  has_many :pasta_cadernos, dependent: :destroy
  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy
  has_many :comentarios, dependent: :destroy
  has_many :voto_comentarios, dependent: :destroy
  has_many :anotacaos, class_name: 'Anotacao', dependent: :destroy
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
    resolucoes.count
  end

  def percentual_acerto
    total = resolucoes.count
    return 0 if total.zero?
    
    (resolucoes.where(correta: true).count.to_f / total * 100).round(1)
  end

  def monthly_exports_count
    exports.where(created_at: Time.current.all_month).count
  end

  def can_export?
    subscribed? || monthly_exports_count < 3
  end

  def variaveis
    if admin?
      return {
        'show_stats_table_by_assunto_basic' => true,
        'excel_stats_export_advanced' => true,
        'ankis_personalized_advanced' => true,
        'ia_concept_question_extraction_advanced' => true,
        'edital_verticalized_advanced' => true,
        'create_notebook_basic' => true
      }
    end

    plano_record = nil
    if plan.present?
      plano_record = Plano.where('LOWER(nome_do_plano) = ?', plan.to_s.downcase).first
    end

    if (plano_record.nil? || plano_record.variaveis.blank?) && (subscribed? || plan.present?)
      p_name = plan.to_s.downcase
      if p_name.include?('advanced') || p_name.include?('avança') || p_name.include?('pro') || p_name.include?('annual') || p_name.include?('monthly') || p_name.include?('anual') || p_name.include?('mensal') || subscribed?
        plano_record = Plano.where('LOWER(nome_do_plano) = ?', 'advanced').first || Plano.where('LOWER(nome_do_plano) = ?', 'pro').first
      elsif p_name.include?('basic') || p_name.include?('básico')
        plano_record = Plano.where('LOWER(nome_do_plano) = ?', 'basic').first
      end

      plano_record ||= Plano.where.not('LOWER(nome_do_plano) = ?', 'free').first || Plano.last
    end

    vars = plano_record&.variaveis || []
    vars.each_with_object({}) do |v, hash|
      if v.include?(':')
        key, value = v.split(':', 2)
        hash[key] = value == 'true' ? true : (value == 'false' ? false : value)
      else
        hash[v] = true
      end
    end
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
      methods: [:variaveis, :payment_gateway]
    )
  end

  def self.verify_admin_token(token)
    session = Session.includes(:user).find_by(token: token)

    return :unauthorized if session.nil? || session.expires_at < Time.current
    return :forbidden unless session.user.admin?
    :authorized
  end
end
