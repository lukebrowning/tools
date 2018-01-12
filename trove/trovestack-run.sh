#!/bin/bash

set -o pipefail

export DEST=${DEST:-"/opt/stack"}
export PATH_DEVSTACK_SRC=${PATH_DEVSTACK_SRC:-$DEST/devstack}
export TROVE_BRANCH=${TROVE_BRANCH:-"master"}
export PROJECT_BRANCH=${PROJECT_BRANCH:-$TROVE_BRANCH}

# Hardcoded values in trovestack.rc.  These cannot be changed
export ADMIN_PASSWORD=passw0rd
export MYSQL_PASSWORD=e1a2c042c828d3566d0a
export DATABASE_PASSWORD=e1a2c042c828d3566d0a
export RABBIT_PASSWORD=f7999d1955c5014aa32c
export SERVICE_TOKEN=be19c524ddc92109a224
export SERVICE_PASSWORD=7de4162d826bc5a11ad9
export SWIFT_HASH=12go358snjw24501

if [ "$1" == "--help" ]; then
    echo "Usage: trovestack-run.sh [ --clean ] [--log=xxx ] install"
    echo "       trovestack-run.sh [--log=xxx ] kick-start <db>"
    echo "       trovestack-run.sh [--log=xxx ] int-tests"
    echo ""
    echo "This script is a passthru to 'trovestack' script, so the same command arguments"
    echo "apply, meaning some command arguments are not listed above.  The clean command"
    echo "argument is an exception.  It does not result in a call to 'trovestack'."
    echo ""
    echo "This tool carries patches per branch which are applied when projects are git cloned"
    echo ""
    echo "./patches/\$TROVE_BRANCH/trove.patch"
    echo "./patches/\$PROJECT_BRANCH/devstack.patch"
    echo ""
    echo "The following environment variables apply to trove and devstack projects respectively"
    echo ""
    echo 'export TROVE_BRANCH=${TROVE_BRANCH:-"master"}'
    echo 'export PROJECT_BRANCH=${PROJECT_BRANCH:-"$TROVE_BRANCH"}'
    echo ""
    echo "Notes:"
    echo ""
    echo "1) the only supported branches are stable/ocata and master"
    echo "2) 'trovestack-run.sh clean' must be run before changing the environment variables above"
    echo ""
    echo "To run:"
    echo ""
    echo "./trovestack-run.sh --log=trovestack-install.${TROVE_BRANCH//\//-}.out install"
    echo "./trovestack-run.sh --log=trovestack-kick-start-mysql.${TROVE_BRANCH//\//-}.out kick-start mysql"
    echo "./trovestack-run.sh --log=trovestack-int-tests-mysql.${TROVE_BRANCH//\//-}.out int-tests"
    echo ""
    echo "To clean up:"
    echo ""
    echo "./trovestack-run.sh clean"
    echo ""
    exit 0
fi

echo "####  $0 $@"

ARCH=$(dpkg --print-architecture)
if [[ $ARCH =~ "ppc64" ]]; then
    if [ ! -e /sys/module/kvm ]; then
        sudo modprobe -b kvm
    fi
    if [ ! -e /sys/module/kvm_pr ]; then
        sudo modprobe -b kvm_pr
    fi
    if [ ! -e /sys/module/kvm_pr ]; then
        echo "A kernel supporting nested virtualization must be loaded!"
        echo "sudo apt-get install linux-generic-hwe-16.04"
        echo "reboot"
        exit 1
    fi
fi

STAGE_FILE=$(pwd)/trovestack-progress.txt

