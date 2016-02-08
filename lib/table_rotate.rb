require 'active_support'

module TableRotate
  extend ActiveSupport::Concern


  # tra = table rotate archive
  ARCHIVE_TABLE_SUFFIX = 'tra'


  def self.root
    File.dirname(__dir__)
  end


  def self.hi
    puts 'hello'
  end


  def self.show_tables
    ActiveRecord::Base.connection.select_values('show tables')
  end


  def self.sql_exec(s)
    ActiveRecord::Base.connection.execute(s)
  end


  def self.timestamp_from_table_name(table_name)
    timestamp = table_name.split('_').last
    if timestamp.match(/\A\d+\z/)
      timestamp
    else
      raise "No valid timestamp for #{table_name}. Expected _\d+ at end."
    end
  end


  def self.in_test?
    true
  end


  def self.rotate_active_table!(table_name)
    timestamp = Time.now.to_i
    archived_table_name = "#{table_name}_#{ARCHIVE_TABLE_SUFFIX}_#{timestamp}"
    tmp_new_table_name = "#{table_name}_tra_new"

    if TableRotate.show_tables.include?(archived_table_name)
      raise "#{archived_table_name} already exists. Aborting rotation of #{table_name} table."
    else
      puts 'Archiving active table and replacing with new one...' unless in_test?
      TableRotate.sql_exec("CREATE TABLE #{tmp_new_table_name} like #{table_name}")
      TableRotate.sql_exec("RENAME TABLE #{table_name} TO #{archived_table_name}, #{tmp_new_table_name} TO #{table_name}")
      puts 'Done!' unless in_test?
    end
  end


  # Get the archive tables given this base table name.
  def self.archive_table_names(table_name)
    TableRotate.
      show_tables.
      select{|t| t.match(/^#{table_name}_#{ARCHIVE_TABLE_SUFFIX}_\d+$/)}.
      sort.reverse
  end


  def self.prune_archives(klass)
  end


  # XXX
  def self.clear_archived_table_before!(table_name, date)
    archive_table_names(table_name).each do |t|
      # Dropping tables is dangerous. Bomb if anything doesn't look right.
      if !t || t == table_name || !t.match(/^#{table_name}_#{ARCHIVE_TABLE_SUFFIX}_\d+$/)
        raise "Attempted to archive invalid table #{t}!"
      end

      archived_str = t.match(/^#{table_name}_#{ARCHIVE_TABLE_SUFFIX}_(\d+)$/)[1]
      archived_at = Date.strptime(archived_str, '%Y%m%d').to_time
      if date == 'endoftime' || archived_at < date
        puts "Dropping table #{t}..." unless in_test?
        TableRotate.sql_exec("DROP TABLE #{t}")
        ActiveRecord::Base.connection.schema_cache.clear_table_cache!(t)
        puts 'Done!' unless in_test?
      end
    end
  end


  # Since we're dynamically creating classes and accessing tables, we need to
  # call this whenever a new table is created or deleted. Otherwise it doesn't
  # get updated properly.
  def self.refresh_table_cache(ar_class)
    ActiveRecord::Base.connection.schema_cache.clear_table_cache!(ar_class.table_name)
    ar_class.reset_column_information
  end


  included do
    def self.archive!
      TableRotate.rotate_active_table!(table_name)
      # TableRotate.clear_archived_table_before!(table_name, archive_table_ttl_in_days.days.ago)
    end


    def self.with_archives(count = -1)
      ([self] + archives(count)).map do |klass|
        yield klass
      end
    end


    def self.archives(count = nil)
      all_tables = TableRotate.archive_table_names(table_name)
      count ||= all_tables.count
      all_tables[0...count].map do |table_name|
        ts = TableRotate.timestamp_from_table_name(table_name)
        archive_class(ts)
      end
    end


    def self.archive_table_ttl_in_days
      3
    end


    # There is no good way to set table_name on a per-query basis with
    # ActiveRecord. So instead, we dynamically generate a subclass
    # with a fixed table name.
    #
    # This returns a sub-class that will operate on an archived table for a
    # specific day, e.g. ActiveRecordClassName20141110.
    def self.archive_class(timestamp)
      klass_name = "#{name}#{timestamp}"

      if Object.const_defined?(klass_name)
        konstant = klass_name.constantize
        unless konstant.table_exists?
          # konstant.table_exists? will always return false until we restart
          # the app unless we manually call this.
          TableRotate.refresh_table_cache(konstant)
        end
      else
        class_eval <<-eos
          class ::#{name}#{timestamp} < #{name}
            self.table_name = '#{table_name}_#{ARCHIVE_TABLE_SUFFIX}_#{timestamp}'
          end
        eos
        konstant = klass_name.constantize
      end

      unless konstant.table_exists?
        puts "No archive exists for #{timestamp}."
        return nil
      end

      konstant
    end
  end
end
