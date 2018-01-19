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

     X=~/devpatch.diff

     git clone git://github.com/openstack/trove /tmp/trove
     cd /tmp/trove
     patch -p1 < $X
     patch  p1 < patches/master/trove-localrc.patch
     git diff > patches/master/trove.patch
     rm -rf /tmp/trove

   If the trove-localrc.patch does not apply properly,
   then you should re-clone trove, apply your patch, and then
   manually make the code change associated with the
   broken patch.  It is a very small code change.  Don't
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

Log files are generated -- trovestack-int-tests-mysql.master.out

One can exercise Trove through the OpenStack GUI by attaching
a browser to the local host's IP address.  For example,
http://x.x.x.x/dashboard. The default users are admin and
demo.  The password is 'passw0rd'.

Sometimes when a test fails the guest images are still present
and are visible through the browser.  In this case, the datastore
instance detail tab may show the stack traceback of the error.
You may have to change the project (**alt_demo**) to see this.

If the failing datastore instances are not present, they were
probably deleted by the test framework.  In this case, the error
may be recreatable through the GUI.  Try to create the datastore
manually, create databases and users, delete them, etc.

At this point, you should be able to log into the instance
and examine the trove log file /var/log/trove/trove-guestagent.log.
Similarly, you can manually start and stop the database using
the command systemctl start/stop <database>.  The user is 'ubuntu'.
There is no password.

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
