# Moonshell

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

### Using

## Structure

### moon.sh

This is the magic sauce that makes everything work. It completely sets up
Moonshell and can be sourced at any time by executing `_moonshell -r`.

### bin

Scripts and other executables that you want available in your $PATH go here.

### completion.d

If there is a completion script for a script or a function, it goes in here.

### lib

All of the functions should go in here. The `private` directory is ignored by
git.

### profile.d

ENV vars and other such things go in here. The `private` directory is ignored
by git.

### var

Everything ephemeral that is created by Moonshell goes in here. This directory
is git ignored, so don't use it for anything important.

