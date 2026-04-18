class CreatePastasCadernoAndUpdateCadernos < ActiveRecord::Migration[8.0]
  def up
    # 1. Create the new table
    create_table :pasta_cadernos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :nome, null: false
      t.timestamps
    end

    add_index :pasta_cadernos, [:user_id, :nome], unique: true

    # 2. Add columns to cadernos
    add_reference :cadernos, :pasta_caderno, null: true, foreign_key: true
    add_column :cadernos, :prova_criacao_data, :datetime

    # 3. Data Migration: Create default folder for existing cadernos and link them
    # Note: Using execute to avoid model dependency during migrations
    execute <<-SQL
      INSERT INTO pasta_cadernos (user_id, nome, created_at, updated_at)
      SELECT DISTINCT user_id, nome_da_pasta, NOW(), NOW()
      FROM cadernos;

      UPDATE cadernos
      SET pasta_caderno_id = pasta_cadernos.id
      FROM pasta_cadernos
      WHERE cadernos.user_id = pasta_cadernos.user_id
        AND cadernos.nome_da_pasta = pasta_cadernos.nome;
    SQL

    # 4. Make pasta_caderno_id mandatory and remove old column
    change_column_null :cadernos, :pasta_caderno_id, false
    remove_column :cadernos, :nome_da_pasta
  end

  def down
    add_column :cadernos, :nome_da_pasta, :string

    execute <<-SQL
      UPDATE cadernos
      SET nome_da_pasta = pasta_cadernos.nome
      FROM pasta_cadernos
      WHERE cadernos.pasta_caderno_id = pasta_cadernos.id;
    SQL

    change_column_null :cadernos, :nome_da_pasta, false
    remove_column :cadernos, :prova_criacao_data
    remove_reference :cadernos, :pasta_caderno
    drop_table :pasta_cadernos
  end
end
