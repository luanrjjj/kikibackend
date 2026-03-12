class CreatePlanos < ActiveRecord::Migration[8.0]
  def change
    create_table :planos do |t|
      t.string :nome_do_plano
      t.decimal :valor, precision: 8, scale: 2
      t.decimal :valor_promocional, precision: 8, scale: 2
      t.datetime :data_inicio_promocao
      t.datetime :data_fim_promocao

      t.timestamps
    end
  end
end
