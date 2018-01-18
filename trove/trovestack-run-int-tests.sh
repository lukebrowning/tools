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
    echo "All in one script to install, kickstart db, and run integrations tests for <db>."
    echo ""
    echo "The list of supported databases is defined by the trove project - mysql, mongodb,"
    echo "percona, redis, postgresql, cassandra, couchbase, db2, and vertica.  The default"
    echo "database is mysql."
    echo ""
    echo "The --clean argument unstacks devstack and allows one to re-start the install, stack,"
    echo "and test process again.  The clean-only argument unstacks and exits."
    echo ""
    echo "The following environment variables apply to trove and devstack projects respectively."
    echo ""
    echo 'export TROVE_BRANCH=${TROVE_BRANCH:-master}'
    echo 'export PROJECT_BRANCH=${PROJECT_BRANCH:-"$TROVE_BRANCH"}'
    echo ""
    echo "Notes:"
    echo ""
    echo "1) the only supported branches are stable/ocata and master"
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

LOG=trovestack-install.${TROVE_BRANCH//\//-}.out
./trovestack-run.sh --log=$LOG install
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed ./trovestack-run.sh install rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  $(date) Succeeded ./trovestack-run.sh install" | tee -a $LOG

LOG=trovestack-kick-start-$DB.${TROVE_BRANCH//\//-}.out
./trovestack-run.sh --log=$LOG kick-start $DB
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed ./trovestack-run.sh kick-start rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  $(date) Succeeded ./trovestack-run.sh kick-start" | tee -a $LOG

LOG=trovestack-int-tests-$DB.${TROVE_BRANCH//\//-}.out
./trovestack-run.sh --log=$LOG int-tests
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed ./trovestack-run.sh int-tests rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  $(date) Succeeded ./trovestack-run.sh int-tests" | tee -a $LOG

