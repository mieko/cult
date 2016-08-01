require_relative '../skel'
require_relative '../project'

module Cult
  module CLI
    module_function
    def init_cmd
      Cri::Command.define do
        name 'init'
        summary 'Create a new cult project in DIRECTORY'
        usage 'init DIRECTORY'

        run do |ops, args|
          fail ArgumentError, "DIRECTORY required" if args.size != 1

          project = Project.new(args[0])
          skel = Skel.new(project)
          skel.copy!
        end
      end
    end
  end
end
