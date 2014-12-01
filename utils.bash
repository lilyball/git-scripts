# utilities for the git scripts

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
#   fatal <msg>
fatal() {
    printf 'fatal: %s\n' "${1-'expected parameter to `fatal`'}" >&2
    exit 128
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
    (( $# > 0 )) || fatal "set_color: expected <color> parameter"
    git config --get-color "$config" "$1"
}

# Usage:
#   color [-n] [(-b <boolconfig> | -f)] ([(-c <config>)] <color> <msg>)... [[(-c <config>)] <color>]
#
# Options:
#   -n               Suppress the trailing newline.
#   -b <boolconfig>  A config boolean value to pass to `git config --get-colorbool`.
#   -f               Force color output even if stdout is not a terminal.
#   -c <config>      Passes the given <config> to `git config --get-color`.
#
# Arguments:
#   <color>   The name of the color to use. This value is passed to
#             `git config --get-color` so any valid color that supports is
#             accepted, including background colors and attributes.
#   <msg>     The message to print in the given color.
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
color() {
    local newline=yes color=
    [[ -t 1 ]] && color=yes
    while (( $# > 0 )); do
        case $1 in
            -n)
                newline=;;
            -f)
                color=yes;;
            -b)
                (( $# > 1 )) || fatal "color: expected parameter to flag $1"
                git config --get-colorbool "$2"
                if (( $? == 0 )); then
                    color=yes
                else
                    color=
                fi;;
            -*)
                die 2 "unknown flag $1";;
            *)
                break;;
        esac
        shift
    done
    while (( $# > 0 )); do
        local config=()
        if [[ $1 == -c ]]; then
            (( $# > 1 )) || fatal "color: expected parameter to flag $1"
            config=(-c "$2")
            shift 2
        fi
        [[ -n $color ]] && set_color "${config[@]}" "$1"
        shift
        (( $# == 0 )) && break
        printf %s "$1"
        shift
    done
    [[ -n $newline ]] && printf '\n'
    return 0
}
