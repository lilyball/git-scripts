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

## `git-close-merged`

Closes all local branches that have been merged into HEAD (or a specified
branch). This command is upstream-aware, and can be instructed to close remote
branches as well. See `git close-merged --help` for details.

## `git-dirs`

Prints a list of the most recently checked-out branches. See `git dirs --help`
for details.

## `git-find-merge`

Finds the oldest merge in the first-parent history of a given branch that a
given commit is reachable from. This can be said to be the merge that introduced
a commit into a given branch. See `git find-merge --help` for details.
