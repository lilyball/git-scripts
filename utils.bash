#!/bin/bash

# utilities for the git scripts

if (( ${#BASH_SOURCE[@]} <= 1 )) && [[ $- != *i* ]]; then
    echo "utils.bash is not an executable script" >&2
    echo "source it from your other scripts with:" >&2
    echo "  . \"\${BASH_SOURCE[0]%/*}\"/utils.bash" >&2
    exit 1
fi

# Usage:
#   die
#   die [<code>] <msg>
#   die <code> <msg>...
#
# Arguments:
#   <code>  The code to exit with. If not provided, defaults to $?.
#           If $? is 0, defaults to 1 instead.
#   <msg>   A message to print to stderr. The first provided message
#           is prefixed with "error: ".
die() {
    local code=$?
    if (( $# > 1 )); then
        code=$1
        shift
    elif (( code == 0 )); then
        code=1
    fi
    if (( $# > 0 )); then
        color -n red "error:" reset " "
        printf "%s\n" "$@"
    fi >&2
    exit "$code"
}

# Usage:
#   fatal [(-f | (-n <n>))] <msg>...
#
# Options:
#   -f      Prints the calling function name before the message.
#           This indicates that the function was used incorrectly.
#   -n <n>  Prints the function <n> levels deep before the message.
#           0 is the current function, 1 is the calling function, etc.
#
# Arguments:
#   <msg>  The message to print. Multiple messages are joined
#          by spaces.
#
# Prints the fatal message and returns (not exits) with 128. Callers
# are expected to then return themselves.
fatal() {
    local name='' msg='' error=''
    if [[ $1 == -f ]]; then
        name=${FUNCNAME[1]}
        shift
    elif [[ $1 == -n ]]; then
        shift
        if (( $# > 0 )); then
            declare -i n=$1
            shift
            if (( n < 0 )); then
                # shellcheck disable=SC2016
                error='`fatal` flag -n parameter must be non-negative'
            else
                name=${FUNCNAME[$n+1]-unknown}
            fi
        else
            # shellcheck disable=SC2016
            error='expected parameter to `fatal` flag -n'
        fi
    fi
    if (( $# == 0 )); then
        # shellcheck disable=SC2016
        error='expected parameter to `fatal`'
    fi
    if [[ -z $error ]]; then
        msg=$*
    else
        name=${FUNCNAME[1]}
        msg=$error
    fi
    printf 'fatal: %s%s\n' "${name:+$name: }" "$msg" >&2
    return 128
}

# Usage:
#   _expect <n> <flag> [<arg>...]
#   _expect <n> -m <msg> [<arg>...]
#
# Options:
#
# Arguments:
#   <n>     The number of required arguments.
#   <flag>  The flag that expects arguments.
#   <msg>   The message to print in the case of failure.
#   <arg>   The rest of the arguments
#
# Returns:
#   If <n> arguments were provided, 0 is returned.
#   Otherwise, a fatal error is printed and a non-zero status is returned.
#
# Notes:
#   Expected usage looks like:
#
#       _expect 1 "$@" || return
_expect() {
    declare -i n=$1
    local flag=$2 msg=
    shift 2
    if [[ -z $n || -z $flag ]]; then
        fatal -f 'missing required parameters'; return
    fi
    if [[ $flag == -m ]]; then
        msg=${1:-'expected parameter(s)'}
        shift
    fi
    if (( n > $# )); then
        if [[ -z $msg ]]; then
            if (( n == 1 )); then
                msg="expected parameter to flag $flag"
            else
                msg="expected $n parameters to flag $flag, found $#"
            fi
        fi
        fatal -n 1 "$msg"
    fi
}

# === Color ===

# Usage:
#   set_color [-c <config>] <color>
#
# Options:
#   -c <config>  Passes the given <config> to `git config --get-color`.
#
# Arguments:
#   <color>  Passes the given <color> to `git config --get-color`
#
# Sets the given color without regard to whether stdout is a terminal.
set_color() {
    local config=
    if (( $# > 1 )); then
        config=$1
        shift
    fi
    _expect 1 -m 'expected <color> parameter' "$@" || return
    git config --get-color "$config" "$1"
}

# Usage:
#   color [-n (-b <boolconfig>) -f] ([(-c <config>)] <color> <msg>)... [[(-c <config>)] <color>]
#
# Options:
#   -n               Suppress the trailing newline.
#   -b <boolconfig>  A config boolean value to pass to `git config --get-colorbool`.
#   -f               Force color output even if stdout is not a terminal.
#                    If -b is used, a color config of `never` will still override this.
#   -c <config>      Passes the given <config> to `git config --get-color`.
#
# Arguments:
#   <color>  The name of the color to use. This value is passed to
#            `git config --get-color` so any valid color that supports is
#            accepted, including background colors and attributes.
#   <msg>    The message to print in the given color.
#
# The printed message will be terminated with a newline unless the `-n` flag
# is passed. Any final color provided will be emitted before the newline.
#
# Note: this command does not reset the color at the end. You are encouraged
# to pass `reset` as the final color if the previous message is colorized.
#
# This command will only print color if the stdout is a terminal, unless either
# `-f` is passed, which forces color, or `-b <boolconfig>` is passed, which tests
# `git config --get-colorbool`.
#
# Note: the output of `git config --get-colorbool` is cached between calls.
utils_color_cache_key=()
utils_color_cache_value=()
color() {
    local newline=yes tty='' config=''
    [[ -t 1 ]] && tty=yes
    while (( $# > 0 )); do
        case $1 in
            -n)
                newline=;;
            -f)
                tty=yes;;
            -b)
                _expect 1 "$@" || return
                shift
                config=$1;;
            *)
                break;;
        esac
        shift
    done
    local color=auto
    if [[ -n $config ]]; then
        # check our cache
        local idx key="${tty:-no},$config"
        for idx in "${!utils_color_cache_key[@]}"; do
            if [[ ${utils_color_cache_key[$idx]} == "$key" ]]; then
                color=${utils_color_cache_value[$idx]}
                break
            fi
        done
        if [[ $color == auto ]]; then
            case $(git config --get-colorbool "$config" "$tty") in
                true) color=yes;;
                false) color=;;
                *) echo "warning: unknown output from git config --get-colorbool" >&2;;
            esac
            utils_color_cache_key+=("$key")
            utils_color_cache_value+=("$color")
        fi
    fi
    [[ $color == auto ]] && color=$tty
    while (( $# > 0 )); do
        local config=
        if [[ $1 == -c ]]; then
            _expect 1 "$@" || return
            config=$2
            shift 2
        fi
        # shellcheck disable=SC2086
        [[ -n $color ]] && set_color ${config:+"$config"} "$1"
        shift
        (( $# == 0 )) && break
        printf %s "$1"
        shift
    done
    [[ -n $newline ]] && printf '\n'
    return 0
}

# Usage:
#   print_lines -h <header> [(-c <color> [-f])] [-n] <text>...
#   print_lines <text>...
#
# Options:
#   -h <header>  Displays <header> before the first line of <text>.
#                Subsequent lines are indented by the length of the
#                header, unless -n is passed.
#   -c <color>   The name of the color to use for the header. See
#                `git config --get-color` for details on allowed colors.
#                Color is only used if stdout is a terminal, unless
#                the -f option is used.
#   -f           Force color output even if stdout is not a terminal.
#   -n           Do not indent subsequent lines of the text.
#
# Arguments:
#   <text>  The text to print to stdout. Multiple <text> arguments
#           are joined by a newline before printing.
#
# Example:
#   print_lines -h note -c yellow "$text"
print_lines() {
    local header='' color='' indent=yes flags=()
    while (( $# > 0 )); do
        case $1 in
            -h)
                _expect 1 "$@" || return
                shift
                header=$1;;
            -c)
                _expect 1 "$@" || return
                shift
                color=$1;
                [[ $color == -* ]] && { fatal -f 'illegal color value'; return; };;
            -f)
                flags+=(-f);;
            -n)
                indent=;;
            *)
                break;;
        esac
        shift
    done
    if [[ -n $header ]]; then
        local temp=$IFS IFS=$'\n'
        local text="$*" IFS=$temp
        local line first=yes
        while read -r line; do
            if [[ $first == yes ]]; then
                if [[ -n $color ]]; then
                    color "${flags[@]}" "$color" "$header" reset ": $line"
                else
                    printf '%s: %s\n' "$header" "$line"
                fi
                first=
                if [[ -n $indent ]]; then header="${header//?/ }  "; else header=''; fi
            else
                printf '%s%s\n' "$header" "$line"
            fi
        done <<<"$text"
    else
        # no header means no treatment of the text
        printf '%s\n' "$@"
    fi
}
