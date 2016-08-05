module Cult
  module CLI
    module_function
    def role_cmd
      role = Cri::Command.define do
        name        'role'
        summary     'Manage roles'
        description <<~EOD
          A role defines what a node does.  The easiest way to think about it is
          just a directory full of scripts (tasks).

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
          You should write tasks with that in mind.  For example, dropping files
          into `/etc/your-httpd.d` instead of re-writing `/etc/your-httpd.conf`.
          With this setup, a node could include both `rat-site` and `tempo-site`
          roles and be happily serving both sites.

          By default, `cult init` generates two root roles that don't depend on
          anything else: `all` and `bootstrap`.  The `bootstrap` role exists
          to get a node from a clean OS install to a configuration to be managed
          by the settings in `all'.  Theoretically, if you're happy doing all
          deploys as the root user, you don't need a `bootstrap` role at all:
          Delete it and set the `user` key in `all/role.json` to "root".

          The tasks in the `all` role are considered shared amongst all roles.
          However, the only thing special about the `all` role is that Cult
          assumes roles and nodes without an explicit `includes` setting belong
          to all.
        EOD

        run do |_, _, cmd|
          puts cmd.help
          exit 0;
        end
      end

      role_create = Cri::Command.define do
        name        'create'
        aliases     'new'
        summary     'creates a new role'
        usage       'create [options] NAME'
        description <<~EOD
          Creates a new role names NAME, which will then be available under
          $CULT_PROJECT/roles/$NAME
        EOD

        required :i, :includes, 'this role depends on another role',
                 multiple: true

        run do |ops, args, cmd|
          fail ArgumentError, "NAME required" if args.size != 1
          puts "create new role #{args}, includes: #{ops[:includes]}"
        end
      end
      role.add_command role_create
    end
  end
end
