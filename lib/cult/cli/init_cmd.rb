require 'cult/skel'
require 'cult/project'
require 'cult/drivers/load'

module Cult
  module CLI
    module_function
    def init_cmd
      Cri::Command.define do
        drivers = Cult::Drivers.all.map{|d| "  > #{d.driver_name}"}.join "\n"

        optional_project

        name        'init'
        usage       'init DIRECTORY'
        summary     'Create a new Cult project'
        description <<~EOD.format_description
          Generates a new Cult project, based on a project skeleton.

          The most useful option is --provider, which specifies both a driver
          and sets up a provider of the same name.  This will make sure the
          dependencies for using the driver are install, and any bookkeeping
          required to start interacting with your VPS provider is handled.

          This usually involves entering an account name or getting an API key.

          The default provider is "script", which isn't too pleasant, but has
          no dependencies.  The "script" driver manages your fleet by executing
          scripts in $CULT_PROJECT/script, which you have to implement.  This is
          tedious, but very doable.  However, if Cult knows about your provider,
          it can handle all of this without you having to do anything.

          Cult knows about the following providers:

          #{drivers}

          The init process just gets you started, and it's nothing that couldn't
          be accomplished by hand, so if you want to change anything later, it's
          not a big deal.

          The project generated sets up a pretty common configuration: an 'all'
          role, a 'bootstrap' role, and a demo task that puts a colorful banner
          in each node's MOTD.
        EOD

        required :p, :provider, 'VPS driver/provider'
        required :d, :driver,   'Specify a driver.  Not ususally needed'

        run(arguments: 1) do |opts, args, cmd|
          project = Project.new(args[0])
          skel = Skel.new(project)
          skel.copy!

          ops[:provider] ||= 'scripts'

          provider_conf = {
            name: ops[:provider],
            driver: ops[:driver] || ops[:provider]
          }

          offer_gem_install do
            driver_cls = Cult::Drivers.find(ops[:driver])
            if driver_cls.nil?
              fail ArgumentError "#{driver_cls} isn't a driver"
            end

            driver_conf = driver_cls.setup!
            provider_conf.merge!(driver_conf)

            FileUtils.mkdir_p(project.location_of("providers"))
            dst_file = File.join("providers",
                                 Cult.project.dump_name(provider_conf[:name]))

            File.write(project.location_of(dst_file),
                       Cult.project.dump_object(vps_config))
          end
        end

      end
    end
  end
end
