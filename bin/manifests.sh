#!/bin/bash
# create k8s object manifests from system using kubectl

################################################################################
if [[ "$1" == "--help" ]]; then
    cat <<'ENDHELP'
Usage:
  (First make sure that you are git-authenticated to Bitbucket)
  cd ~/projects  # where you want the git working directories to live
  setup.sh [options]

Setup helper for FTB workstations or servers.

Options:
    --shell  Initialize shell environment variables (bash and/or zsh)
             (May prompt for sudo password while updating /etc/profile.d)
     --java  Install the US encryption strength policy files
             (May prompt for sudo password while updating $JAVA_HOME/lib/security)
    --maven  Copy in the MS3 repository settings
  --storage  Establish local database storage
     --curl  Initialize .curlrc, (mTLS settings)
   --devops  Clone the devops repos
   --cdxmon  Clone the CDX Monitoring repos
   --common  Clone & build the common source with the config & data repos
   --advana  Clone & build the Advana source repos
    --sabrs  Clone & build the SABRS source repos
  --sabrscb  Clone & build the SABRS Checkbook source repos
  --sabrsgl  Clone & build the SABRS GL source repos
   --smarts  Clone & build the CFMS SMARTS source repos
 --smartslh  Clone & build the CFMS SMARTS Labor History source repos
 --deploy    Dump YAML deployment manifest 
 --service   Dump YAML service manifest 
 --ingress   Dump YAML ingress manifest 
     --ginv  Clone & build the G-Invoicing source repo
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
        --shell) initShell=true;     noAction=false; shift 1 ;;
         --java) initJava=true;      noAction=false; shift 1 ;;
        --maven) initMaven=true;     noAction=false; shift 1 ;;
      --storage) initStorage=true;   noAction=false; shift 1 ;;
         --curl) initCurl=true;      noAction=false; shift 1 ;;
       --devops) cloneDevops=true;   noAction=false; shift 1 ;;
       --common) cloneCommon=true;   noAction=false; shift 1 ;;
       --cdxmon) cloneCdxMon=true;   noAction=false; shift 1 ;;
         --ginv) cloneGinv=true;     noAction=false; shift 1 ;;
       --advana) cloneAdvana=true;   noAction=false; shift 1 ;;
        --sabrs) cloneSabrs=true;    noAction=false; shift 1 ;;
      --sabrscb) cloneSabrsCb=true;  noAction=false; shift 1 ;;
      --sabrsgl) cloneSabrsGl=true;  noAction=false; shift 1 ;;
       --smarts) cloneSmarts=true;   noAction=false; shift 1 ;;
     --smartslh) cloneSmartsLh=true; noAction=false; shift 1 ;;
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
# shell setup

if [[ ${initShell} == true ]]; then
    if [[ -e ~/.zshrc ]]; then
        echo "Adding cdx-env-tools/cdxrc to ~/.zshrc"
        sed_i -e '/cdxrc/d' ~/.zshrc
        echo "source ${CDX_PROJECTS}/cdx-env-tools/cdxrc" >> ~/.zshrc
    fi
    if [[ -e ~/.bashrc ]]; then
        echo "Adding cdx-env-tools/cdxrc to ~/.bashrc"
        sed_i -e '/cdxrc/d' ~/.bashrc
        echo "source ${CDX_PROJECTS}/cdx-env-tools/cdxrc" >> ~/.bashrc
    fi
    # copy-in user configs
    if [[ ! -e ~/.exrc ]]; then
        echo "Adding ~/.exrc (vi editor defaults)"
        cp ${CDX_PROJECTS}/cdx-env-tools/host-configs/~/.exrc ~
    fi
fi

# --------------------------------------------------
# Java setup

