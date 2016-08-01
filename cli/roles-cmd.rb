module Cult
  module CLI
    module_function
    def roles_cmd
      roles = Cri::Command.define do
        name 'roles'
        summary 'A role defines how a node will act.'
      end

      roles_create = Cri::Command.define do
        name 'create'
        aliases 'new'
        summary 'creates a new role'
        usage 'create [options] NAME'

        option :i, :includes, 'this role depends on another role',
                argument: :required, multiple: true

        run do |ops, args, cmd|
          fail ArgumentError, "NAME required" if args.size != 1
          puts "create new role #{args}, parent: #{ops[:includes]}"
        end
      end
      roles.add_command roles_create
    end
  end
end
