# Moonshell

The original impetus and raison detre for this project was [Moonshot](https://github.com/acquia/moonshot).
It has since been abandoned by its owner, but it did some things well and simply.

The focus of this project is to make AWS CF stacks simple and easy for an
administrator to use from the CLI.

Influential axioms:

1. Clean code is good code

1. Make peoples lives better and easier

1. Do unto others as you would have done unto yourself

Contents:

1. [Overview](#overview)

1. [Directory Structure](#directory-structure)

1. [Usage](#usage)

1. [Structure](#structure)

1. [Why](#why)

1. [How](#how)

## Overview

Everything starts with `./moon.sh`. When sourced it:

1. Sets core `MOON_` variables.

1. Adds itself to `PATH`.

1. Sources `*.sh` files from `lib`, `profile.d` and `completion.d`.

1. Automatically sources {etc,lib,etc/{profile.d,completion.d}} in `.`

### Setup

`jq` must be installed to parse output from the AWS CLI.

To get the most out of Moonshell you have to source it during login. You can
add the following to your `~/.bashrc` or `~/.bash_profile`, which ever is best
for your choice of operating system.

Sample:

```
# MoonShell - https://github.com/communityds/moonshell
#
# This block must be the last entry in your .bash_profile/.bashrc. moon.sh
# assumes that it is being sourced last for the modifications it makes to PATH.
#export DEBUG=true
source ${HOME}/tools/moonshell/moon.sh
```

## Directory Structure

To implement Moonshell in to a product a few key files are required:

```
moonshell/moonshell.sh
moonshell/${environment}.sh
moonshell/templates/template.yml
moonshell/templates/nest-template.yml
```

### moonshell/moonshell.sh

This file contains all global variables to use with every environment of every
stack for this product.

Mandatory minimum contents:
* `APP_NAME` Is the name of your product which matches `^[a-zA-Z0-9_]*$`
* `STACK_TEMPLATE_BUCKET` Is the short name of your preconfigured bucket

Optional
* `STACK_TEMPLATE_FILE` Overrides the default location of the parent stack template: `moonshell/templates/template.yml`
* `STACK_TEMPLATE_BUCKET_SCHEME` is one of `s3://`(default) or `file://`.

### moonshell/${environment}.sh

An environment file must exist for each environment of an application. It is a
line delimited list of `KEY=VALUE`. The KEY word must be valid for both Bash and
Cloudformation. The VALUE must be a quoted string.

Example:

```
InstanceType="t3.nano"
VolumeSize="50"
EncryptionEnabled="true"
EncryptionKey="arn:aws:kms:ap-southeast-2:123456789012:key/12345678-90ab-cdef-1234-567890abcdef"
```

### moonshell/templates/template.yml

The content and size of the main template must comply with all [AWS quotas](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cloudformation-limits.html).

### moonshell/templates/nest-template.yml

The naming of your nested-template is up to you, provided the parent stack template
is whatever `STACK_TEMPLATE_FILE` is set to. When the `moonshell/templates/`
directory is uploaded to your designated S3 bucket it automatically runs with
the `--delete` flag.

It is recommended to not have versioning enabled on your `STACK_TEMPLATE_BUCKET`
and instead rely on versioning of your template in git.

## Usage

The functionality of Moonshell differs between whether it is in an interractive
shell, or a script. There are two main switches you may need to use in custom
scripts depending on the level of integration required.

* `AWS_ACCOUNT_NAME` if `false` does not pre-load any AWS specific libraries
* `MOON_FILE` if `false` disables the need to be in the root of a repo to operate

The majority of Moonshell's functionality relies upon a `moonshell/moonshell.sh`
to set product related variables. By default we assume that the stack name is
a concatenatenation of application and environment.

* `STACK_NAME="${APP_NAME}-${ENVIRONMENT}"`

### Debug

Debugging is relatively easy as you only need set a single variable; `DEBUG`.

For example:

```
DEBUG=true s3-ls dev
```

To debug issues with the initial shell sourcing of Moonshell, uncomment the
`DEBUG` line from your `~/.bashrc`/`~/.bash_profile` and spawn a new shell. All
future shells will have DEBUG enabled by default until you remove it from your
profile.

### Admin

The `_moonshell` function enables basic admin functionality for Moonshell. You
can tab complete its options for more info.

```
[user@host ~]$ _moonshell
Usage: _moonshell [-h|--help] [-r|--reset] [-s|--setup]
Perform basic functions for Moonshell.

    -h, --help      show this help and exit
    -r, --reset     remove all var files and regenerate self
    -t, --test      run bashate, rubocop and markdownlint
```

### Overlaying

Moonshell contains common functions and features required across all products,
but each product has differences; requires different tools, different
variables etc. The solution is to overlay customisations.

Per the structure below, Moonshell uses the FHS standard dirs of `bin`, `lib`,
`var`, `etc`, etc. If, in your repo of `${HOME}/dev/repo`, you have a `bin` and
`lib` directory, you can simply:

`overlay_dir_install PATH_TO_REPO`

This will automatically create an entry in `etc/profile.d/private/overlay.sh`,
so every time you spawn a shell your repo dir is automatically layed atop of
Moonshell. `bin/` will be prepended to `${PATH}` and every .sh file in `lib/`
will be sourced. Identically named scripts in `${MOON_BIN}` and functions in
`${MOON_LIB}` will replace the default in Moonshell.

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
the time of writing these tools Moonshot has been abandoned by its original
author and using Ruby to develop solutions to our needs is an expense we can't
afford. We are working through the process of developing out several systems
that all interract with each other on some level; the scope and functionality
is being found out as development happens.

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
  zone's name ***must*** be "${APP_NAME}-${ENVIRONMENT}.local". `'.local`
  domains are, like the 10.0.0.0/8 network range, unusable on the internet, so
  it further reinforces that DNS is local to the host you are on.

* `RouteTableId`: This is the route table used by all primatives inside the VPC

* `VPCId`: This can be programmatically found from knowing the stack name, but
  having it as an output helps users and some scripts.

* `VPCNetwork`: This must be set to the network CIDR used for the entire VPC

CloudFormation Defaults:

* `aws:cloudformation:stack-name`: CF gives us the stack-name for free and we
  use it to find the VPCId from the stack's name when other methods aren't
  available.

### Code Deploy

Per stack there must only be one Code Deploy application. We tar ball the
`codedeploy/` directory and upload it to `codedeploy/` in the stack's local s3
bucket. All nodes which are to deploy the artefact must have read access to
that location, and the host buliding the artefact must be able to write to it.

Inside of the `codedeploy/` directory you must have an `appspec.yml` file per:
https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file.html#appspec-reference-server

Example S3 IAM policy written in YAML

```
  ArtefactS3Policy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: ArtefactS3IAMPolicy
      PolicyDocument:
        Statement:
          - Effect: Allow
            Action:
              - s3:ListBucket
            Resource:
              - Fn::GetAtt:
                - ArtefactS3Bucket
                - Arn
          - Effect: Allow
            Action:
              - s3:GetObject
            Resource:
              - Fn::Join:
                - ''
                - - Fn::GetAtt:
                    - ArtefactS3Bucket
                    - Arn
                  - '/codedeploy/*'
```

### KMS

We strongly advise the use of KMS to encrypt all data at rest. You can use KMS
for encrypting EBS volumes attached to instances, RDS, and even for S3. It is
unadvisable to statically set the KMS key as you should use a different key for
every stack you run to ensure your data is completely isolated. The setup of
KMS is beyond the scope of this document, but it should be defined in your
template as a 'must have' parameter.

Moonshell, specifically `s3_upload` and `s3_upload_multipart`, check for the
presence of a parameter that starts with `arn:aws:kms` and uses this to set
the encryption key used. If not present, no encryption is used. AWS does set,
but use by default, their own KMS key, but using this is arguably defunct.

To view all available KMS keys for your account:

```
aws kms list-aliases
```

* NOTE: You should specify a KMS key as the key UUID and not the alias, this is
because IAM policy can only be set on a key's UUID.

### SSH with a Jump Host / Bastion

Connecting directly to your application servers via SSH is plain madness, poor
practice and a violation of several security frameworks. Use a jump host!

To get the most out of your jump host you should use either ProxyCommand
or ProxyJump; for example, if you have foo bastion and use the bar.local and
baz.local domains for your cloud servers:

```
Host bastion-foo
  Hostname bastion-foo.example.com
  StrictHostKeyChecking yes
  ForwardX11 no

host *.bar.local
  ProxyJump bastion-foo

host *.baz.local
  ProxyCommand ssh bastion-foo nc -w 120s %h
```

Depending on the application you are hosting you may choose to have a dedicated
and separated 'admin' node from where you can perform your needed admin
functions; it's poor form to give your application nodes access to all the
things if not strictly required. To this end Moonshell contains several
'bastion' functions. These are to enable scripts to execute remotely for
dumping/restoring of databases or what ever you may need.

To make the most of this you either need to export a variable; this is
prepended to the internal domain name of the stack:

```
export ADMIN_NODE_HOSTNAME=
```

Or, create a function which returns the FQDN of the admin node, for example:

```
ssh_target_hostname () {
    local stack_name=$1

    case ${stack_name} in
        foo-*) echo "admin.${stack_name}.local" ;;
        bar-dev) echo "admin.yolo-dev.local" ;;
        *) echo "localhost" ;;
    esac
}
```

### S3 Bucket

Every stack which has an S3 bucket should have versioning enabled and be
configured with a KMS key. All relevant `s3_` functions try to detect existence
of KMS in the stack and insert appropriate switches when required.

The discovery of the stack's S3 bucket name requires a heavy API call to list
stack resources. Because this call has a low requests-per-minute threshold, and
we do not handle retries, the S3 bucket name should be defined once at the top
of a script and it will be used thereafter. We assume this variable is
`S3_BUCKET`

```
export S3_BUCKET="$(s3_stack_bucket_name ${STACK_NAME})"
```

