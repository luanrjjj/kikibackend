class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at

      t.timestamps
    end
    add_index :sessions, :token, unique: true
  end
end