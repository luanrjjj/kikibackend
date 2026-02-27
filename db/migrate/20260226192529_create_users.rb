class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :name
      t.string :subscription_status
      t.string :plan
      t.boolean :admin, default: false
      t.string :stripe_customer_id
      t.datetime :current_period_end
      t.datetime :trial_ends_at

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :stripe_customer_id, unique: true
  end
end
