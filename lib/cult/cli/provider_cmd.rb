require 'cult/drivers/load'

module Cult
  module CLI

    module_function
    def provider_cmd
      provider = Cri::Command.define do
        optional_project
        name        'provider'
        aliases     'providers'
        summary     'Provider Commands'
        description <<~EOD
          A provider is a VPS service.  Cult ships with drivers for quite a few
          services, (which can be listed with `cult provider drivers`).

          The commands here actually set up your environment with provider
          accounts.  Regarding terminology:

          A "driver" is an interface to a third party service you probably pay
          for, for example, "mikes-kvm-warehouse" would be a driver that knows
          how to interact with the commercial VPS provider "Mike's KVM
          Warehouse".

          A "provider" is a configured account on a service, which uses a
          driver to get things done.  For example "Bob's Account at Mike's
          KVM Warehouse".

          In a lot the common case, you'll be using one provider, which is using
          a driver of the same name.
        EOD

        arguments 0
        run do |opts, args, cmd|
          puts cmd.help
          exit 0;
        end
      end

      provider_list = Cri::Command.define do
        name        'list'
        summary     'List Providers'
        description <<~EOD
          Lists Providers for this project.  If --driver is specified, it only
          lists Providers which employ that driver.
        EOD
        required :d, :driver, "Restrict list to providers using DRIVER"

        arguments 0..1
        run do |opts, args, cmd|
          providers = Cult.project.providers

          # Filtering
          providers = providers.all(args[0]) if args[0]

          if opts[:driver]
            driver_cls = Cult.project.drivers[opts[:driver]]
            providers = providers.select do |p|
              p.driver.is_a?(driver_cls)
            end
          end

          providers.each do |p|
            printf "%-20s %-s\n", p.name, Cult.project.relative_path(p.path)
          end

        end
      end
      provider.add_command(provider_list)

      provider_avail = Cri::Command.define do
        optional_project
        name       'drivers'
        summary    'list available drivers'
        description <<~EOD
          Displays a list of all available drivers, by their name, and list of
          gem dependencies.
        EOD

        arguments 0
        run do |opts, args, cmd|
          Cult::Drivers.all.each do |p|
            printf "%-20s %-s\n", p.driver_name, p.required_gems
          end
        end
      end
      provider.add_command(provider_avail)

      provider_create = Cri::Command.define do
        name        'create'
        usage       'create NAME'
        summary     'creates a new provider for your project'
        required    :d, :driver, 'Specify driver, if different than NAME'
        description <<~EOD
          Creates a new provider for the project.  There are a few ways this
          can be specified, for example

            cult provider create mikes-kvm-warehouse

          Will set up a provider account using 'mikes-kvm-warehouse' as both
          the driver type and the local provider name.

          If you need the two to be separate, for example, if you have multiple
          accounts at Mike's KVM Warehouse, you can specify a driver name with
          --driver, and an independent provider name.
        EOD

        arguments 1
        run do |opts, args, cmd|
          name, _ = *args
          driver = CLI.fetch_item(opts[:driver] || name, from: Driver)
          name = CLI.fetch_item(name, from: Provider, exist: false)

          puts [driver, name].inspect
        end
      end
      provider.add_command(provider_create)

      provider
    end
  end
end
