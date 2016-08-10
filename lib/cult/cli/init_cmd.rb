require 'cult/skel'
require 'cult/project'
require 'cult/vps/all'

module Cult
  module CLI
    module_function
    def init_cmd
      Cri::Command.define do
        providers = Cult::VPS.providers.map { |p| p.provider_name }.join ', '

        name        'init'
        usage       'init DIRECTORY'
        summary     'Create a new Cult project'
        description <<~EOD.gsub(/(\S)\n(\S)/m, '\1 \2')
          Generates a new Cult project, based on a project skeleton.

          The most useful option is --provider, which will make sure the
          dependencies for interacting with your VPS provider are installed.
          It'll also walk you through any initial setup specific to the
          provider, like obtaining an API key, etc.

          The default provider is "scripts", which isn't too pleasant, but has
          no dependencies.  "scripts" manage your fleet by executing scripts in
          $CULT_PROJECT/scripts, which you have to implement.  This is tedious,
          but very doable.  However, if Cult knows about your provider, it can
          handle all of this without you having to do anything.

          Cult knows about the following providers:

            > #{providers}

          The init process just gets you started, and it's nothing that couldn't
          be accomplished by hand, so if you want to change anything later, it's
          not a big deal.

          The project generated sets up a pretty common configuration: an 'all'
          role, a 'bootstrap' role, and a demo task that puts a colorful banner
          in each node's MOTD.
        EOD

        required :p, :provider, 'VPS provider'

        run do |ops, args|
          fail ArgumentError, 'DIRECTORY required' if args.size != 1

          project = Project.new(args[0])
          skel = Skel.new(project)
          skel.copy!

          vps_config = {
            adapter: ops[:provider]
          }

          ops[:provider] ||= 'scripts'
          begin
            cls = Cult::VPS.find(ops[:provider])
            provider = cls.new({})
            initial_config = provider.setup!
            vps_config.merge!(initial_config)

            File.write(project.location_of('vps/default.json'),
                       JSON.pretty_generate(vps_config))

          rescue Cult::VPS::GemNeededError => e
            print <<~EOD
              This VPS provider requires the installation of one or more gem
              dependencies:

                #{e.gems.inspect}"

              Cult can install them for you.
            EOD

            next unless Cult::CLI.yes_no("Install?")

            e.gems.each do |gem|
              cmd = "gem install #{gem}"
              puts "executing: #{cmd}"
              system cmd
            end
            Gem.refresh
            retry
          end
        end
      end
    end
  end
end
