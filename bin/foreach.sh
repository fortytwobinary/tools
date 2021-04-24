#!/bin/bash
# This script provides generalized functionality for doing this:
#   for dir in ${REPETITION_SET[@]}; do
#       ( cd $dir; some-command(s); )
#   done
# Where REPETITION_SET is configured by each.env, which can be customized for your project-specific directories.
# The options provide convenient control of execution, output formatting and REPETITION_SET subsetting.
# This script extends repeat.sh, which is expected to be co-located.
# It sources each.env, which is also expected to be co-located.

################################################################################
if [[ "$1" == "--help" ]]; then
    cat <<'ENDHELP'
Usage:
  export EACH_SET=groupA,groupB
  each.sh [options] <command-line>
    OR
  each.sh [options] <<'CMDS'
    <commands>...
  CMDS

A "project iterator" utility for performing ad hoc work in each of a set of source trees, eg, git working directories.
Shell command(s) to be performed in each project tree are specified in one of two ways:
  1) On the each.sh command line, immediately following any each.sh options
  2) As a file of commands read from stdin, typically as a heredoc
(Examples of usage can be found at end of this script)

The list of sub-directories to be visited is specified by REPETITION_SET, which is defined in each.env.
To customize each.env, copy it to <parent-directory>/.each, or to ~/.each, and edit that.

Options:
  -?       Summarize the each.sh configs & effective options, and exit.
  -s       Insert a spearation banner at the beginning of each iteration, using of this character. (default is -)
  -hs      Halt iteration upon the first success. (The default is halt after the first error: -hf)
  +h       Continue iterating, disregarding the exit code of each iteration.
  -v       verbose - Log identifying info before each iteration, and a summary after the last iteration.
  +v       terse - No logging.
  -g tags  Select prefined group(s) of projects. This option overrides EACH_SET.
           A valid tag is any array variable, containing a list of directory names, that is defined in each.env and/or .each.
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
       otherwise they are evaluated up front as part of the each.sh command, rather then during each iteration.

Provided variables:
  $RUN_DIR   The directory path where each.sh was invoked
  $I         The sequential number within each iteration
  $CURRENT_CMD_DIR  The directory path as specified in REPETITION_SET, (usually relative)

Other useful expressions:
  $PWD              The full directory path
  $(basename $PWD)  The relative directory name

Defaults:
  logLevel:   verbose  (See -v/+v)
  haltOn:     failure  (See -hs/-hf)
  outputUpon: all      (See -os/-of)
ENDHELP
    exit
fi
################################################################################

# TODO: +p to "exclude" individual project(s)
# TODO: add -j to operate on repos of open PRs, eg: each.sh -j bugfix/CA-666
# TODO: iteration-retry option (-rN), eg: for the irritating "Failed to delete C:\...\target"

BASH_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"

# --------------------------------------------------
# parse command line options

iterLogLevel=verbose
iterHaltOn=failure

fwdArgs=()
while [[ $# > 0 && "$1" =~ ^[-+] ]]; do
    case "$1" in
       -\?) REPORT_CONFIGS=_report_EACH_configs; shift 1 ;;
        -g) EACH_SET="${2}";       shift 2 ;;
          # any other options are forwarded to repeat.sh
        -1) fwdArgs+=( '-o' '${I}) ${IOUT} ${CURRENT_CMD_DIR}' ); shift 1 ;;
        -o) fwdArgs+=( '-o' "${2}" );                      shift 2 ;;
         *) fwdArgs+=( "${1}" );                           shift 1 ;;
    esac
done

# --------------------------------------------------
# initialize from repeat.sh and then apply overrides

source ${BASH_DIR}/repeat.sh "${fwdArgs[@]}"

# load user configs
# This is intended for overriding REPETITION_SET to specific project directories of interest
# .. although other definitions could conceivably be overridden as well
# (the repeat.sh default is to include all sub-directories in $PWD)

function source_if() {
    if [[ -e "${1}" ]]; then
        source "${1}"
        configFiles+=( "${1}" )
    fi
}
source_if ${BASH_DIR}/foreach.env  # globally-defined configs
source_if ~/.foreach               # user-defined, if any
source_if ./.foreach               # locally-defined, if any

