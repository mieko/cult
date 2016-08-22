require_relative '../ui/shell'
require_relative '../ui/role_info'

module Cult
  module CLI

    module_function
    def ui_cmd
      shell = Cult::UI::Shell.new
      ui = Cri::Command.define do
        name        'ui'
        summary     'The interactive Cult command center'
        description <<~EOD
          Cult includes a terminal-mode, but graphical user interface to access
          some of its functionality.
        EOD

        run do |opts, args, cmd|
          CLI.require_args(args, 0)
          shell.run
        end
      end

      ui_welcome = Cri::Command.define do
        name        'welcome'
        summary     'Displays the ui welcome page'

        run do |opts, args, cmd|
          CLI.require_args(args, 0)
          shell.doc('welcome')
        end
      end
      ui.add_command(ui_welcome)

      ui_panel = Cri::Command.define do
        name        'panel'
        summary     'Displays the node/role selection panel'

        run do |opts, args, cmd|
          CLI.require_args(args, 0)
          shell.panel
        end
      end
      ui.add_command(ui_panel)

      ui_node_info = Cri::Command.define do
        name        'role-info'
        summary     'Display information about a node'
        usage       'node-info NODENAME'

        run do |opts, args, cmd|
          Cult::UI::RoleInfo.new(args).run
        end
      end
      ui.add_command(ui_node_info)
      ui
    end

  end
end
