#!/bin/bash
# This script provides generalized functionality for doing this, (see _iterate()):
#   for dir in */; do
#       ( cd $dir; some-command(s); )
#   done
#
# The options provide convenient control of execution and output formatting.

################################################################################
if [[ "$1" == "--help" ]]; then
    cat <<'ENDHELP'
Usage:
  cd <parent-directory>
  PATH+=:$PWD/tools/bin
  repeat.sh [options] <command-line>
    OR
  repeat.sh [options] <<'CMDS'
    <commands>...
  CMDS

A "directory iterator" utility for performing ad hoc work in each sub-directory in $PWD.
Shell command(s) to be performed in each directory are specified in one of two ways:
  1) On the iter.sh command line, immediately following any iter.sh options
  2) As a file of commands read from stdin, typically as a heredoc
(Examples of usage can be found at end of this script)

Options:
  -?       Summarize the iter.sh configs & effective options, and exit.
  -s       Insert a spearation banner at the beginning of each iteration, using of this character. (default is -)
  -hf      Halt iteration upon the first failure/error. (The default is to just keep going: +h)
  -hs      Halt iteration upon the first success.
  -x       Enable command execution tracing.
  -v       verbose - Log identifying info before each iteration, and a summary after the last iteration.
  +v       terse - No logging
  -1       A single line of output for each iteration. A shortcut for: -o '$I) $IOUT $IDIR'
  -o fmt   (disables logging) The specific output format for each iteration. (This disables logging.)
           (Assumes that the iterated command emits a single line simple value. eg, git branch --show-current)
           In addition to the "Provided variables" listed below, this option also provides $IOUT,
           containing the output produced during each iteration.
  -os,-of  In conjunction with -o, show the output only when the iteration succeeds/fails, (per its exit code).
           The output format deafults to: '$I) $IDIR\n$IOUT'. To override, specifiy -o after the option.
           haltOn defaults to none (+h). To override, specifiy -hf or -hs after the option.

Several shell variables can be referenced by the user command(s) being executed.
These variables are exported so that they can be referenced within invoked scripts as well.
NOTE - if used directly on the command line, shell variables need to be escaped,
       otherwise they are evaluated up front as part of the iter.sh command, rather then during each iteration.

Provided variables:
  $RUN_DIR   The directory path where repeat.sh was invoked
  $I         The sequential number within each iteration
  $CURRENT_CMD_DIR  The directory path as specified in REPETITION_SET, (usually relative)

Other useful expressions:
  $PWD              The full directory path
  $(basename $PWD)  The relative directory name

Defaults:
  logLevel:   terse  (See -v/+v)
  haltOn:     none   (See -hs/-hf)
  outputUpon: all    (See -os/-of)
ENDHELP
    exit
fi
################################################################################

# This script is "source-me" extensible.
# To reuse from within another script:
#   1. source iter.sh [<options>...]
#   2. Override: REPETITION_SET and/or iter_*() functions, as needed
#   3. iter_run [<options>...] [<params>...]

# TODO?: source .bashrc so that user functions are available
# TODO?: -oo no iteration header when no iteration output
# TODO? rename -o,-os,-of to -e,-es,-ef ("echo")
# TODO: de-dupe REPETITION_SET, without sorting it
# TODO: re-quote command line params in funcBody (until then, use a "Here Function" for non-trivial command syntax)

BASH_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ignore command customizations, if any
unalias cat    2> /dev/null
unalias printf 2> /dev/null

# --------------------------------------------------
# defaults

export RUN_DIR=${PWD}

# all (non-.) directories in $PWD
REPETITION_SET=( */ )

# --------------------------------------------------
# parse command line options

# variable defaults (expression evaluation via : no-op command)
: ${iterCmdTrace:=+x}     # +x/-x
: ${iterLogLevel:=terse}  # terse/verbose/formatted
: ${iterHaltOn:=none}     # failure/success/none
: ${outputUpon:=all}      # failure/success/all
iterSeparator=
outFormat=

function _parse_simple_option() {
    # NOTE: this CANNOT handle options with args, (ie, shift > 1)
    case "$1" in
       -\?) REPORT_CONFIGS=_report_ITER_configs ;;
        -x) iterCmdTrace=-x       ;;
        -v) iterLogLevel=verbose  ;;
        +v) iterLogLevel=terse    ;;
       -hf) iterHaltOn=failure    ;;
       -hs) iterHaltOn=success    ;;
        +h) iterHaltOn=none       ;;
       -os) outputUpon=success    ;;
       -of) outputUpon=failure    ;;
       -s*) sepChar=${1:2}; iterSeparator=$(printf "=%.0s" {1..60} | tr "=" "${sepChar:--}") ;;
         *) echo "$(basename ${BASH_SOURCE}): Unrecognized option: $1" >&2
            exit 1 ;;
    esac

    if [[ outputUpon != 'all' ]]; then
       iterHaltOn=none
       iterLogLevel=formatted
       outFormat=$'$I) $IDIR\n$IOUT'
    fi
}

