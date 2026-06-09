class UpdatePlanVariables < SeedMigration::Migration
  def up
    planos_data = {
      'Free' => [
        'limit_resolutions_free:20',
        'anki_export_by_week_free:1',
        'create_notebook_free:false'
      ],
      'Basic' => [
        'create_notebook_basic:true',
        'show_stats_table_by_assunto_basic:true'
      ],
      'Advanced' => [
        'excel_stats_export_advanced:true',
        'ankis_personalized_advanced:true',
        'ia_concept_question_extraction_advanced:true',
        'edital_verticalized_advanced:true',
        'show_stats_table_by_assunto_basic:true'
      ]
    }

    planos_data.each do |nome, vars|
      plano = Plano.find_by(nome_do_plano: nome)
      if plano
        # Merge or overwrite? The request implies setting these values.
        # Since variaveis is an array of strings, we'll ensure these specific ones are present.
        # But for a seed, replacing might be cleaner if we want to reset to these specific values.
        plano.update!(variaveis: vars)
      end
    end
  end

  def down
    Plano.update_all(variaveis: [])
  end
end
