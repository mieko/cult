# Immediate plans

## Use new features of `cri`

The `cri` gem has added a lot of features that'd make sense for Cult to use since we based the
initial work on cri 2.8.  We'll possibly be able to lose a lot of code and extensions to cri.

In particular:
  * Default subcommands
  * Default option values
  * Option transforms
  * Parameter naming, validation, transformation
  * `no_params`
  * `load_file`: we already split up our commands into files, we can utilize this

# Upgrade other dependencies

We haven't checked compatibility or started using new features from some of our dependencies

Check on:
  * `net-ssh`.  We're on 4.2, 5.0.x is current.  We may just want to find or write a 'mini-ssh'
                that drives the SSH client.  This will also avoid a new problem of a dependency
                on libsodium that no gem actually builds.
  * `net-scp`.  Currently in maintenance mode, and most recent version depends on `net-ssh < 5.0`.
                We need a solution for this.  The current version is now controlled by the
                `net-ssh` team at `net-ssh/net-scp`.  May just need a gemspec update on their
                end.  If we go the 'mini-ssh' route, it should just have a 'send_file' method.

# Overhaul gem installation stuff

I want to pull this out of cult, and release cult-provider-{whatever} packages that depend on the
proper gems, or just move to https://github.com/fog/fog.  It'll handle all the dependencies and
provides an abstraction later.

# Check compatibility with new provider gems.

I know for a fact `--zone` with Digital Ocean fails (`NoMethodError`).  We need to find out what
else has been going on in these gems in the last two years.
