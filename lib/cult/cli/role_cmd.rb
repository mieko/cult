require 'fileutils'
require 'json'

module Cult
  module CLI
    module_function

    def role_cmd
      role = Cri::Command.define do
        optional_project
        name 'role'
        aliases 'roles'
        summary 'Manage roles'
        description <<~DOC.format_description
          A role defines what a node does.  The easiest way to think about it
          is just a directory full of scripts (tasks).

          A role can include an arbitrary number of other roles.  For example,
          you may have two roles `rat-site' and `tempo-site', which both depend
          on a common role `web-server'.  In this case, `web-server' would be
          the set of tasks that install the web server through the package
          manager, set up a base configuration, and allow ports 80 and 443
          through the firewall.

          Both `rat-site' and `tempo-site' would declare that they depend on
          `web-server' by listing it in their `includes' array in role.json.
          Their tasks would then only consist of dropping a configuration file,
          TLS keys and certificates into `/etc/your-httpd.d`.

          Composability is the mindset behind roles.  Cult assumes, by default,
          that roles are written in a way to compose well with each other if
          they find themselves on the same node.  That is not always possible,
          (thus the `conflicts' key exists in `role.json'), but is the goal.
          You should write tasks with that in mind.  For example, dropping
          files into `/etc/your-httpd.d` instead of re-writing
          `/etc/your-httpd.conf`. With this setup, a node could include both
          `rat-site` and `tempo-site` roles and be happily serving both sites.

          By default, `cult init` generates two root roles that don't depend on
          anything else: `base` and `bootstrap`.  The `bootstrap` role exists
          to get a node from a clean OS install to a configuration to be
          managed by the settings in `base'.  Theoretically, if you're happy
          doing all deploys as the root user, you don't need a `bootstrap` role
          at all: Delete it and set the `user` key in `base/role.json` to
          "root".

          The tasks in the `base` role are considered shared amongst all roles.
          However, the only thing special about the `base` role is that Cult
          assumes roles and nodes without an explicit `includes` setting belong
          to `base`.
        DOC

        run(arguments: none) do |_opts, _args, cmd|
          puts cmd.help
          exit
        end
      end

      role_new = Cri::Command.define do
        name 'new'
        summary 'creates a new role'
        usage 'create [options] NAME'
        description <<~DOC.format_description
          Creates a new role names NAME, which will then be available under
          $CULT_PROJECT/roles/$NAME
        DOC

        required :r, :roles, 'this role depends on another /ROLE+/ (multiple)',
                 multiple: true

        run(arguments: 1) do |opts, args, _cmd|
          name = CLI.fetch_item(args[0], from: Role, exist: false)

          role = Role.by_name(Cult.project, name)
          data = {}

          if opts[:roles]
            data[:includes] = CLI.fetch_items(opts[:roles],
                                              from: Role).map(&:name)
          end
          FileUtils.mkdir_p(role.path)
          File.write(role.role_file, JSON.pretty_generate(data))

          FileUtils.mkdir_p(File.join(role.path, "files"))
          File.write(File.join(role.path, "files", ".keep"), '')

          FileUtils.mkdir_p(File.join(role.path, "tasks"))
          File.write(File.join(role.path, "tasks", ".keep"), '')
        end
      end
      role.add_command(role_new)

      role_rm = Cri::Command.define do
        name 'rm'
        usage 'rm /ROLE+/ ...'
        summary 'Destroy role ROLE'
        description <<~DOC.format_description
          Destroys all roles specified.
        DOC

        run(arguments: 1..unlimited) do |_opts, args, _cmd|
          roles = args.map do |role_name|
            CLI.fetch_items(role_name, from: Role)
          end.flatten

          roles.each do |role|
            if CLI.yes_no?("Delete role #{role.name} (#{role.path})?",
                           default: :no)
              FileUtils.rm_rf(role.path)
            end
          end
        end
      end
      role.add_command(role_rm)

      role_ls = Cri::Command.define do
        name        'ls'
        usage       'ls [/ROLE+/ ...]'
        summary     'List existing roles'
        description <<~DOC.format_description
          Lists roles in this project.  By default, lists all roles.  If one or
          more ROLES are specified, only lists those
        DOC

        run(arguments: unlimited) do |_opts, args, _cmd|
          roles = Cult.project.roles
          unless args.empty?
            roles = CLI.fetch_items(*args, from: Role)
          end

          table = Terminal::Table.new(headings: ['Role', 'Build Order'])
          table.rows = roles.map do |r|
            [r.name, r.build_order.map(&:name).join(', ')]
          end
          puts table

        end
      end
      role.add_command(role_ls)

      role
    end
  end
end
