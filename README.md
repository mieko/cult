# Cult

## Introduction

Cult is a tool to manage fleets of servers.  It tries to work in an obvious
way, and doesn't intend on you learning a bunch of new metaphors, languages, and
terminology.

Cult may be what you're looking for if:

  * You like the transparency of shell-script setup but have outgrown it, and
    it's turning into a tangled mess
  * "Configuration Management Systems" rub you the wrong way
  * You're not worried about abstracting away Unix, as if you'll be deploying on
    a herd of Amigas next year
  * You're not looking to find a community-sourced, cloud-hosted meta-script to
    effectively `apt-get -y install nginx`
  * You have no ceremony around spinning up and killing servers.  Cult can
    manage real metal, but its default mindset is: if you fuck up too bad, you
    can spin up a fresh instance
  * When you think of a forward migration, the first thing that comes to mind is
    `#!/usr/bin/env my-favorite-language`
  * You don't get why you need more than a working SSH to configure a server,
    and why you'd need an agent running thereafter.

Cult's probably not your bourbon and ginger if:

  * You see value in "converging toward a configuration", as if you're guiding
    your precious children through the path of life, and helping them evolve
    into better people.
  * You have one big-ass old server that's been conservatively upgraded via
    efforts big enough to have a project name.  Cult can help you *out* of that,
    though.
  * You're sold on container-in-a-container-via-an-image deployment.  That's
    totally reasonable, but Cult doesn't really do anything particularly special
    to help you there.
  * You expect to have the same configuration abstractly work on a totally
    diverse set of platforms.  Cult can manage these absolutely fine, but you
    lose a lot of the benefit of its role-based sharing.
  * You've already got a working and complicated network, managed by year's
    worth of highly-tuned inputs into a Configuration Management System.  Cult
    itself does less for you, but requires a lot less of you.

But, what you gain via Cult is transparency, repeatability, and obviousness.


## Installation

Cult requires nothing to be installed on each node, other than working SSH with
public key authorization.  Things like [cloud-init][1] are perfectly capable of
getting you a blank slate with a root account, setup with an SSH key, and many
VPS providers have it ready to go.

If you're betting on Cult, you'll do *only* that in cloud-init, and let Cult's
bootstrap role handle the rest.

Cult is written in Ruby and available as a gem,  but it is an application, not a
library.  It's not written in Rails.

    $ gem install cult

Even though you aren't required to use them, it includes the terminal-mode GUI
packages (`$ cult ui`).  Because it's 2016, and we're not worried about a few
MB of extra packages hanging around anymore.

## Usage

TODO

## Development

TODO

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mieko/cult.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


[1]: https://cloudinit.readthedocs.io/en/latest/ "cloud-init"
