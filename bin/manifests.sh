#!/bin/bash
# create k8s object manifests from system using kubectl

################################################################################
if [[ "$1" == "--help" ]]; then
    cat <<'ENDHELP'
Usage:
  cd ~/k8s-project  # where the namespace deployment resides 
  manifests.sh [options] <namespace>

Options:
 --deploy    Dump YAML deployment manifest 
 --service   Dump YAML service manifest 
 --ingress   Dump YAML ingress manifest 
ENDHELP
    exit
fi
################################################################################

BASH_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $BASH_DIR

PROJECTS=$( cd ${BASH_DIR}/../.. && pwd )
echo $PROJECTS

# ignore any command customizations
unalias cat  2> /dev/null
unalias cp   2> /dev/null
unalias git  2> /dev/null
unalias sudo 2> /dev/null

noAction=true

# --------------------------------------------------
# parse command line options

while [[ $# > 0 && "${1}" =~ ^-- ]]; do
    case "${1}" in 
      --deploy)  yamlDeploy=true;    noAction=false; shift 1 ;;
      --service) yamlService=true;   noAction=false; shift 1 ;;
      --ingress) yamlIngress=true;   noAction=false; shift 1 ;;
              *) echo "Unrecognized option: ${1}" >&2; exit 1 ;;
    esac
done

if [[ ${noAction} == true ]]; then
    echo "No action was specified" >&2
    exit 1
fi

# --------------------------------------------------
# OS compatibility shimming

SUDO=sudo
sed_i() { sed -i "$@"; }

if [[ "$(uname -s)" == 'CYGWIN'* ]]; then
    SUDO=
fi
if [[ "$(uname -s)" == 'Darwin'* ]]; then
    sed_i() { sed -i '' "$@"; }
fi

# --------------------------------------------------
# yaml manifest dumps 

if [[ ${yamlDeploy} == true ]]; then
    ( set -ex
      kubectl get deploy -n $1 -o yaml > dump-$1-deploy.yaml
    )
fi

if [[ ${yamlService} == true ]]; then
    ( set -ex
      kubectl get svc -n $1 -o yaml > dump-$1-service.yaml
    )
fi

if [[ ${yamlIngress} == true ]]; then
    ( set -ex
      kubectl get ingress -n $1 -o yaml > dump-$1-ingress.yaml
    )
fi
