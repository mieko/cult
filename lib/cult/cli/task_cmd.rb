module Cult
  module CLI

    module_function

    def task_cmd
      task = Cri::Command.define do
        optional_project
        name 'task'
        aliases 'tasks'
        summary 'Task manipulation'
        usage 'task [command]'
        description <<~DOC.format_description
          Tasks are basically shell scripts.  Or anything with a \#! line, or
          that can be executed by name.

          Each task belongs to a Role, and the collection of Tasks in a Role,
          when ran in sequence, define what the Role does.

          For example, you could have a 'database-sever' Role, which would
          include tasks with filenames like:

            000-add-postgres-apt-repo
            001-install-postgres
            002-create-roles
            003-update-hba
            004-install-tls-cert
            005-start-postgres

          All of these Tasks would be run in sequence to define what you
          consider a `database-server` should look like.  Note that a task's
          sequence is defined by a leading number, and `task resequence` will
          neatly line these up for you.
        DOC

        run(arguments: none) do |_opts, _args, cmd|
          puts cmd.help
          exit
        end
      end

      task_resequence = Cri::Command.define do
        name 'resequence'
        aliases 'reserial'
        summary 'Resequences task serial numbers'

        flag :A, :all, 'Re-sequence all roles'
        flag :G, :'git-add', '`git add` each change'
        required :r, :role, 'Resequence only /NODE+/ (multiple)', multiple: true

        description <<~DOC.format_description
          Resequences the serial numbers in each task provided with --roles,
          or all roles with --all.  You cannot supply both --all and specify
          --roles.

          A resequence isn't something to do lightly once you have deployed
          nodes.  This will be elaborated on in the future.  It's probably
          a good idea to do this in a development branch and test out the
          results.

          The --git-add option will execute `git add` for each rename made.
          This will make your status contain a bunch of neat renames, instead of
          a lot of deleted and untracked files.

          This command respects the global --yes flag.
        DOC

        run(arguments: none) do |opts, _args, _cmd|
          if opts[:all] && !Array(opts[:role]).empty?
            fail CLIError, "can't supply -A and also a list of roles"
          end

          roles = if opts[:all]
            Cult.project.roles
          elsif opts[:role]
            CLI.fetch_items(opts[:role], from: Role)
          else
            fail CLIError, "no roles specified with --role or --all"
          end

          roles.each do |role|
            puts "Resequencing role: `#{role.name}'"
            tasks = role.build_tasks.sort_by do |task|
              # This makes sure we don't change order for duplicate serials
              [task.serial, task.name]
            end

            renames = tasks.map.with_index do |task, i|
              if task.serial != i
                new_task = Task.from_serial_and_name(role, serial: i, name: task.name)
                [task, new_task]
              end
            end.compact.to_h

            next if renames.empty?

            unless Cult::CLI.yes?
              renames.each do |src, dst|
                puts "rename #{Cult.project.relative_path(src.path)} " \
                     "-> #{Cult.project.relative_path(dst.path)}"
              end
            end

            if Cult::CLI.yes_no?("Execute renames?")
              renames.each do |src, dst|
                FileUtils.mv(src.path, dst.path)
                if opts[:'git-add']
                  %x(git add #{src.path}; git add #{dst.path})
                end
              end
            end
          end
        end
      end
      task.add_command(task_resequence)

      task_sanity = Cri::Command.define do
        name 'sanity'
        summary 'checks task files for numbering sanity'
        description <<~DOC.format_description
          TODO: Document (and do something!)
        DOC

        run do |_opts, _args, _cmd|
          puts 'checking sanity...'
        end
      end
      task.add_command task_sanity

      task_new = Cri::Command.define do
        name 'new'
        usage 'create [options] DESCRIPTION'
        summary 'create a new task for ROLE with a proper serial'
        description <<~DOC.format_description
        DOC

        required :r, :role, '/ROLE/ for task.  defaults to "base"'
        flag :e, :edit, 'open generated task file in your $EDITOR'

        run do |opts, args, _cmd|
          english = args.join " "
          opts[:roles] ||= 'base'
          puts [english, opts[:roles], opts[:edit]].inspect
        end
      end
      task.add_command(task_new)

      task
    end
  end
end