if [ "$1" == "--clean" ]; then

    LOG=$(pwd)/trovestack-clean.${TROVE_BRANCH//\//-}.out

    if [ -d /home/ubuntu/images/ ]; then
        rm -rf /home/ubuntu/images
    fi

    LASTDEVSTACK=/opt/stack/new/devstack
    if [ -d "$LASTDEVSTACK" ]; then
        LASTDEST=/opt/stack/new
    else
        LASTDEVSTACK=/opt/stack/devstack
        if [ ! -d "$LASTDEVSTACK" ]; then
            LASTDEVSTACK=$DEST/devstack
            LASTDEST=$DEST
        else
            LASTDEST=/opt/stack
        fi
    fi

    pushd $LASTDEVSTACK >/dev/null 2>&1
    ./unstack.sh 2>&1 | tee $LOG
    popd >/dev/null 2>&1

    echo "####  Stopping services" | tee -a $LOG
    sudo systemctl stop devstack@tr-tmgr.service 2>&1 | tee -a $LOG
    sudo systemctl stop devstack@tr-cond.service 2>&1 | tee -a $LOG
    sudo systemctl stop devstack@n-cond.service 2>&1 | tee -a $LOG
    sudo systemctl stop devstack@peakmem_tracker.service 2>&1 | tee -a $LOG
    sudo systemctl stop devstack@q-l3.service 2>&1 | tee -a $LOG
    sudo systemctl stop system-devstack.slice 2>&1 | tee -a $LOG
    sudo systemctl stop rabbitmq-server 2>&1 | tee -a $LOG
    sudo systemctl stop apache2 2>&1 | tee -a $LOG

    pushd $LASTDEVSTACK >/dev/null 2>&1
    ./clean.sh 2>&1 | tee -a $LOG
    popd >/dev/null 2>&1

    if [ -f $LASTDEST/data/swift/drives/images/swift.img ]; then
        sudo umount $LASTDEST/data/swift/drives/images/swift.img
    fi

    echo "####  Killing OpenStack processes sleeping on sockets" | tee -a $LOG
    PROCS=$(lsof -iTCP -sTCP:LISTEN | grep ubuntu | grep -e glance -e neutron -e nova -e swift -e trove -e cinder | awk '{print $2}')
    if [ -n "$PROCS" ]; then
        echo "Found $PROCS" | tee -a $LOG
        echo $PROCS | xargs kill
    fi

    echo "####  Uninstalling pip modules"
    echo 'y' >/tmp/y.$$
    sudo -H pip uninstall amqp 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall cliff 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall cursive 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall cryptography 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall dib-utils 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall diskimage-builder 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall django 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall django-babel 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall django-openstack-auth 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall django-nose 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall etcd3 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall etcd3gw 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall flake8 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall flake8-docstrings 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall flake8-import-order 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall glance-store 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall jsonschema 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall keystoneauth1 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall keystonemiddleware 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall kombu 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall openstack.nose-plugin 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall openstackdocstheme 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall openstacksdk 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.cache 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.concurrency 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.config 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.context 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.db 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.i18n 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.log 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.messaging 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.middleware 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.policy 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.privsep 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.reports 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.rootwrap 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.serialization 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.service 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.utils 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.versionedobjects 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslo.vmware 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslosphinx 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall oslotest 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall os-client-config 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall os-vif 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall os-xenapi 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall networkx 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall neutron-lib 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall pbr 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall ptyprocess 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall pypowervm 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-barbicanclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-cinderclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-designateclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-glanceclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-heatclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-ironicclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-keystoneclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-mistralclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-neutronclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-novaclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-openstackclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-swiftclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall python-troveclient 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall Sphinx 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall tooz 2>&1 </tmp/y.$$ | tee -a $LOG
    sudo -H pip uninstall trove 2>&1 </tmp/y.$$ | tee -a $LOG
    rm -f /tmp/y.$$

    sudo rm -rf /usr/local/share/diskimage-builder
    sudo rm -f /etc/trove/*
    sudo rm -f /usr/local/bin/trove*
    sudo rm -rf /opt/stack/*

    rm -f $STAGE_FILE
    rm -f .my.cnf

    echo "####  Killing any remaining detached screen sessions" | tee -a $LOG
    PROCS=$(screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}')
    if [ -n "$PROCS" ]; then
        echo "Found $PROCS" | tee -a $LOG
        echo $PROCS | xargs kill
    fi
    screen -wipe 2>&1 | tee -a $LOG

    echo "####  Remove OpenStack lvm vgs" | tee -a $LOG 
    VGS=$(sudo vgs | grep "stack-volumes" | awk '{print $1}')
    if [ -n "$VGS" ]; then
        echo "Found $VGS" | tee -a $LOG
        for i in $VGS
        do
            sudo lvremove -f $i 2>&1 | tee -a $LOG
            echo "lvremove rc=$?" | tee -a $LOG
            sudo vgremove -f $i 2>&1 | tee -a $LOG
            echo "vgremove rc=$?" | tee -a $LOG
        done
    fi

    echo "####  Detach remaining OpenStack loop devices attached from $LASTDEST" | tee -a $LOG
    LOOPS=$(losetup -a | grep "$DEST" | awk '{print substr($1, 1, length($1)-1)}')
    if [ -n "$LOOPS" ]; then
        echo "Found $LOOPS" | tee -a $LOG
        for i in $LOOPS
        do
            sudo losetup -d $i 2>&1 | tee -a $LOG
            echo "losetup rc=$?" | tee -a $LOG
        done
    fi

    echo "####  Umount remaining OpenStack loop devices attached from $LASTDEST" | tee -a $LOG
    MNTS=$(df -h | grep "$LASTDEST" | awk '{print $6}')
    if [ -n "$MNTS" ]; then
        echo "Found $MNTS" | tee -a $LOG
        for i in $MNTS
        do
            sudo umount $i 2>&1 | tee -a $LOG
        done
    fi

    echo "####  List processes sleeping on sockets" | tee -a $LOG
    sleep 1
    RUNNING=$(lsof -iTCP -sTCP:LISTEN)
    if [ -n "$RUNNING" ]; then
        echo "####  Please try to kill the remaining processes manually.  You may not need to kill them all." | tee -a $LOG
        lsof -iTCP -sTCP:LISTEN 2>&1 | tee -a $LOG
        exit 1
    fi
    shift
fi

LOG=""
if [[ "$1" =~ "--log=" ]]; then
    LOG=$(pwd)/${1##--log=}
    shift
fi

CMD="$1"

if [ -z "$CMD" ]; then
    # Must have been a --clean by itself
    exit 0
fi

if [ "$CMD" == "kick-start" ]; then
    DB=${2:-"mysql"}
else
    DB=""
fi

if [ -z "$LOG" ]; then
    if [ -z "$DB" ]; then
        LOG=trovestack-$CMD.${TROVE_BRANCH//\//-}.out.$$
    else
        LOG=trovestack-$CMD-$DB.${TROVE_BRANCH//\//-}.out.$$
    fi
fi

echo "####  TROVE_BRANCH=$TROVE_BRANCH" | tee -a $LOG
echo "####  PROJECT_BRANCH=$PROJECT_BRANCH" | tee -a $LOG
echo "####  LOG=$LOG" | tee -a $LOG
echo "####  CMD=$CMD" | tee -a $LOG
echo "####  DB=$DB" | tee -a $LOG
echo "####  $0 $@" | tee -a $LOG

export DEFAULT_INSTANCE_TYPE=m1.small
export USE_UUID_TOKEN=True
export GIT_TIMEOUT=300             # 5 minutes

export DIB_DEBUG_TRACE=1
export DIB_NO_TMPFS=1
export REBUILD_IMAGE=True

# A bug in trovestack requires diskimage-builder to be installed as a python module.
# Trove doesn't invoke diskimage-builder from a python module.  The 1.26.1 version
# comes from openstack/requirements/upper-constraints.txt, so we pre-install the
# version that will be installed by devstack

if [ "$TROVE_BRANCH" == "stable/ocata" ]; then
    export TEMPEST_BRANCH=17.0.0
    export DISKIMAGE_BUILDER_BRANCH=1.26.1
    export DISKIMAGE_BUILDER_PIP_VERSION=1.26.1
else
    export TEMPEST_BRANCH=master
    export DISKIMAGE_BUILDER_BRANCH=master
    export DISKIMAGE_BUILDER_PIP_VERSION=2.9.0

    export ETCD_VERSION=v3.2.7
    PKG=$(dpkg --print-architecture)
    if [ "$PKG" == "amd64" ]; then
        export ETCD_SHA256=f4e7a282eed333bb6c00eaad2644d17d23e111953e19e4fab1fc390249d6353a
    else
        export ETCD_SHA256=47fd1f0b1185778777b1baa2d5eec58dc90409e7892f2614da396f62619ec3e3
    fi
fi

export PATH_DISKIMAGEBUILDER=$DEST/diskimage-builder
export DIB_REPO=$PATH_DISKIMAGEBUILDER
export DIB_BRANCH=$DISKIMAGE_BUILDER_BRANCH

export PATH_TRIPLEO_ELEMENTS=$DEST/tripleo-image-elements
export TRIPLEO_IMAGE_ELEMENTS_BRANCH=$TROVE_BRANCH

export PATH_TROVE_DASHBOARD=$DEST/trove-dashboard
export TROVE_DASHBOARD_BRANCH=$TROVE_BRANCH

export PATH_PYTHON_TROVECLIENT=$DEST/python-troveclient
export TROVE_CLIENT_DIR=PATH_PYTHON_TROVECLIENT
export PYTHON_TROVECLIENT_BRANCH=$TROVE_BRANCH

function stage_complete {
    STAGE=$1

    echo "STAGE=$STAGE"

    if [ -e ${STAGE_FILE} ] && (grep $STAGE-${TROVE_BRANCH//\//-} ${STAGE_FILE} >/dev/null) ; then
        return 0
    else
        return 1
    fi
}

function record_success {
    STAGE=$1

    # Always allow integration test to be re-run
    if [ "$STAGE" == "init-tests" ]; then
        return
    fi

    if stage_complete $STAGE ; then
        echo "####  Stage '$STAGE' already completed." | tee -a $LOG
    else
        echo "$STAGE-${TROVE_BRANCH//\//-}" >> ${STAGE_FILE}
    fi
}


function checkout_proj() {
    BRANCH=$1

    TAG=$(git tag -l $BRANCH)
    if [ -n "$TAG" ]; then
        git checkout -B branch-$BRANCH $BRANCH
    else
        git checkout $BRANCH
    fi
    return $?
}

function clone_proj() {
    GITPROJECT=$1
    BRANCH=$2
    PATCH=$3

    PROJECT=${GITPROJECT##*/}
    PATCH=$(pwd)/patches/$BRANCH/$PROJECT.patch

    if [ ! -e $DEST ]; then
        sudo mkdir -p $DEST
        sudo chown -R ubuntu:ubuntu /opt/stack
    fi

    if [ -e "$PATCH" ] || [ "$PROJECT" == "trove" ] || [ "$CMD" == "gate-install" ]; then
        if [ ! -d $DEST/$PROJECT ]; then
            echo "####  Cloning $PROJECT" | tee -a $LOG
            pushd $DEST 2>&1 >/dev/null
            git clone http://github.com/$GITPROJECT $PROJECT
            if [ $? != 0 ]; then
                echo "####  git clone $PROJECT failed!" | tee -a $LOG
                exit 1
            fi
            pushd $PROJECT 2>&1 >/dev/null
            echo "####  Checking out $PROJECT $BRANCH" | tee -a $LOG
            checkout_proj $BRANCH
            if [ $? != 0 ]; then
                echo "####  git checkout $PROJECT $BRANCH failed!" | tee -a $LOG
                exit 2
            fi
            if [ -e $PATCH ]; then
                local CMD=patch-$PROJECT
                if ! stage_complete $CMD ; then
                    echo "####  Applying $PROJECT $PATCH" | tee -a $LOG
                    patch -p1 < $PATCH
                    if [ $? != 0 ]; then 
                        echo "####  Patch $PROJECT failed!" | tee -a $LOG
                        exit 3
                    fi
                    record_success $CMD
                    if [ "$PROJECT" == "trove" ]; then
                        find $DEST/trove/integration/scripts/files/elements -type f \( ! -iname "element-deps" -and ! -iname "README.*" \) -exec chmod 755 {} \;
                    fi
                fi
            fi
            popd 2>&1 >/dev/null
            popd 2>&1 >/dev/null
        fi
    fi
}

