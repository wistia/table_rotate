module TableRotate
  class Tasks
    include Rake::DSL if defined?(Rake::DSL)
    def install_tasks
      namespace :table_rotate do
        desc 'Calls MyModel.archive! on the specified ActiveRecord class'
        task :archive, :klass do |t, args|
          klass = args[0].constantize
          klass.archive!
        end
      end
    end
  end
end

if defined?(Rake)
  TableRotate::Tasks.new.install_tasks
end
