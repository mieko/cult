module Cult
  module CLI
    module_function
    def tasks_cmd
      tasks = Cri::Command.define do
        name 'tasks'
        summary 'Tasks are scripts which run on nodes to bring them up to date.'
        usage 'tasks [command]'

        run do |_, _, cmd|
          puts cmd.help;
          exit
        end
      end

      tasks_sanity = Cri::Command.define do
        name 'sanity'
        summary 'checks task files for numbering sanity'

        run do |args, ops, cmd|
          puts 'checking sanity...'
        end
      end
      tasks.add_command tasks_sanity

      tasks_create = Cri::Command.define do
        name 'create'
        aliases 'new'
        summary 'create a new task for ROLE with a proper serial'
        usage 'create [options] DESCRIPTION'
        option :r, :role, 'role for task.  defaults to "all"', argument: :required
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
