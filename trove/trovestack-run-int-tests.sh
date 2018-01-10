#!/bin/bash

set -eo pipefail

export TROVE_BRANCH=${TROVE_BRANCH:-"master"}
export PROJECT_BRANCH=${PROJECT_BRANCH:-"$TROVE_BRANCH"}

export TROVE_CLIENT_BRANCH=$TROVE_BRANCH
export PYTHON_TROVECLIENT_BRANCH=$TROVE_BRANCH
export TROVE_DASHBOARD_BRANCH=$TROVE_BRANCH

export CINDERCLIENT_BRANCH=$PROJECT_BRANCH
export BRICK_CINDERCLIENT_BRANCH=$PROJECT_BRANCH
export GLANCECLIENT_BRANCH=$PROJECT_BRANCH
export IRONICCLIENT_BRANCH=$PROJECT_BRANCH
export KEYSTONEAUTH_BRANCH=$PROJECT_BRANCH
export KEYSTONECLIENT_BRANCH=$PROJECT_BRANCH
export NEUTRONCLIENT_BRANCH=$PROJECT_BRANCH
export SWIFTCLIENT_BRANCH=$PROJECT_BRANCH
export OPENSTACKCLIENT_BRANCH=$PROJECT_BRANCH

export PYTHON_NEUTRONCLIENT_BRANCH=$PROJECT_BRANCH


if [ "$1" == "--help" ]; then
    echo "Usage: trovestack-run-int-tests.sh --help | [ --clean-only ] | [ --clean ] [ <db> ]"
    echo ""
    echo "All in one script to install, kickstart db, and run integrations tests"
    echo ""
    echo "The clean script unstacks devstack and allows one to start the install process over again"
    echo ""
    echo "The following environment variables apply to trove and devstack projects respectively"
    echo ""
    echo 'export TROVE_BRANCH=${TROVE_BRANCH:-master}'
    echo 'export PROJECT_BRANCH=${PROJECT_BRANCH:-"$TROVE_BRANCH"}'
    echo ""
    echo "Notes:"
    echo ""
    echo "1) the only supported branches are stable/ocata and master"
    echo "2) the only database presently enabled is mysql"
    exit 0
fi

function bak_file() {
    CMD=$1

    for i in ./trovestack-$CMD*.${TROVE_BRANCH//\//-}.out
    do
        if [ -e "$i" ]; then
            mv $i $i.bak
        fi
    done
}

if [[ "$1" =~ "--clean" ]]; then
    bak_file clean
    bak_file install
    bak_file kick-start
    bak_file int-tests
    ./trovestack-run.sh --clean
    if [ "$1" == "--clean-only" ]; then
        exit 0
    fi
    shift
fi

DB=${1:-"mysql"}

./trovestack-run.sh --log=trovestack-install.${TROVE_BRANCH//\//-}.out install
./trovestack-run.sh --log=trovestack-kick-start-$DB.${TROVE_BRANCH//\//-}.out kick-start $DB
./trovestack-run.sh --log=trovestack-int-tests-$DB.${TROVE_BRANCH//\//-}.out int-tests

