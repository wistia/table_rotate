require 'active_support'

module TableRotate
  class Error < StandardError; end
  class NotEnoughTimeBetweenArchivesError < Error; end
  class InvalidTimestampError < Error; end
  class ArchiveTableAlreadyExistsError < Error; end


  extend ActiveSupport::Concern


  # tra = table rotate archive
  ARCHIVE_TABLE_SUFFIX = 'tra'
  ARCHIVE_TABLE_REGEX = /\_#{ARCHIVE_TABLE_SUFFIX}_\d+\z/


  def self.root
    File.dirname(__dir__)
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
      timestamp.to_i
    else
      raise InvalidTimestampError, "No valid timestamp for #{table_name}. Expected _\d+ at end."
    end
  end


  def self.in_test?
    true
  end


  def self.archive_table_name(base_name, timestamp)
    "#{base_name}_#{ARCHIVE_TABLE_SUFFIX}_#{timestamp}"
  end


  # Get the archive tables given this base table name.
  def self.archive_table_names(base_name)
    TableRotate.
      show_tables.
      select{ |t| t.starts_with?(base_name) && t.match(ARCHIVE_TABLE_REGEX) }.
      sort.reverse
  end


  def self.rotate_active_table!(table_name)
    archived_table_name = archive_table_name(table_name, Time.now.to_i)
    tmp_new_table_name = "#{table_name}_tra_new"

    if TableRotate.show_tables.include?(archived_table_name)
      raise ArchiveTableAlreadyExistsError, "#{archived_table_name} already exists. Aborting rotation of #{table_name} table."
    else
      puts 'Archiving active table and replacing with new one...' unless in_test?
      TableRotate.sql_exec("CREATE TABLE #{tmp_new_table_name} like #{table_name}")
      TableRotate.sql_exec("RENAME TABLE #{table_name} TO #{archived_table_name}, #{tmp_new_table_name} TO #{table_name}")
      puts 'Done!' unless in_test?
    end
  end


  def self.prune_archives!(klass)
    dropped = []

    loop do
      # archive tables are ordered by newest first. we want to drop the oldest
      # first, so we pop off the back.
      table_names = archive_table_names(klass.table_name)
      if table_names.count <= klass.max_archive_count
        break
      else
        table = table_names.last
        if sane_to_drop?(klass, table)
          TableRotate.sql_exec("DROP TABLE #{table}")
          ActiveRecord::Base.connection.schema_cache.clear_table_cache!(table)
        end
        dropped << table
      end
    end

    dropped
  end


  def self.sane_to_drop?(klass, table_name)
    table_name.starts_with?(klass.table_name) &&
      table_name.match(ARCHIVE_TABLE_REGEX)
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
      unless enough_time_since_last_archive?
        raise NotEnoughTimeBetweenArchivesError, "There must be at least #{min_time_between_archives} seconds between each archive."
      end

      TableRotate.rotate_active_table!(table_name)
      TableRotate.prune_archives!(self)
    end


    def self.enough_time_since_last_archive?
      if archive = archives(1).first
        last_archive_timestamp = TableRotate.timestamp_from_table_name(archive.table_name)
        time_since_last_archive = Time.now.to_i - last_archive_timestamp
        time_since_last_archive >= min_time_between_archives
      else
        true
      end
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


    # We'll use this to prune old tables
    def self.max_archive_count
      3
    end


    # In case `prune_archives!` gets run extra-often, this will prevent it from
    # archiving too frequently.
    def self.min_time_between_archives
      1.day
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
