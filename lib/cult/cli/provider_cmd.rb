require 'cult/vps/all'

module Cult
  module CLI

    module_function
    def provider_cmd
      provider = Cri::Command.define do
        no_project
        name        'provider'
        summary     'Provider Commands'
        description <<~EOD
        EOD

        run do |_, _, cmd|
          puts cmd.help
          exit 0;
        end
      end

      provider_avail = Cri::Command.define do
        no_project
        name       'avail'
        aliases    'available'
        summary    'list available provider adapters'
        description <<~EOD
          Displays a list of all available providers, by their name, class,
          and list of gem dependencies.
        EOD

        run do |_, _|
          fmt = "%-20s %-38s %-20s\n"
          printf(fmt, "name", "adapter", "gems")
          puts '-' * 76
          Cult::VPS.providers.each do |p|
            printf(fmt, p.provider_name, p.inspect, p.required_gems)
          end
        end
      end
      provider.add_command(provider_avail)

    end
  end
end