if [[ ! -z ${EACH_SET} ]]; then
    # parse common-separated tags
    IFS=',' read -ra tagNames <<<"$EACH_SET"
    eachSet=()
    for tagName in "${tagNames[@]}"; do
      # verify that this is a defined array variable
      if [[ ! $(declare -p ${tagName}) =~ -a ]] 2> /dev/null; then
          echo "Unrecognized: ${tagName}" >&2
          echo "(Needs to be an array defined in each.env or .each)" >&2
          exit 1
      fi
      arrayRef=$tagName[@]       # eg, cfms[@]
      eachSet+=( ${!arrayRef} )  # append its elements to REPETITION_SET
    done
    #REPETITION_SET=( $(printf '%s\n' "${eachSet[@]}" | sort -u) )  # uniqify the list
    REPETITION_SET=( ${eachSet[@]} )
fi

# --------------------------------------------------
# Everything from here until 'now run it' is strictly function definitions...

# bash3 equivalent of "${1,,}", (for Mac-compatibility)
_tolowercase() {
    echo "$(tr '[:upper:]' '[:lower:]' <<<"${1}")"
}

compactPaths() {
    # matching on leading space left-anchors paths within the string
    # forcing lowercase caters to Windows -> cygwin path phenomena
    local paths=$(_tolowercase " ${1}")
    paths=${paths//"$(_tolowercase " ${HOME}")"/' ~'}
    paths=${paths//"$(_tolowercase " ${PWD}")/"/' '}
    echo "${paths:1}"
}

function _report_EACH_configs() {
    echo "Config load order: $(compactPaths "${configFiles[*]}")"
    echo "EACH_SET:  ${EACH_SET[@]}"
    _report_ITER_configs
}

# --------------------------------------------------
# override repeat.sh event handlers

if [[ ${iterLogLevel} == verbose ]]; then
    function iter_begin() {
        echo "======================================================================"
        echo "${I}) ${CURRENT_CMD_DIR}"
    }
    function iter_exit() {
        echo "=== Processed ${I} of ${#REPETITION_SET[*]} ==="
        exit $1
    }
    function iter_successStop() { echo "Stopping on first success: ${CURRENT_CMD_DIR}"; }
    function iter_successCont() { :; }
    function iter_failStop()    { echo "[$1] Error while processing ${CURRENT_CMD_DIR}" >&2; }
    function iter_failCont()    { echo "each.sh continuing despite error [$1] .."; }
fi

# --------------------------------------------------
# now run it ...

# make co-located scripts directly callable
export PATH="${BASH_DIR}:${PATH}"
cd ${EACH_ROOT:-.}

iter_run "$@"
exit $?

# __________________________________________________
# Usage examples
# (See usage examples in repeat.sh for additional details)

if false; then # X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X

# See options in effect (dry run)
each.sh -?

# A no-op, just list the project directories
each.sh

# Stop upon first error (default)
each.sh -hf false

# Stop upon first success
each.sh -hs grep -l 'spring-boot' README*.md

# Don't stop, regardless of iteration exit code
each.sh +h false

# git examples

each.sh git status -s -uno
each.sh git stash list
each.sh git log -1 --pretty=%B
each.sh -1 git branch --show-current
each.sh -o '$IOUT' +h grep 'url' .git/config

# Multi-command "Here Function" examples  ###

each.sh <<'CMDS'
  git status -s -uno
  git stash list
CMDS

# Create a new topic branch uniformly on all repos
each.sh <<'CMDS'
  git checkout dev
  git pull
  git checkout -b CA-666
CMDS

# Release tagging
each.sh <<'CMDS'
  git checkout master
  git pull origin master
  git tag -a '1.0.0-alpha' HEAD -m 'Jan 15 release'
  git push --tags --progress origin master:master
CMDS

# branches with no remote tracking set
each.sh -p ALL <<'CMDS' -os
  git rev-parse @{u} 2>&1 | grep "no upstream configured"
CMDS

# list out-of-date tracking branches
each.sh -p ALL -os <<CMDS
  git remote show origin | grep "local out of date" || :
CMDS

# mvn examples

each.sh mvn verify -DskipTests
each.sh mvn clean install

# Script examples - scripts living in the same directory as each.sh

# (WARNING: long-running)
each.sh lint.sh
each.sh indent.sh
each.sh rebuild.sh -x
each.sh deploy.sh -x

# (WARNING: destructive/irreversible)
#each.sh <<'CMDS'
#  set -e
#  BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
#  git checkout -f                        # throw away local changes
#  git clean -fdx                         # remove untracked files & directories
#  git reset --hard origin/${BRANCH_NAME} # reset index & working tree
#  git pull
#CMDS

# error/warning usage examples ###

# warning shown if recursively invoked: "recursive call to repeat.sh detected"
each.sh each.sh git status -s -uno

fi # X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X-X

