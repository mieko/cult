require_relative '../ui/shell'

module Cult
  module CLI

    module_function
    def ui_cmd
      shell = Cult::UI::Shell.new
      ui = Cri::Command.define do
        name 'ui'
        summary 'Run the interactive cult command center'

        run do |_, _|
          shell.run
        end
      end

      ui_welcome = Cri::Command.define do
        name 'welcome'
        summary 'Displays the ui welcome page in less'

        run do |_, _|
          shell.doc('welcome')
        end
      end
      ui.add_command(ui_welcome)

      ui_panel = Cri::Command.define do
        name 'panel'
        summary 'Displays the node selection panel'

        run do |_,_|
          shell.panel
        end
      end
      ui.add_command(ui_panel)

      ui
    end

  end
end
