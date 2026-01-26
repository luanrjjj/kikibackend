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

ActiveRecord::Schema[8.0].define(version: 2026_01_15_023014) do
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
    t.index ["banca_id"], name: "index_concursos_on_banca_id"
    t.index ["orgao_id"], name: "index_concursos_on_orgao_id"
  end

  create_table "disciplinas", force: :cascade do |t|
    t.string "nome", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orgaos", force: :cascade do |t|
    t.string "nome", null: false
    t.string "sede"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_de_atuacao_id"], name: "index_provas_on_area_de_atuacao_id"
    t.index ["area_de_formacao_id"], name: "index_provas_on_area_de_formacao_id"
    t.index ["banca_id"], name: "index_provas_on_banca_id"
    t.index ["concurso_id"], name: "index_provas_on_concurso_id"
    t.index ["orgao_id"], name: "index_provas_on_orgao_id"
  end

  create_table "questaos", force: :cascade do |t|
    t.text "texto"
    t.boolean "discursiva", null: false
    t.date "anulada"
    t.date "desatualizada"
    t.integer "ano", null: false
    t.json "alternativas"
    t.string "correta"
    t.string "enunciado", null: false
    t.bigint "prova_id", null: false
    t.bigint "concurso_id"
    t.bigint "assunto_id"
    t.bigint "disciplina_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assunto_id"], name: "index_questaos_on_assunto_id"
    t.index ["concurso_id"], name: "index_questaos_on_concurso_id"
    t.index ["disciplina_id"], name: "index_questaos_on_disciplina_id"
    t.index ["prova_id"], name: "index_questaos_on_prova_id"
  end

  create_table "seed_migration_data_migrations", id: :serial, force: :cascade do |t|
    t.string "version"
    t.integer "runtime"
    t.datetime "migrated_on", precision: nil
  end

  create_table "textos", force: :cascade do |t|
    t.string "texto", null: false
    t.bigint "prova_id", null: false
    t.bigint "concurso_id", null: false
    t.bigint "questao_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concurso_id"], name: "index_textos_on_concurso_id"
    t.index ["prova_id"], name: "index_textos_on_prova_id"
    t.index ["questao_id"], name: "index_textos_on_questao_id"
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

  add_foreign_key "assuntos", "disciplinas"
  add_foreign_key "concursos", "bancas"
  add_foreign_key "concursos", "orgaos"
  add_foreign_key "provas", "area_de_atuacaos"
  add_foreign_key "provas", "area_de_formacaos"
  add_foreign_key "provas", "bancas"
  add_foreign_key "provas", "concursos"
  add_foreign_key "provas", "orgaos"
  add_foreign_key "questaos", "assuntos"
  add_foreign_key "questaos", "concursos"
  add_foreign_key "questaos", "disciplinas"
  add_foreign_key "questaos", "provas"
  add_foreign_key "textos", "concursos"
  add_foreign_key "textos", "provas"
  add_foreign_key "textos", "questaos"
  add_foreign_key "topicos", "assuntos"
  add_foreign_key "topicos", "disciplinas"
end
