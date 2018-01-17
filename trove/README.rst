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

Note:  if there are no development patches and you
just want to test the upstream code as is, then skip step 1.
You will need to apply the trove-localrc.patch in step 2.

1) transfer patch from gerrit to local machine and place
   them in **./patches/master**

2) re-generate your Trove patch with a small change provided
   in the patches directory::

     X=~/gerritpatch.diff

     git clone git://github.com/openstack/trove /tmp/trove
     cd /tmp/trove
     patch -p1 < $X
     patch  p1 < ~/patches/master/trove-localrc.patch
     git diff > ~/patches/master/trove.patch
     rm -rf /tmp/trove

     If the trove-localrc.patch does not apply cleaning
     then you should re-clone and manually make the code
     change.  It is a very small code change.

3) run trovestack-run-gate-tests.sh or trovestack-run-int-tests.sh

   Specify --help for command arguments

   It is necessary to specify **--clean** between invocations
   assuming one gets beyond the cloning and patching step
   which occurs in the beginning.  Code is placed in
   /opt/stack/ or /opt/stack/new depending on whether one
   runs integration or gate tests.


Debug
-----

Log files are generated -- trovestack-int-tests-mysql.master.out

One can exercise Trove through the OpenStack GUI by attaching
a browser to the local host's IP address.  For example,
http://x.x.x.x/dashboard. The default users are admin and
demo.  The password is 'passw0rd'.

Sometimes when a test fails the guest images are still present
and are visible through the browser.  In this case, the datastore
instance detail tab may contain a stack traceback.

One can also log into the guest datastore - ssh ubuntu@y.y.y.y
from the localhost.  There is no password.


Erratic Results
---------------

Devstack provides unstack and clean scripts to reset the environment
so that tests may be run again.  However, it has been observed
that everything does not always get cleaned and devstack often
fails when it is re-run.  This is not an issue for Trove gate
testing as these are generally one time use environments.

The scripts provided by this project provide **--clean** and **--clean-only**
command arguments to improve the determinism and consistency of development
and testing.  The clean logic is hardcoded to deal with specific elements that
have been observed to escape the underlying devstack functions.  The clean
logic is a continual work in progress as the master branch changes daily.
The clean-only option enables the user to perform manual cleanup.

After running clean-only, the user should run the following commands to
identify additional elements that should be manually cleaned before re-testing:

  > sudo systemctl status
  > ps -edf
  > df -h
  > pip list

Look for items located in **/opt/stack** or associated with **devstack**.
