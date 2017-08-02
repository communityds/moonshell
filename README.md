# Moonshell

[![Build Status](https://travis-ci.org/communityds/moonshell.svg?branch=master)](https://travis-ci.org/communityds/moonshell)

This project is based upon [BashEnv](https://github.com/pingram3030/bashenv)
which is a dynamic bash environment management solution. TL;DR; It's a
framework you can use to create custom functions and modifications to Bash to
do what ever you please.

The focus of this project is to make AWS CF stacks simple and easy for an
administrator to use from the CLI.

Influential axioms:

1. Clean code is good code

1. Make peoples lives better and easier

1. Do unto others as you would have done unto yourself

Contents:

1. [Overview](#overview)

1. [Usage](#usage)

1. [Structure](#structure)

1. [Why](#why)

1. [How](#how)

## Overview

Everything starts with `./moon.sh`. When sourced it:

1. Sets core `ENV_` variables.

1. Checks itself for whether its installed and installs itself if not.

1. Adds itself to `PATH`.

1. Sources `*.sh` files from `lib`, `profile.d` and `completion.d`.

1. Handles being sourced from Bash or a script.

## Usage

### Setup

To both setup and use Moonshell, simply source `moon.sh`, this library will
take care of self installation.

```
source moon.sh
```

### Admin

The `_moonshell` function enables basic admin functionality for Moonshell. You
can tab complete its options for more info.

```
[user@host ~]$ _moonshell -<tab><tab>
-h       --help   -r       --reset  -s       --setup  -t       --test
[user@host ~]$ _moonshell --help
Usage: _moonshell [-h|--help] [-r|--reset] [-s|--setup]
Perform basic functions for Moonshell.

    -h, --help      show this help and exit
    -r, --reset     remove all var files and regenerate self
    -s, --setup     install self in to the shell of user: 'user'
    -t, --test      run bashate, rubocop and markdownlint
```

### Overlaying

Moonshell contains common functions and features that we need across all of our
products, but each product has differences; requires different tools, different
variables etc. The solution is to overlay customisations.

Per the structure below, Moonshell uses the FHS standard dirs of `bin`, `lib`,
`var`, `etc`, etc. If, in your repo checkout of `${HOME}/dev/repo`, you have a
`bin` and `lib` directory, you can simply:

`_moonshell_overlay_dir ${HOME}/dev/repo`

This will automatically create an entry in `etc/profile.d/private/overlay.sh`,
so every time you spawn a shell your repo dir is automatically layed atop of
Moonshell. `bin/` will be prepended to `${PATH}` and every .sh file in `lib/`
will be sourced. Identically named scripts in `${ENV_BIN}` and functions in
`${ENV_LIB}` will replace the default in Moonshell.

## Structure

Moonshell tries to adhere to Linux FHS best practice:

* bin/ - Executable scripts sans type suffix; foo, not foo.sh

* lib/ - Non-executable function libraries with suffix; foo.rb, foo.sh etc.

* etc/

        * completion.d/ - Bash completion functions suffixed with `.sh`

        * profile.d/ - Definitions of variables and other statically set things

* usr/ - Extra supporting files for applications

* var/ - Location for any temp or state files, everything here is ephemeral

## Why

A lot of the functionality herein should ideally be ported to Moonshot, but, at
the time of writing these tools, using Ruby to develop solutions to our needs
is an expense we can't afford. We are working through the process of developing
out several systems that all interract with each other on some level; the scope
and functionality is being found out as development happens.

Bash was the quickest and easiest way to create re-usable code that runs on all
systems regardless of all external dependencies, with exception of `aws-cli`,
and that can be easily extended. Only some rules need to be adhered to for
stack creation, naming of resources and outputs.

The last, and arguably most important, reason is that I am a systems
administrator. I use the CLI for pretty much all important operations in my day
to day work. I need the CLI to be quick, easy and extensible. Having a sorted
admin environment even makes developing out new things easier because you have
all the tools to introspect and do basic tasks at your fingertips.

In the future scripts may be written in Python, or Ruby, but until then Bash
is where it's at.

### No, Really, Why Bash

[Google Shell Style Guide](https://google.github.io/styleguide/shell.xml?showone=File_Extensions#File_Extensions)

* Bash is on everything.
* Bash doesn't require installation and updating of vendor modules.
* Bash is really good at getting things from A to B with a bit of simple
  manipulation in between.
* Nothing in this repo requires associative arrays, so there is less of a need
  for a higher level language.
* Bash functions and scripts integrate really well with the Bash cli.
* There are fewer bugs caused by edge cases found in higher level languages.
* I <3 Bash :D

## How

When building out stacks thought must be given to the names of resources. It is
advised to always use generic names for resources to enable future portability
of templates and/or other code.

It is highly recommended to create an internal Route53 hosted zone so that you
can easily connect to your instances and reference resources by short easy to
remember common hostnames; i.e. "ping app" or "mysql -h rds". Route53 is used
heavily by Moonshell as a means to find information such as an instance to
ssh to, or gather information from. It is also pivotal in creating VPC peering
connections to grant access to resources in one VPC from another. DNS is a
solved problem; use it!

* NOTE: You must delete all but the base records in the hosted zone before
  stack deletion. Failure to do so will result in a failure to delete the stack
  because AWS doesn't provide a way to forcibly delete entries when a zone is
  to be deleted, thanks AWS.. This is a similar problem to versioned S3
  buckets; you must delete all versions of all files before you can delete the
  bucket.

We run a shared centralised `core` VPC that contains a jump host, logging and
email services. All peered VPCs use the central logger and are accessed by the
central jump host. Moonshell expects this vpc be named `core`

### Stack Outputs

These outputs are required to be set:

* `ExternalRoute53HostedZoneName`: To keep track of stacks, and any sites that
  point to stack, a CNAME is created for the stack's name.

  i.e. `app_name-environment.dev.example.com` -> `my-varnish-elb-1g{...}elb.amazonaws.com.`

  This enables you to CNAME other records more easily to your stack, which
  makes administration more pleasant and easier for others to diagnose issues:

  i.e. `foo.example.com` -> `app_name-environment.dev.example.com`

  Plus, getting people to update DNS whenever the ELB address changes is work
  that noone should do. USE DNS!!

* `InternalRoute53HostedZoneId`: Due to the potential for name-space violations
  we must have available the zone's ID to interrogate. The default for the
  zone's name ***must*** be "${APP_NAME}-${ENVIRONMENT}.local".

* `VPCNetwork`: This must be set to the network CIDR used for the entire VPC

* `RouteTableId`: This is the route table used by all primatives insiide the VPC

Moonshot Defaults:

* `aws:cloudformation:stack-name`: Moonshot gives us the stack-name for free
  and we use it to find the VPCId from the stack's name.

