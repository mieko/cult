module Cult
  module CLI
    module_function
    def task_cmd
      task = Cri::Command.define do
        name    'task'
        summary 'Task Manipulation'
        usage   'task [command]'

        run do |_, _, cmd|
          puts cmd.help;
          exit
        end
      end

      task_reserial = Cri::Command.define do
        name        'reserial'
        summary     'Does nothing useful'

        flag nil, :pointless,       'Describes the procedure'
        flag nil, :'but-automatic', 'Automates the pointlessness'

        description <<~EOD
          Cult uses a per-project global serial number scheme to make sure tasks
          run in the order they were created.  This is good for repeatability.

          But after a while, the serial numbers of tasks within the same role
          will be all over the place.  If everything is running smoothly, you
          can group these back together with the 'reserial' command.

          One thing to note: there are no technical reasons to reserial, it's
          just for aesthetics.  There's also a real chance you can get into a
          mess if the process isn't coordinated properly.  But people still
          defrag filesystems, so...: Use the following guidelines for the best
          chance of not shooting yourself in the foot.

            1. Make sure your entire fleet is up-to-date and running smoothly.
               Particularly, they should all report the same version, and
               that version should be the same as the current serial.  So
               compare the output of these:

                 cult node version -A
                 cult task version

               If there are nodes that are not up-to-date, the next time they
               try to increase their version, from, e.g., 47 to 48, 48 will not
               be the thing it thought it was, and there's really no way to fix
               this problem.

            2. Yell down the hall to your colleagues: "I'm about to reserial,
               no one change anything today.  It's important that the numbers
               look in-order to me".

            3. Lock all the nodes for changes, so someone who is trying to get
               real work done will be thwarted by your needless reserial,
               something like:

                 cult node lock -A -m "wasting-time-reserialing"

            4. Create a new development branch of your project, something like:
               `git checkout -b dev-reserial`

            5. Execute 'cult task reserial --pointless'.  It will not execute
               without the --pointless flag.  There is no short option.

            6. Consider switching back to `master' and deleting the
               `dev-reserial' branch.

            7. Spawn all of your nodes in development mode.  If your current
               git branch contains with '\\bdev\\b', you'll automatically be in
               development mode.  Make sure all nodes come up fully.

            8. Well, I guess at this point you may as well switch back to master
               and merge env-dev-reserial.

            9. Unlock the fleet: `cult node unlock -A "wasting-time-reserialing"

           10. Run `cult fleet push-index --force'.  That will update each
               node's version of history of how it got to where it is, which is
               effectively outright lying.  Notice how most Cult commands are
               really simple and friendly, and this one looks like a git
               command, circa 2006.

           11. Commit your changes and push, and TELL EVERYONE THAT THEY MUST
               PULL MASTER AGAIN BEFORE EVER EVER TOUCHING ANYTHING TO DO WITH
               CULT.  If someone has an old copy of the repo and does any
               operations, even years from now, you'll be fucked, and there will
               be no way to fix it.

           12. Realize something didn't go correctly, and your roles were more
               intertwined than you thought.  Create a thread on HN describing
               how Cult is too complicated to use, and something as simple but
               important as making sure numbers are in order totally caused you
               three days of downtime, lost user data, and made your investors
               pull out.

           13. Hear that that `cult task reserial --pointless --but-automatic`
               will do all of these steps for you next time, not including
               communication with other users, but including the HN thread.  But
               now you've learned what it entails.

           14. You're done, but you still have an uneasy feeling about it.

          Really, you'll get over the out-of-sequence serials.  It's about as
          important as when you moved from Subversion, with its nice revision
          numbers to git's SHAs.  Or when Rails added entire timestamps to
          migration filenames.  The cause and result of a bad reserial process
          is similar to rebasing a widely-used published git branch, but it's
          MUCH harder to fix.
        EOD

        run do |opts, args, cmd|
          unless opts[:pointless]
            $stderr.puts "#{$0}: was not described with --pointless"
            exit 1
          end
        end
      end
      task.add_command(task_reserial)

      task_sanity = Cri::Command.define do
        name        'sanity'
        summary     'checks task files for numbering sanity'
        description <<~EOD
        EOD

        run do |args, ops, cmd|
          puts 'checking sanity...'
        end
      end
      task.add_command task_sanity

      task_create = Cri::Command.define do
        name        'create'
        aliases     'new'
        usage       'create [options] DESCRIPTION'
        summary     'create a new task for ROLE with a proper serial'
        description <<~EOD
        EOD

        required :r, :role, 'role for task.  defaults to "all"'
        flag :e, :edit, 'open generated task file in your $EDITOR'

        run do |opts, args, cmd|
          english = args.join " "
          opts[:roles] ||= 'all'
          puts [english, opts[:roles], opts[:edit]].inspect
        end
      end
      task.add_command task_create

      task
    end
  end
end