if [[ ${initJava} == true ]]; then
    if [[ -z ${JAVA_HOME} ]]; then
        echo "Cannot continue, JAVA_HOME is not defined." >&2
        exit 1
    fi
    echo "Installing the US encryption strength policy files"
    # https://www.oracle.com/java/technologies/javase-jce8-downloads.html
    ( set -x
      ${SUDO} cp ${CDX_PROJECTS}/cdx-env-tools/host-configs/java/*.jar ${JAVA_HOME}/jre/lib/security
    )
    ls -l ${JAVA_HOME}/jre/lib/security/*.jar
fi

# --------------------------------------------------
# Maven setup

if [[ ${initMaven} == true ]]; then
    echo "Copying in the MS3 Maven settings"
    ( set -x
      cp ${CDX_PROJECTS}/cdx-env-tools/host-configs/~/.m2/settings.xml ~/.m2
    )
fi

# --------------------------------------------------
# Storage setup

if [[ ${initStorage} == true ]]; then
    echo "Initializing cdx-storage"
    ( set -x
      mkdir -p ${CDX_PROJECTS}/cdx-storage/oracle/oradata
      chmod o+w ${CDX_PROJECTS}/cdx-storage/oracle/oradata/
    )
fi

# --------------------------------------------------
# curl setup

if [[ ${initCurl} == true ]]; then
    if [[ -z ${CDX_CONFIGS} ]]; then
        echo "Cannot continue, CDX_CONFIGS is not defined." >&2
        exit 1
    fi
    source ${CDX_CONFIGS}/.pkirc
    echo Populating ~/.curlrc
    cat > ~/.curlrc <<EOF
# mTLS keystores
--cacert ${CDX_CONFIGS}/pki/cdx_cacerts.pem
--cert   ${CDX_CONFIGS}/pki/cdx_keystore.pem:${CDX_KEYSTORE_PASS}
EOF
fi

# --------------------------------------------------
# repo cloning

if [[ ${cloneDevops} == true ]]; then
    ( set -ex
      git clone -b main   git@github.com:fortytwobinary/k8s-configs.git 
      git clone -b main   git@github.com:fortytwobinary/configs.git 
    )
fi
if [[ ${cloneCommon} == true ]]; then
    if [[ -z ${MOPTS} ]]; then
        echo "Cannot continue, MOPTS is not defined." >&2
        exit 1
    fi
    ( set -ex
      git clone -b local https://bitbucket.org/navyfmp/cdx-configs.git
      git clone -b dev   https://bitbucket.org/navyfmp/cdx-data.git
      git clone -b dev   https://bitbucket.org/navyfmp/cdx-commons.git
      git clone -b dev   https://bitbucket.org/navyfmp/cdx-mule-domain.git
      git clone -b dev   https://bitbucket.org/navyfmp/cdx-hello-world.git
      each.sh -p common mvn clean install
      cd cdx-hello-world
      mvn clean package ${MOPTS}
    )
fi
if [[ ${cloneCdxMon} == true ]]; then
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/cdx-mon-db-sapi.git
      git clone -b dev https://bitbucket.org/navyfmp/cdx-mon-poller.git
      git clone -b dev https://bitbucket.org/navyfmp/cdx-mon-dashboard.git
    )
fi
if [[ ${cloneGinv} == true ]]; then
    # these apps currently use Domain 1.0.0
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/ginv-sapi.git
      cd ginv-sapi
      mvn clean package -Denv=local
    )
fi
if [[ ${cloneAdvana} == true ]]; then
    if [[ -z ${MOPTS} ]]; then
        echo "Cannot continue, MOPTS is not defined." >&2
        exit 1
    fi
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/advana-pull-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/advana-push-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/advana-sapi.git
      #each.sh -p advana mvn clean package ${MOPTS}
    )
fi
if [[ ${cloneSabrs} == true ]]; then
    # these apps currently use Domain 1.0.0
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-sapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-validation-api.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-papi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-legacy-soap.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-filedrop-client.git
      each.sh -p sabrs mvn clean package -Denv=local
    )
fi
if [[ ${cloneSabrsCb} == true ]]; then
    if [[ -z ${MOPTS} ]]; then
        echo "Cannot continue, MOPTS is not defined." >&2
        exit 1
    fi
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-cb-allo-sapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-cb-auth-sapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-cb-corr-sapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-cb-spen-sapi.git
      #each.sh -p sabrscb mvn clean package ${MOPTS}
    )
fi
if [[ ${cloneSabrsGl} == true ]]; then
    if [[ -z ${MOPTS} ]]; then
        echo "Cannot continue, MOPTS is not defined." >&2
        exit 1
    fi
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-gl-cycles-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-gl-index-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/sabrs-gl-cache-xapi.git
      #each.sh -p sabrsgl mvn clean package ${MOPTS}
    )
fi
if [[ ${cloneSmarts} == true ]]; then
    if [[ -z ${MOPTS} ]]; then
        echo "Cannot continue, MOPTS is not defined." >&2
        exit 1
    fi
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/smarts-active-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/smarts-fund-ctl-spend-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/smarts-reim-bill-code-xapi.git
      git clone -b dev https://bitbucket.org/navyfmp/smarts-reim-order-nbr-xapi.git
      #each.sh -p smarts mvn clean package ${MOPTS}
    )
fi
if [[ ${cloneSmartsLh} == true ]]; then
    if [[ -z ${MOPTS} ]]; then
        echo "Cannot continue, MOPTS is not defined." >&2
        exit 1
    fi
    ( set -ex
      git clone -b dev https://bitbucket.org/navyfmp/smarts-laborhist-trans-org-sapi.git
      git clone -b dev https://bitbucket.org/navyfmp/smarts-laborhist-trans-xapi.git
      #each.sh -p smartslh mvn clean package ${MOPTS}
    )
fi

if [[ ${yamlDeploy} == true ]]; then
    ( set -ex
      kubectl get deploy -n $1 -o yaml > dump-deploy.yaml
    )
fi

if [[ ${yamlService} == true ]]; then
    ( set -ex
      kubectl get svc -n $1 -o yaml > dump-service.yaml
    )
fi

if [[ ${yamlIngress} == true ]]; then
    ( set -ex
      kubectl get ingress -n $1 -o yaml > dump-ingress.yaml
    )
fi