while [[ $# > 0 && "$1" =~ ^[-+] ]]; do
    case "$1" in
      -1) iterLogLevel=formatted; outFormat='${I}) ${IOUT} ${CURRENT_CMD_DIR}'; shift 1 ;;
      -o) iterLogLevel=formatted; outFormat="${2}";                      shift 2 ;;
       *) _parse_simple_option "${1}";  shift 1 ;;
    esac
done


# --------------------------------------------------
# Everything from here until 'now run it' is strictly function definitions...

function _report_ITER_configs() {
    if [[ ${iterLogLevel} == formatted ]]; then
        echo "log level: ${iterLogLevel} '${outFormat}'"
        if [[ ${outputUpon} != all ]]; then
            echo "    output only: ${outputUpon} iterations"
        fi
    else
        echo "log level: ${iterLogLevel}"
    fi
    echo "halt on:   ${iterHaltOn}"
    echo "REPETITION_SET (${#REPETITION_SET[@]}):"
    for CURRENT_CMD_DIR in "${REPETITION_SET[@]}"; do
        if [[ ! -e ${CURRENT_CMD_DIR} ]]; then
            echo "    ${CURRENT_CMD_DIR}   DOES NOT EXIST HERE"
        else
            echo "    ${CURRENT_CMD_DIR}"
        fi
    done
    declare -f _iter_visit
}

# --------------------------------------------------
# dynamic function definition helper

function _trim_whitespace() (
    local str="$1"
    shopt -s extglob
    str="${str##*( )}" # trim leading
    str="${str%%*( )}" # trim trailing
    echo "${str}"
)

