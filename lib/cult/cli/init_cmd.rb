require 'cult/drivers/load'
require 'json'

module Cult
  module CLI

    module_function
    def init_cmd
      Cri::Command.define do
        drivers = Cult::Drivers.all.map{|d| d.driver_name }.join ", "

        optional_project
        name        'init'
        aliases     'new'
        usage       'init [OPTIONS] DIRECTORY'
        summary     'Create a new Cult project'
        description <<~EOD.format_description
          Generates a new Cult project, based on a project skeleton.

          The most useful option is --driver, which both specifies a driver and
          sets up a provider of the same name.  This will make sure the
          dependencies for using the driver are install, and any bookkeeping
          required to start interacting with your VPS provider is handled.

          This usually involves entering an account name or getting an API key.

          The default provider is "script", which isn't too pleasant, but has
          no dependencies.  The "script" driver manages your fleet by executing
          scripts in $CULT_PROJECT/script, which you have to implement.  This is
          tedious, but very doable.  However, if Cult knows about your provider,
          it can handle all of this without you having to do anything.

          Cult knows about the following providers:

          > #{drivers}

          The init process just gets you started, and it's nothing that couldn't
          be accomplished by hand, so if you want to change anything later, it's
          not a big deal.

          The project generated sets up a pretty common configuration: a `base`
          role, a 'bootstrap' role, and a demo task that puts a colorful banner
          in each node's MOTD.
        EOD

        required :d, :driver,   'Driver with which to create your provider'
        required :p, :provider, 'Specify an explicit provider name'

        run(arguments: 1) do |opts, args, cmd|
          project = Project.new(args[0])
          if project.exist?
            fail CLIError, "a Cult project already exists in #{project.path}"
          end

          driver_cls = if !opts[:provider] && !opts[:driver]
            opts[:provider] ||= 'scripts'
            CLI.fetch_item(opts[:provider], from: Driver)
          elsif opts[:provider] && !opts[:driver]
            CLI.fetch_item(opts[:provider], from: Driver)
          elsif opts[:driver] && !opts[:provider]
            CLI.fetch_item(opts[:driver], from: Driver).tap do |dc|
              opts[:provider] = dc.driver_name
            end
          elsif opts[:driver]
            CLI.fetch_item(opts[:driver], from: Driver)
          end

          fail CLIError, "Hmm, no driver class" if driver_cls.nil?

          skel = Skel.new(project)
          skel.copy!

          provider_conf = {
            name: opts[:provider],
            driver: driver_cls.driver_name
          }

          CLI.offer_gem_install do
            driver_conf = driver_cls.setup!
            provider_conf.merge!(driver_conf)


            provider_dir = File.join(project.location_of("providers"),
                                     provider_conf[:name])
            FileUtils.mkdir_p(provider_dir)


            provider_file = File.join(provider_dir, "provider.json")
            File.write(provider_file, JSON.pretty_generate(provider_conf))


            defaults_file = File.join(provider_dir, "defaults.json")
            defaults = Provider.generate_defaults(provider_conf)
            File.write(defaults_file, JSON.pretty_generate(defaults))
          end

          Dir.chdir(project.path) do
            `git init .`
            `git add -A`
            `git commit -m "[Cult] Created new project"`
          end

        end

      end
    end
  end
end
