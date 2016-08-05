module Cult
  module CLI
    module_function
    def tasks_cmd
      tasks = Cri::Command.define do
        name    'tasks'
        summary 'Task Manipulation'
        usage   'tasks [command]'

        run do |_, _, cmd|
          puts cmd.help;
          exit
        end
      end

      tasks_sanity = Cri::Command.define do
        name        'sanity'
        summary     'checks task files for numbering sanity'
        description <<~EOD
        EOD

        run do |args, ops, cmd|
          puts 'checking sanity...'
        end
      end
      tasks.add_command tasks_sanity

      tasks_create = Cri::Command.define do
        name        'create'
        aliases     'new'
        usage       'create [options] DESCRIPTION'
        summary     'create a new task for ROLE with a proper serial'        
        description <<~EOD
        EOD

        required :r, :role, 'role for task.  defaults to "all"'
        flag :e, :edit, 'open generated task file in your $EDITOR'

        run do |opts, args, cmd|
          english = args.join " "
          opts[:roles] ||= 'all'
          puts [english, opts[:roles], opts[:edit]].inspect
        end
      end
      tasks.add_command tasks_create

      tasks
    end
  end
end
