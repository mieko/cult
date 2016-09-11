![Cult][logo]
# Cult


## Introduction

Cult is a tool to manage fleets of servers. It tries to work in an obvious
way, and doesn't intend on you learning a bunch of new metaphors, languages,
and terminology.

Cult may be what you're looking for if:

  * You like the transparency of shell-script setup but have outgrown it, and
    it's turning into a tangled mess.  You can create a more structured tangled
    mess with Cult.
  * "Configuration Management Systems" and "Known Configuration State" stuff
    rubs you the wrong way.
  * You're not worried about abstracting away Unix, as if you'll be deploying
    on a herd of Amigas next year.
  * You're not looking to find a cloud-hosted meta-script to effectively
    `apt-get -y install nginx`.
  * You have no ceremony around spinning up and killing servers. Cult can
    manage real metal, but its default mindset is: if you fuck up too bad, you
    can spin up a fresh instance.
  * When you think of a forward migration, the first thing that comes to mind
    is `#!...`
  * You don't get why you need more than a working SSH to configure a server,
    and why you'd want an agent running thereafter.
  * It doesn't creep you out that Cult can look at your git branch name to
    decide if you're in production or development mode. There are some
    conventions going on.


Cult's probably not your bourbon and ginger if:

  * You see value in "converging toward a configuration", as if you're guiding
    your precious children through the path of life, and helping them evolve
    into better servers.
  * You have one big-ass old server that's gets conservatively upgraded via
    efforts big enough to have a project name. Cult can help you *out* of
    that, though.  Maybe.
  * You're sold on image-in-a-container-in-a-KVM deployment. That's totally
    reasonable, but Cult doesn't really do anything particularly special
    to help you if you're happy with the process you have building images.
  * You expect to have the same configuration abstractly work on a totally
    diverse set of platforms (e.g., one "formula" that works on Ubuntu,
    FreeBSD, and SCO OpenServer 5). Cult can manage these absolutely fine, but
    you lose a lot of the benefit of its role-based sharing, and will find
    yourself in the script-equivalent of `#ifdef`-hell.
  * You've already got a working and complicated network, managed by years
    worth of highly-tuned inputs into a Configuration Management System. Cult
    itself does less for you, but requires a lot less of you.

But, what you gain via Cult is transparency, repeatability, and obviousness.  
Hopefully.


## Installation

Cult is written in Ruby and available as a gem, but it is an application, not a
library. It's not written in, and has no relation to Rails. It depends on
Ruby 2.3 or greater. If you've got Ruby installed, via any means, the following
command should handle everything:

    $ gem install cult

Most provider drivers require outside gems, for example, the Linode driver
requires the Linode API gem, the DigitalOcean driver requires DropletKit,
etc. Cult will ask, and then install these required gems only when you go to
use the driver.

Cult requires nothing to be installed on each node, other than an operating SSH
server and Bourne Shell. If you know you've got Bash on the other end, feel
free to write your tasks in Bash. If you want to write tasks in Ruby, Python,
Node or Perl, etc, one of your firsts Tasks in the `all` or `bootstrap` role
should be to `apt-get -y install {ruby,python,node}`. All subsequent tasks will
have that interpreter available.


## General Theory

I think a reasonable level of abstraction for cloud deployments is such:

  1. *Nodes*: Actual machines, virtual or otherwise, running somewhere.
  2. *Roles*: The purpose of a node. e.g., `web-frontend`, `db-master`, or
     `redis-server`.
  3. *Tasks*: Roles are made of tasks, which are basically scripts, called
     things like `install-postgres` or `configure-nginx`. They're written in
     your language of choice. When you being up a Node with a Role, all of the
     Role's tasks are executed to get it up and running.
  4. *Providers*: Your VPS provider, e.g., Linode, DigitalOcean, etc. These
     allow you to spawn and destroy nodes, and typically charge you a few cents
     per node per hour. I guess there's also *Drivers*, but a Provider is
     really just an instance of a *Driver* with an API key configured.

We hate adding anything on top of this because it increases complexity.

Sometimes, what you need is not baked into Cult. So Cult is full of escape
hatches like ERB templating on shell scripts and JSON files to do weird stuff.


### Drivers

Cult provides a handful of Drivers which can talk to common VPS providers,
initially DigitalOcean, Linode, and Vultr. A driver is typically 200-300 lines
of Ruby code, and is pretty well isolated from the rest of Cult, so feel free
to open a PR to add your provider of choice. You can get a current list with:

    $ cult provider drivers

The goal of a driver is to talk to your VPS provider, start a server with a
size/instance type, zone/region, distribution, and ssh key you provide. It
then makes sure it's configured to allow a root login with that SSH key.

The Driver gets you to a "pre-bootstrap" stage where your server exists and
you can connect to it. The `bootstrap` role can then kick in. Your `boostrap`
role will typically create the `cult` user, disable the root account, etc (the
default bootstrap role indeed does exactly this.)


### Nodes

A node is a physical instance running somewhere. A node has a name, like
'web1', but also has a full description, that looks something like:

  web1@ubuntu-16-01.2gb:digitalocean.nyc1

A node named `web1` is an idea, but hasn't spawned. A node named with its full
description should represent a real server somewhere, that is (hopefully)
running.


