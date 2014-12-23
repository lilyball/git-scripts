# git-scripts

A collection of scripts for use with git

## Installation

Place this directory in your `$PATH`.

### Bash

```sh
PATH=path/to/git-scripts:$PATH
```
### Fish

```fish
set PATH path/to/git-scripts $PATH
```

## Usage

Every script can be invoked as a git subcommand such as `git dirs`. Every script
should respond to the `--help` flag with its expected parameters and options.

# Scripts

## `git-close-current-branch`

Closes the current branch if it's been merged into the mainline. Intended usage
is after a pull request for the current branch has been merged into mainline and
the remote branch deleted. See `git close-current-branch --help` for details.
