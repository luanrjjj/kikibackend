class AddResolutionLimitConfig < SeedMigration::Migration
  def up
    unless ConfigGlobalApolo.find_by(nome_da_variavel: 'limit_resolutions_free')
      ConfigGlobalApolo.set('limit_resolutions_free', '20')
    end
  end

  def down
    ConfigGlobalApolo.find_by(nome_da_variavel: 'limit_resolutions_free')&.destroy
  end
end
