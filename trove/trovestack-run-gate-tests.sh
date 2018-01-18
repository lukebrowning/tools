#!/bin/bash

set -o pipefail

export TROVE_BRANCH=${TROVE_BRANCH:-"master"}
export PROJECT_BRANCH=${PROJECT_BRANCH:-"$TROVE_BRANCH"}

# The trove plugin to devstack is used which installs projects
# associated with services, however, trovestack gate testing
# assumes that trove is installed in /opt/stack/new, so make
# the default directory for all projects.

export DEST=/opt/stack/new

if [ "$1" == "--help" ]; then
    echo "Usage: trovestack-run-gate-tests.sh --help | [ --clean-only ] | [ --clean ] [ <db> ]"
    echo ""
    echo "All in one script to clean, install, and run gate tests [ FOR MYSQL ONLY PRESENTLY ]"
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

function setup() {
     grep zuul /etc/passwd >/dev/null 2>&1
     if [ $? != 0 ]; then
         sudo adduser --system --group --no-create-home zuul
         cat > 51_zuul << _EOF_
zuul ALL=(ALL) NOPASSWD:ALL
_EOF_
         sudo mv 51_zuul /etc/sudoers.d/
         sudo chown root:root /etc/sudoers.d/51_zuul
         sudo chmod 440 /etc/sudoers.d/51_zuul
     fi
}

function bak_file() {
    CMD=$1

    for i in ./trovestack-$CMD*.${TROVE_BRANCH//\//-}.out
    do
        if [ -e "$i" ]; then
            mv $i $i.bak
        fi
    done
}

function run_unittests() {
    pushd $DEST/trove > /dev/null 2>&1

    failed=False

    LOG=$BASEDIR/trovestack-gate-pep8.${TROVE_BRANCH//\//-}.out
    echo "####  Start pep8 test" | tee -a $LOG
    tox -e pep8 | tee -a $LOG
    rc=$?
    if [ $rc != 0 ]; then
        echo "####  Failed pep8 rc=$rc" | tee -a $LOG
        failed=True
    fi
    echo "####  Succeeded pep8" | tee -a $LOG

    LOG=$BASEDIR/trovestack-gate-py27.${TROVE_BRANCH//\//-}.out
    echo "####  Start py27 test" | tee -a $LOG
    tox -e py27 | tee -a $LOG
    rc=$?
    if [ $rc != 0 ]; then
        echo "####  Failed py27 rc=$rc" | tee -a $LOG
        failed=True
    fi
    echo "####  Succeeded py27" | tee -a $LOG

    LOG=$BASEDIR/trovestack-gate-py35.${TROVE_BRANCH//\//-}.out
    echo "####  Start py35 test" | tee -a $LOG
    tox -e py35 | tee -a $LOG
    rc=$?
    if [ $rc != 0 ]; then
        echo "####  Failed py35 rc=$rc" | tee -a $LOG
        failed=True
    fi
    echo "####  Succeeded py35" | tee -a $LOG

    if [ $failed == True ]; then
        exit 1
    fi

    popd > /dev/null 2>&1
}

DB=${2:-"mysql"}

if [[ "$1" =~ "--clean" ]]; then
    bak_file clean
    bak_file gate-install
    bak_file gate-stack
    if [ $DB == "mysql" ]; then
        bak_file gate-mysql-functional
    fi
    bak_file gate-$DB-supported-single
#    bak_file gate-$DB-supported-multi
    ./trovestack-run.sh --clean
    rm -f trovestack-progress.txt
    if [ "$1" == "--clean-only" ]; then
        exit 0
    fi
    shift
fi

setup

# Install trove and devstack with development patches
LOG=trovestack-gate-install.${TROVE_BRANCH//\//-}.out
./trovestack-run.sh --log=$LOG gate-install
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed ./trovestack-run.sh gate-install rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  $(date) Succeeded ./trovestack-run.sh gate-install" | tee -a $LOG

BASEDIR=$(pwd)

pushd $DEST/devstack

# Note passwords are hardcoded in trovestack so these can't be changed
cat > local.conf << _EOF_
[[local|localrc]]
DEST=/opt/stack/new
DATA_DIR=/opt/stack/new/data
TROVE_DIR=/opt/stack/new/trove
enable_plugin trove file:///opt/stack/new/trove
PYTHONUNBUFFERED=true
NETWORK_GATEWAY=10.1.0.1
USE_SCREEN=False
ACTIVE_TIMEOUT=90
BOOT_TIMEOUT=90
ASSOCIATE_TIMEOUT=60
TERMINATE_TIMEOUT=60
ADMIN_PASSWORD=passw0rd
INSTALL_TEMPEST=False
MYSQL_PASSWORD=e1a2c042c828d3566d0a
DATABASE_PASSWORD=e1a2c042c828d3566d0a
RABBIT_PASSWORD=f7999d1955c5014aa32c
SERVICE_TOKEN=be19c524ddc92109a224
SERVICE_PASSWORD=7de4162d826bc5a11ad9
SWIFT_HASH=12go358snjw24501
ENABLED_SERVICES=c-api,c-bak,c-sch,c-vol,cinder,dstat,etcd3,g-api,g-reg,heat,h-api,h-api-cfn,h-api-cw,h-eng,horizon,key,mysql,n-api,n-api-meta,n-cauth,n-cond,n-cpu,n-novnc,n-obj,n-sch,placement-api,q-agt,q-dhcp,q-l3,q-meta,q-metering,q-svc,rabbit,s-proxy,s-object,s-container,s-account,tr-api,tr-tmgr,tr-cond,trove

_EOF_

export BRIDGE_IP=10.1.0.1
export PATH_DEVSTACK_SRC=$DEST/devstack
export LOGFILE=$DEST/devstacklog.txt

LOG=$BASEDIR/trovestack-gate-stack.${TROVE_BRANCH//\//-}.out
echo "####  $(date) Invoke ./stack.sh" | tee -a $LOG
echo "####  Use tail -f $LOGFILE to see progress in another window" | tee -a $LOG
./stack.sh >> $LOG 2>&1
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed ./stack.sh rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  $(date) Succeeded ./stack.sh" | tee -a $LOG

pushd $DEST/trove/integration/scripts

LOG=$BASEDIR/trovestack-gate-mysql-functional.${TROVE_BRANCH//\//-}.out
echo "####  Start legacy-trove-functional-dsvm-mysql" | tee -a $LOG
./trovestack dsvm-gate-tests mysql 2>&1 | tee -a $LOG
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed legacy-trove-functional-dsvm-mysql rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  Succeeded legacy-trove-functional-dsvm-mysql" | tee -a $LOG

LOG=$BASEDIR/trovestack-gate-mysql-supported-single.${TROVE_BRANCH//\//-}.out
echo "####  Start legacy-trove-scenario-dsvm-mysql-single" | tee -a $LOG
./trovestack dsvm-gate-tests mysql mysql-supported-single 2>&1 | tee -a $LOG
rc=$?
if [ $rc != 0 ]; then
    echo "####  Failed legacy-trove-scenario-dsvm-mysql-single rc=$rc" | tee -a $LOG
    exit 1
fi
echo "####  Succeeded legacy-trove-scenario-dsvm-mysql-single" | tee -a $LOG

# Uncomment the following line to run unit tests: pep8, py27, py35, ...
# run_unittests
