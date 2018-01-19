Test and debug trove development patches before upstreaming
===========================================================

The scripts run by users are **trovestack-run-gate-tests.sh**
and **trovestack-run-int-tests.sh**, which respectively run OpenStack
Trove gate tests and Trove Integration tests.  They invoke
the internal script trovestack-run.sh which does the git cloning
and patching of key projects.  This allows the user to develop
and test his changes before upstreaming them.

The OpenStack projects that can be patched are
**trove, trove-dashboard,
python-troveclient, tripleo-image-elements, diskimage-builder,
devstack and requirements**.

The basic development process is shown below.

1) transfer patches to be tested to the local machine.  Patches 
   should be placed in patches/master/<project>.patch, where project is
   one of the patchable projects identified above.  If you are providing
   a trove patch, then it must be combined with a patch provided by
   this toolset in step 2.

   If there are no development patches and you just want to test
   the master branch, then skip to step 3.

2) re-generate your Trove patch with a small change provided
   in the patches directory::

     X=~/devpatch.diff     # This is your trove dev patch

     git clone git://github.com/openstack/trove /tmp/trove
     cd /tmp/trove
     patch -p1 < $X
     patch  p1 < patches/master/trove-localrc.patch
     git diff > patches/master/trove.patch
     rm -rf /tmp/trove

   If the trove-localrc.patch does not apply properly,
   then you should re-clone trove, apply your patch, and then
   manually make the code change associated with the
   broken patch.  It is a very small code change (1 line).  Don't
   forget to save the patch to patches/master/trove.patch!

3) run trovestack-run-gate-tests.sh or trovestack-run-int-tests.sh

   Usage: **trovestack-run-int-tests.sh** --help | [ --clean-only ] | [ --clean ] [ <db> ]

   Usage: **trovestack-run-gate-tests.sh** --help | [ --clean-only ] | [ --clean ] [ <db> ]

   All in one scripts to install, stack, create the db image, and run integration or gate tests for <db>.

   The list of supported databases is defined by the trove project - mysql, mongodb,
   percona, redis, postgresql, cassandra, couchbase, db2, and vertica.  The default
   database is mysql.

   The **--clean** argument unstacks devstack and allows one to re-start the install, stack,
   and test process again.  The specified database is tested.  The **--clean-only** argument
   unstacks and exits.

   The following environment variables apply to trove and devstack projects respectively::

     > export TROVE_BRANCH=${TROVE_BRANCH:-master}
     > export PROJECT_BRANCH=${PROJECT_BRANCH:-"$TROVE_BRANCH"}

   The only supported branches are stable/ocata and master

Debug
-----

The scripts capture standard output in log files which end 
in '.out'. The clean commands copy the current set of log files
to a new file that ends with '.bak'.  This allows you to compare
the last two runs.  It is only two deep though, so you may 
want to preserve results before they are copied over.

This is the sequence of files produced for integration tests:

1. trovestack-install.master.out
2. trovestack-kick-start-<db>.master.out
3. trovestack-int-tests-<db>.master.out

This is the sequence for gate tests:

1. trovestack-gate-install.master.out
2. trovestack-gate-stack.master.out
3. trovestack-gate-<db>-functional.master.out
4. trovestack-gate-<db>-supported-single.master.out

Once devstack is running, you can connect to the OpenStack
GUI using your browser::

  > http://x.x.x.x/dashboard
  > The default users are admin and demo.
  > The password is 'passw0rd'.

x.x.x.x is your test victim.  It should have at least 48 GBs of RAM and 80 GBs of storage.

Sometimes you can see the failure in the browser by examining the
stack tracebook of the datastore instance.  You may have to change
the project (**alt_demo**) in the GUI to see this.

If the failing datastore instances are not present, they were
probably deleted by the test framework.  If this happens, you
may be able to recreate the error using the GUI.  Try to create
a datastore instance, databases, users, delete them, etc.

During this process, you should be able to connect to the
instance which allows you to examine the trove-guestagent.log and 
database log files.  Start the database, stop it, etc.

To login into the datastore::

  > ssh ubuntu@y.y.y.y
  > there is no password

Erratic Results
---------------

Devstack provides unstack and clean scripts to reset the environment
so that tests may be run again.  However, it has been observed
that everything does not always get cleaned and devstack often
fails when it is re-run.  This is not an issue for Trove gate
testing as these are generally only run once and then the VM is discarded.

The scripts provided by this project provide **--clean** and **--clean-only**
command arguments to improve the determinism and repeatability of development
and testing.  The clean logic is hardcoded to deal with specific elements that
have been observed to escape the underlying devstack functions.  The clean
logic is a continual work in progress as the master branch changes daily.
The clean-only option enables the user to perform manual cleanup.

After running clean-only, the user should run the following commands to
identify additional elements that should be manually cleaned before re-testing::

  > sudo systemctl status
  > ps -edf
  > df -h
  > pip list

Look for items located in **/opt/stack** or associated with **devstack**.
