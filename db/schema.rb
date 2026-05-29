# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_29_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "area_de_atuacaos", force: :cascade do |t|
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "area_de_formacaos", force: :cascade do |t|
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "assuntos", force: :cascade do |t|
    t.string "nome", null: false
    t.bigint "disciplina_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["disciplina_id"], name: "index_assuntos_on_disciplina_id"
  end

  create_table "bancas", force: :cascade do |t|
    t.string "nome", null: false
    t.string "logo"
    t.string "sigla", null: false
    t.integer "total_concursos"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "questaos_count", default: 0
    t.integer "com_gabarito_count", default: 0
    t.index ["questaos_count"], name: "index_bancas_on_questaos_count"
  end

  create_table "cadernos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "prova_id"
    t.bigint "concurso_id"
    t.json "questoes_ids", default: []
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pasta_caderno_id", null: false
    t.datetime "prova_criacao_data"
    t.json "filtros"
    t.bigint "filtro_id"
    t.index ["concurso_id"], name: "index_cadernos_on_concurso_id"
    t.index ["filtro_id"], name: "index_cadernos_on_filtro_id"
    t.index ["pasta_caderno_id"], name: "index_cadernos_on_pasta_caderno_id"
    t.index ["prova_id"], name: "index_cadernos_on_prova_id"
    t.index ["user_id", "nome"], name: "index_cadernos_on_user_id_and_nome", unique: true
    t.index ["user_id"], name: "index_cadernos_on_user_id"
  end

  create_table "cargo_guias", force: :cascade do |t|
    t.string "nome_do_cargo"
    t.bigint "filtro_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["filtro_id"], name: "index_cargo_guias_on_filtro_id"
  end

  create_table "comentarios", force: :cascade do |t|
    t.bigint "prova_id"
    t.bigint "user_id", null: false
    t.bigint "concurso_id"
    t.bigint "questao_id", null: false
    t.integer "votos_soma", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "texto"
    t.index ["concurso_id"], name: "index_comentarios_on_concurso_id"
    t.index ["prova_id"], name: "index_comentarios_on_prova_id"
    t.index ["questao_id"], name: "index_comentarios_on_questao_id"
    t.index ["user_id"], name: "index_comentarios_on_user_id"
  end

  create_table "concursos", force: :cascade do |t|
    t.string "nome"
    t.date "inscricoes_ate"
    t.string "edital_nome"
    t.json "cargos"
    t.bigint "banca_id"
    t.bigint "orgao_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "validado_admin"
    t.string "pdf_folder_url"
    t.string "edital_url"
    t.string "estagio"
    t.index ["banca_id"], name: "index_concursos_on_banca_id"
    t.index ["orgao_id"], name: "index_concursos_on_orgao_id"
  end

  create_table "config_global_apolo", force: :cascade do |t|
    t.string "nome_da_variavel", null: false
    t.string "valor_da_variavel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["nome_da_variavel"], name: "index_config_global_apolo_on_nome_da_variavel", unique: true
  end

  create_table "disciplinas", force: :cascade do |t|
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "exports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "prova_id"
    t.bigint "concurso_id"
    t.integer "questoes_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concurso_id"], name: "index_exports_on_concurso_id"
    t.index ["prova_id"], name: "index_exports_on_prova_id"
    t.index ["user_id"], name: "index_exports_on_user_id"
  end

  create_table "filtros", force: :cascade do |t|
    t.bigint "user_id"
    t.json "filtro"
    t.string "nome_do_filtro"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_filtros_on_user_id"
  end

  create_table "guia_filtros", force: :cascade do |t|
    t.bigint "guia_id", null: false
    t.bigint "filtro_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "cargo_guia_id"
    t.index ["cargo_guia_id"], name: "index_guia_filtros_on_cargo_guia_id"
    t.index ["filtro_id"], name: "index_guia_filtros_on_filtro_id"
    t.index ["guia_id"], name: "index_guia_filtros_on_guia_id"
  end

  create_table "guias", force: :cascade do |t|
    t.bigint "concurso_id", null: false
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concurso_id"], name: "index_guias_on_concurso_id"
  end

  create_table "orgaos", force: :cascade do |t|
    t.string "nome", null: false
    t.string "sigla"
    t.string "sede"
    t.string "logo_url"
    t.string "esfera"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pagamentos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "gateway"
    t.string "consumer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tipo"
    t.index ["user_id"], name: "index_pagamentos_on_user_id"
  end

  create_table "password_resets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_password_resets_on_token", unique: true
    t.index ["user_id"], name: "index_password_resets_on_user_id"
  end

  create_table "pasta_cadernos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "nome"], name: "index_pasta_cadernos_on_user_id_and_nome", unique: true
    t.index ["user_id"], name: "index_pasta_cadernos_on_user_id"
  end

  create_table "planos", force: :cascade do |t|
    t.string "nome_do_plano"
    t.decimal "valor_mensal", precision: 8, scale: 2
    t.decimal "valor_promocional_mensal", precision: 8, scale: 2
    t.datetime "data_inicio_promocao"
    t.datetime "data_fim_promocao"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "valor_anual", precision: 8, scale: 2
    t.decimal "valor_promocional_anual", precision: 8, scale: 2
  end

  create_table "prova_questaos", force: :cascade do |t|
    t.bigint "prova_id", null: false
    t.bigint "questao_id", null: false
    t.integer "numero_questao", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prova_id", "questao_id"], name: "index_prova_questaos_on_prova_id_and_questao_id", unique: true
    t.index ["prova_id"], name: "index_prova_questaos_on_prova_id"
    t.index ["questao_id"], name: "index_prova_questaos_on_questao_id"
  end

  create_table "provas", force: :cascade do |t|
    t.string "nome", null: false
    t.bigint "orgao_id", null: false
    t.bigint "banca_id", null: false
    t.bigint "concurso_id", null: false
    t.bigint "area_de_formacao_id"
    t.bigint "area_de_atuacao_id"
    t.integer "ano"
    t.string "escolaridade"
    t.string "pdfs_folder_url"
    t.date "data_prova_aplicacao"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "validado_admin"
    t.string "edital_url"
    t.string "prova_url"
    t.index ["area_de_atuacao_id"], name: "index_provas_on_area_de_atuacao_id"
    t.index ["area_de_formacao_id"], name: "index_provas_on_area_de_formacao_id"
    t.index ["banca_id"], name: "index_provas_on_banca_id"
    t.index ["concurso_id"], name: "index_provas_on_concurso_id"
    t.index ["orgao_id"], name: "index_provas_on_orgao_id"
  end

  create_table "questaos", force: :cascade do |t|
    t.boolean "discursiva", null: false
    t.date "anulada"
    t.date "desatualizada"
    t.integer "ano", null: false
    t.json "alternativas"
    t.string "correta"
    t.string "enunciado", null: false
    t.string "sistema_ref_id"
    t.bigint "concurso_id"
    t.bigint "assunto_id"
    t.bigint "disciplina_id"
    t.bigint "texto_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "validado_admin"
    t.string "disciplina_ref"
    t.string "assunto_ref", default: [], array: true
    t.bigint "topico_id"
    t.index ["ano"], name: "index_questaos_on_ano"
    t.index ["anulada"], name: "index_questaos_on_anulada"
    t.index ["assunto_id"], name: "index_questaos_on_assunto_id"
    t.index ["concurso_id"], name: "index_questaos_on_concurso_id"
    t.index ["correta"], name: "index_questaos_on_correta"
    t.index ["desatualizada"], name: "index_questaos_on_desatualizada"
    t.index ["disciplina_id"], name: "index_questaos_on_disciplina_id"
    t.index ["sistema_ref_id"], name: "index_questaos_on_sistema_ref_id"
    t.index ["texto_id"], name: "index_questaos_on_texto_id"
    t.index ["topico_id"], name: "index_questaos_on_topico_id"
    t.index ["validado_admin"], name: "index_questaos_on_validado_admin"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "questao_id", null: false
    t.string "error_type", null: false
    t.text "description", null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["questao_id"], name: "index_reports_on_questao_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "resolucaos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "questao_id", null: false
    t.bigint "caderno_id"
    t.string "resposta"
    t.boolean "correta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["caderno_id"], name: "index_resolucaos_on_caderno_id"
    t.index ["questao_id"], name: "index_resolucaos_on_questao_id"
    t.index ["user_id"], name: "index_resolucaos_on_user_id"
  end

  create_table "seed_migration_data_migrations", id: :serial, force: :cascade do |t|
    t.string "version"
    t.integer "runtime"
    t.datetime "migrated_on", precision: nil
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "textos", force: :cascade do |t|
    t.string "texto", null: false
    t.bigint "prova_id", null: false
    t.bigint "concurso_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "imagem_texto"
    t.index ["concurso_id"], name: "index_textos_on_concurso_id"
    t.index ["prova_id"], name: "index_textos_on_prova_id"
  end

  create_table "topicos", force: :cascade do |t|
    t.string "nome", null: false
    t.bigint "disciplina_id"
    t.bigint "assunto_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assunto_id"], name: "index_topicos_on_assunto_id"
    t.index ["disciplina_id"], name: "index_topicos_on_disciplina_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "name"
    t.string "subscription_status"
    t.string "plan"
    t.boolean "admin", default: false
    t.string "stripe_customer_id"
    t.datetime "current_period_end"
    t.datetime "trial_ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "asaas_customer_id"
    t.string "cpf"
    t.string "cep"
    t.string "telefone"
    t.string "endereco"
    t.string "endereco_numero"
    t.string "cidade"
    t.string "estado"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.index ["asaas_customer_id"], name: "index_users_on_asaas_customer_id", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  create_table "voto_comentarios", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "comentario_id", null: false
    t.integer "valor", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comentario_id"], name: "index_voto_comentarios_on_comentario_id"
    t.index ["user_id", "comentario_id"], name: "index_voto_comentarios_on_user_id_and_comentario_id", unique: true
    t.index ["user_id"], name: "index_voto_comentarios_on_user_id"
  end

  add_foreign_key "assuntos", "disciplinas"
  add_foreign_key "cadernos", "concursos"
  add_foreign_key "cadernos", "filtros"
  add_foreign_key "cadernos", "pasta_cadernos"
  add_foreign_key "cadernos", "provas"
  add_foreign_key "cadernos", "users"
  add_foreign_key "cargo_guias", "filtros"
  add_foreign_key "comentarios", "concursos"
  add_foreign_key "comentarios", "provas"
  add_foreign_key "comentarios", "questaos"
  add_foreign_key "comentarios", "users"
  add_foreign_key "concursos", "bancas"
  add_foreign_key "concursos", "orgaos"
  add_foreign_key "exports", "concursos"
  add_foreign_key "exports", "provas"
  add_foreign_key "exports", "users"
  add_foreign_key "filtros", "users"
  add_foreign_key "guia_filtros", "cargo_guias"
  add_foreign_key "guia_filtros", "filtros"
  add_foreign_key "guia_filtros", "guias"
  add_foreign_key "guias", "concursos"
  add_foreign_key "pagamentos", "users"
  add_foreign_key "password_resets", "users"
  add_foreign_key "pasta_cadernos", "users"
  add_foreign_key "prova_questaos", "provas"
  add_foreign_key "prova_questaos", "questaos"
  add_foreign_key "provas", "area_de_atuacaos"
  add_foreign_key "provas", "area_de_formacaos"
  add_foreign_key "provas", "bancas"
  add_foreign_key "provas", "concursos"
  add_foreign_key "provas", "orgaos"
  add_foreign_key "questaos", "assuntos"
  add_foreign_key "questaos", "concursos"
  add_foreign_key "questaos", "disciplinas"
  add_foreign_key "questaos", "textos"
  add_foreign_key "questaos", "topicos"
  add_foreign_key "reports", "questaos"
  add_foreign_key "reports", "users"
  add_foreign_key "resolucaos", "cadernos"
  add_foreign_key "resolucaos", "questaos"
  add_foreign_key "resolucaos", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "textos", "concursos"
  add_foreign_key "textos", "provas"
  add_foreign_key "topicos", "assuntos"
  add_foreign_key "topicos", "disciplinas"
  add_foreign_key "voto_comentarios", "comentarios"
  add_foreign_key "voto_comentarios", "users"
end