### Roles
A role is a collection of files (usually configuration files), Tasks (usually
shell scripts), and a configuration (`role.json`). A role can include other
roles via `includes:`.

A Role's tasks are named like `000-a-descriptive-name`, because the only
ordering Cult does is asciibetical.  Tasks named numerically are considered
build tasks.  A Task named "sync" is built, shipped, and executed during
`cult fleet sync`.  Other files are ignored, so you can symlink or whatever
between them (if you want some sort of meta-role or something.)

Every task, file, and even `role.json` is pre-processed with ERB before it gets
processed by Cult or shipped to a node. This lets you customize behavior based
on the node, the role, the provider, the project, /dev/urandom, or anything
else you'd like.


#### Special Roles
There are two Roles generated by default that you should think of as
special-ish:

  1. `all`: If a Role does not explicitly list an `includes` value, Cult will
     act as if it specified `includes: ['all']`. In practice, this means tasks
     in the `all` role are common to all nodes that haven't explicitly opted
     out of it. A task can opt-out of including `all` with an explicit
     `includes: []`.
  2. `bootstrap`: The generator creates this role to be the first one ran on a
     new node. Before it starts, we have a root account with an SSH key, when
     `bootstrap` finishes, we have a `cult` user on the node with `sudo` access
     who uses the same SSH key, and the root account is disabled. `bootstrap`
     opts-out of `all`. The generator also installs a MOTD banner so you'll
     know Cult was enabled on the server, has a demo script that sets the
     hostname.


## Usage

We're going to put together a complete usage guide, tutorial, and example repo
once Cult has settled down a bit. It's still pre-1.0 software, and we still
like breaking things to make it work better for us.


### Spooky Secrets

  * `cult console` is built to be really nice to use. If you're not afraid of
    Ruby, the method names are chosen to read almost like pseudo-code. It
    supports IRB, Pry, and Ripl with command-line flags.
  * Anything that Cult keeps "an Array of", that you'd maybe want to reference
    by name is stored in a NamedArray, which shares some features with a Hash.
    This is for convenience. For example, in `cult console`, you can find the
    first driver with `drivers[0]`, find it by name with `drivers['linode']`,
    or (*get ready for fancy stuff:*) look it up by a Regexp with
    `drivers[/ocean/i]`.
  * Check this out on the console:
    `nodes[/^dev/].with(role: /httpd/).with(something: /else/)`
  * The NamedArray stuff even works on the command-line with String arguments,
    and will convert strings that start with '/' to Regexps to search by name.
  * Although Cult will only *generate* JSON, not having comments and other
    stuff is a pain. If you don't care about JSON-readability of your
    `node.json`s or `role.json`s, you can just rename it to `node.yaml` or
    `node.yml` and it'll get parsed with a YAML parser. Cult keeps transient
    state in separate files for this reason: so it doesn't overwrite your
    long-lived YAML replacements with JSON equivalents.


## Development

### History

Cult was developed to basically avoid Puppet, Chef, and Ansible. I know there
are some really large, successful deployments of all of these. I just think
they just do too much for me to feel safe with when shit goes crazy.

Some of the things Cult doesn't do are things we haven't had time to implement,
like fully building out 'cult ui'. A lot of the things Cult doesn't do are
the reason Cult exists. Some of the limitations are designed to force a
certain mindset I think is healthy for building resilient systems. In
particular:

  1. Exercising the server bring-up process from bottom-up as the normal mode
     of operation. This is why Cult makes you bring up a node from provision/
     bootstrap each time, instead of using snapshots, a feature virtually every
     VPS provider supports.  (The snapshot thing is looking pretty tempting,
     though.)
  2. Making it less reasonable to have nodes hanging around that have ended up
     in their current state via baby-step migrations for too long. Cult does
     this fine, but makes it easier to just test a new node with a clean build.
     This way you're not worried about idempotent transforms, or a lot of
     conditional logic. If a node is not where you want, bring up another that
     is, and kill the old one.

We can be convinced otherwise, but these sort of feel like the core tenets of
what Cult is about.

Cult began and reached a useful state in a burst of exploratory hacking.  It
accidentally turned out really useful for us.  It wasn't written with tests in
lockstep. We'd love to have tests, but with our devel-branch style division, it
hasn't been a priority yet (with other fires to put out.)  There wasn't, and
probably won't be perfectly bisect-able single-feature commits.  This may make
you feel a bit antsy.  Think of it more as jazz improv than an orchestra.


### Contributing

We greatly appreciate bug reports, pull-requests, questions, and general
commentary in the GitHub Issues. These are all *contributions*. However,
before opening an issue demanding us to work on your feature that Cult *has to
have to be taken seriously*, note:

  *  Cult was built by meter.md nerds to make managing our infrastructure
     better. Its utility is measured by that metric. We've released the
     project because we believe in the value of open *collaboration*, not so we
     can be unpaid software contractors working on the demands of strangers on
     the internet.
  *  If your contribution consists of instructing the team how to run the
     project or interface with the community: Thanks, but we've got that
     handled.

If you're contributing code, asking a question, or reporting a bug, don't let
the above items you away.


## License

Cult is available as open source software under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

[logo]: ./doc/images/masthead@0.5x.png "Cult Logo"
