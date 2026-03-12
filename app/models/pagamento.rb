class Pagamento < ApplicationRecord
  belongs_to :user

  enum :gateway, { stripe: 'stripe', woovi: 'woovi', asaas: 'asaas' }
  enum :tipo, { credit_card: 'credit_card', boleto: 'boleto', pix: 'pix' }

  validates :gateway, presence: true
  validates :tipo, presence: true
  validates :consumer_id, presence: true
end