# Assemble the user command(s) provided one of two ways:
#  1) the remaining command-line arguments interpreted as a command
#  2) command line(s) read from STDIN, (typically a HERE doc)
#     in which case, any remaining command-line args are discarded
# TODO: rework string manipulation to maintain arg quoting
function assemble_user_commands() {
    # (NOTE: fancy bash stuff: tty-sensing, dynamic function creation, etc)
    if [[ -t 0 ]]; then
        local funcBody="$@"      # from caller args
    else
        local funcBody="$(cat)"  # from piped or redirected
        if [[ $# > 0 ]]; then
            echo "Using stdin, extraneous command line parameters ignored: $@" >&2
        fi
    fi

    # handle no-op case
    funcBody="$(_trim_whitespace "${funcBody}")"
    if [[ ${#funcBody} == 0 ]]; then
        # empty funcBody
        funcBody=":"  # no-op command
    fi
    echo "${funcBody}"
}

# --------------------------------------------------
# event handlers

function iter_successStop() { :; }
function iter_successCont() { :; }
function iter_failStop()    { :; }
function iter_failCont()    { :; }

function iter_separator() { :; }
if [[ ! -z "${iterSeparator}" ]]; then
    function iter_separator() { echo "${iterSeparator}"; }
fi

case ${iterLogLevel} in
    verbose)
        function iter_begin() { echo "${I}) ${CURRENT_CMD_DIR}"; }
        function iter_end()   { :; }
        function iter_exit()  { echo "= ${I} of ${#REPETITION_SET[*]} ="; exit $1; }
        ;;
    terse)
        function iter_begin() { :; }
        function iter_end()   { :; }
        function iter_exit()  { exit $1; }
        ;;
    formatted)
        function iter_begin() { :; }
        eval "function _iter_out() ( echo \"${outFormat}\" )"
        function iter_end() {
            if [[ ${outputUpon} == success && ${1} != 0 ]] \
            || [[ ${outputUpon} == failure && ${1} == 0 ]]; then
                return
            fi
            _iter_out
        }
        function iter_exit()  { exit $1; }
        ;;
esac

# --------------------------------------------------
# checks

function _warn_if_recursion() {
    # TODO: (if this should be a hard error condition) devise a way to immediately exit from the top-level iter.sh
    #   worst case would be monitoring a lock file in the _iter_visit loop; this could also contain the error message
    if type -t _iter_visit; then
        # we must be a child of a running iteration that has exported _iter_visit()
        echo "WARNING: recursive call to iter.sh detected" >&2
    fi
}

function _validate_REPETITION_SET() {
    local dir
    for dir in "${REPETITION_SET[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            echo "Non-existent directory in REPETITION_SET: ${dir}" >&2
            echo "Maybe we're in the wrong directory?" >&2
            exit 1
        fi
    done
}

# --------------------------------------------------
# execution loop

function _stopOrContinue() {
    local rc=$1
    if [[ ${rc} == 0 ]]; then
        if [[ ${iterHaltOn} == success ]]; then
            iter_successStop 0
            iter_exit 0
        else
            iter_successCont 0
        fi
    else
        if [[ ${iterHaltOn} == failure ]]; then
            iter_failStop ${rc}
            iter_exit ${rc}
        else
            iter_failCont ${rc}
        fi
    fi
}

# this is the core loop that drives iteration
function _iterate() (
    declare -ix I=0
    declare  -x CURRENT_CMD_DIR
    declare  -x IDIR
    declare  -x IOUT
    for CURRENT_CMD_DIR in "${REPETITION_SET[@]}"; do
        IDIR=$(basename ${CURRENT_CMD_DIR})  # also trims any trailing slash
        I+=1
        iter_separator
        iter_begin
        if [[ ${iterLogLevel} == formatted ]]; then
            IOUT=$( cd "${CURRENT_CMD_DIR}"; _iter_visit )
            iterRC=$?
        else
            ( cd "${CURRENT_CMD_DIR}"; _iter_visit )
            iterRC=$?
        fi
        iter_end ${iterRC}
        _stopOrContinue ${iterRC}
    done
    iter_exit ${iterRC}
)

function iter_run() (
    # parse command line options (second pass)
    while [[ $# > 0 && "$1" =~ ^[-+] ]]; do
        _parse_simple_option "$1"
        shift 1
    done

    _warn_if_recursion

    eval "function _iter_visit() ( set ${iterCmdTrace}; $(assemble_user_commands "$@") )"
    export -f _iter_visit

    if [[ ! -z "${REPORT_CONFIGS}" ]]; then
        # run defined reporting function
        ${REPORT_CONFIGS}
        exit 0
    fi

    _validate_REPETITION_SET

    # make co-located scripts directly callable
    export PATH="${BASH_DIR}:${PATH}"
    _iterate
)

# --------------------------------------------------
# now run it ...

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    # this script has been run as a command, not source'd
    iter_run "$@"
    exit $?
fi

# else this script has been source'd

# __________________________________________________
# Usage examples

if false; then # X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X

# A no-op, just list the iteration set (directories)
iter.sh -v

# Single command examples ###
#   Unless quoted/escaped, file globbing & variable expansion occur up front.
#   The given command runs in a fresh subshell during each directory visit.

# List the most recently modified file in each sub-directory
iter.sh echo '$PWD/$(ls -t ${PWD} |head -1)'

# Stop upon first error
iter.sh -v -hf false

# Stop upon first success
cd /etc
iter.sh -v -hs [[ -d etc ]]
cd -

# Don't stop, regardless of iteration exit code (default)
iter.sh -v +h false

# Script example - script living in the same directory as iter.sh
# (WARNING: long-running)
iter.sh lint.sh

# Multi-command "Here Function" examples ###
#   Like traditional EOF, CMDS can be any token you like.
#   The given function body runs in its own subshell during each directory visit.
#   File globbing occurs at visit-time.
#   If 'CMDS' is in single quotes, then variable expansion will occur during each iteration.

# contrived FUNC example
iter.sh <<'CMDS'
  echo "$(stat --format="%A %B" .) ${CURRENT_CMD_DIR}"
CMDS

# Employ set -e (errexit) option: ls will never execute
iter.sh <<'CMDS'
  set -e
  pwd
  false  # intentional error
  ls -dl $PWD
CMDS

# Simple source-me reuse example - could be the basis for a dedicated script
( source iter.sh
  REPETITION_SET=( $(find . -maxdepth 2 -name pom.xml -printf '%h\n') )
  iter_run <<'CMDS'
    grep -m 1 '<version' pom.xml
CMDS
)

# survey out-of-date tracking branches
# (note +h so that we don't stop when a grep finds no match)
each.sh -p ALL +h <<CMDS
  git remote show origin | grep "local out of date"
CMDS

# error/warning usage examples ###

# Inline command while also providing a "Here Function": "extraneous command parameters ignored"
iter.sh -v spuriouso -z <<'CMDS'
  false
CMDS

# A source-me error example: "Non-existent directory in REPETITION_SET: /non-existent"
( source iter.sh
  REPETITION_SET=( /non-existent )
  iter_run
)

# Empty REPETITION_SET: "I: 0"
( source iter.sh
  REPETITION_SET=()
  function iter_exit()  { echo "I: $I"; exit $1; }
  iter_run -v
)

# warning shown if recursively invoked: "recursive call to iter.sh detected"
iter.sh iter.sh git status -s -uno

fi # X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X