type git >/dev/null 2>&1
if [ $? != 0 ]; then
    sudo apt-get -y install git
fi

type pip >/dev/null 2>&1
if [ $? != 0 ]; then
    sudo apt-get -y install python-dev python-setuptools python-pexpect python-pip
    sudo apt-get -y install python3-dev python3-setuptools python3-pexpect python3-pip
fi

echo 'y' >/tmp/y.$$

if ! stage_complete $CMD ; then

    if [[ "$CMD" =~ "install" ]]; then                       # CMD = install | gate-install

        clone_proj openstack/trove $TROVE_BRANCH trove.patch
        clone_proj openstack/trove-dashboard $TROVE_DASHBOARD_BRANCH trove-dashboard.patch
        clone_proj openstack/python-troveclient $PATH_PYTHON_TROVECLIENT python-troveclient.patch
        clone_proj openstack/requirements $PROJECT_BRANCH requirements.patch
        clone_proj openstack/tripleo-image-elements $TRIPLEO_IMAGE_ELEMENTS_BRANCH tripleo-image-elements.patch
        clone_proj openstack-dev/devstack $PROJECT_BRANCH devstack.patch
        clone_proj openstack/diskimage-builder $DISKIMAGE_BUILDER_BRANCH diskimage-builder.patch

        # Install the openstack/requirements version to satisfy pip -c upper-constraints
        # requirements during the install step.  DIB is not invoked until kick-start command
        #
        # Note: DIB is installed by trovestack and it is a prerequisite to trovestack.  It should
        #       not be the latter.  It didn't used to be a prererequisite and the documentation does
        #       not indicate that it is a prerequisite, so this is a recent bug
        #
        # Code below re-installs the DIB python module from the git repo during the kick-start
        # phase if the git repo was patched.  The reason this is not done during the install step
        # is that it would fail the upper-constraints test at the end of the install phase.  The
        # version of the dib module that is installed from the git repo has 'dev' in it.
        sudo -H pip install diskimage-builder==$DISKIMAGE_BUILDER_PIP_VERSION < /tmp/y.$$ >/dev/null 2>&1

        if [[ "$CMD" =~ "gate" ]]; then
            pushd $DEST/trove >/dev/null 2>&1
            python setup.py build
            sudo python setup.py install
            popd >/dev/null 2>&1

            pushd $DEST/python-troveclient >/dev/null 2>&1
            python setup.py build
            sudo python setup.py install
            popd >/dev/null 2>&1
        fi

    elif [ "$CMD" == "kick-start" ]; then 

        # Fix the python module for diskimage-builder if we have a patch for it.  See above
        LCMD=patch-diskimage-builder
        if stage_complete $LCMD ; then
            echo "####  diskimage-builder is patched.  Re-load the python module from the git repo" | tee -a $LOG
            sudo -H pip uninstall diskimage-builder </tmp/y.$$ >/dev/null 2>&1
            sudo -H pip install $PATH_DISKIMAGEBUILDER </tmp/y.$$ >/dev/null 2>&1
            record_success $LCMD
        fi

        # Kickstart is implemented below.  This section just performed an extra install.  Add in DB
        CMD=$CMD-$DB
    fi
fi

rm -f /tmp/y.$$

if [[ "$CMD" =~ "gate" ]]; then
    record_success $CMD
    exit 0 
fi

rc=0

if ! stage_complete $CMD ; then
    pushd $DEST/trove/integration/scripts

    # The output of the install command below is not piped to tee as with the other commands, because
    # the tee process never exits.  This is probably due to daemons that are started in the install phase
    # with the assumption that the daemons are inheriting stdout from the install process.  tee won't
    # exit until the shared stdout file descriptor is closed, so don't use tee for install.

    if [ "$CMD" == "install" ]; then
        echo "####  $(date) trovestack $@ >> $LOG 2>&1" | tee -a $LOG
        echo "####  Use tail -f $LOG to see progress in another window" | tee -a $LOG
        ./trovestack $@ >> $LOG 2>&1
        rc=$?
    else
        echo "####  $(date) trovestack $@" | tee -a $LOG
        ./trovestack $@ 2>&1 | tee -a $LOG
        rc=$?
    fi

    echo "####  trovestack rc=$rc" | tee -a $LOG
    if [ $rc == 0 ]; then
        record_success $CMD
    fi

    popd
fi

exit $rc
