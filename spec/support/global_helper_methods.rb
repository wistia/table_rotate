def drop_all_tables!
  TableRotate.show_tables.each do |table_name|
    ActiveRecord::Migration.drop_table(table_name)
  end
end

def create_test_models_table!
  ActiveRecord::Migration.create_table(:test_models) do |t|
    t.string :value
  end
end

def reset_tables!
  ActiveRecord::Migration.suppress_messages do
    drop_all_tables!
    create_test_models_table!
  end
end

def establish_db_connection!
  @config = YAML.load_file("#{TableRotate.root}/config/database.yml")['test']
  ActiveRecord::Base.establish_connection(@config)
end
