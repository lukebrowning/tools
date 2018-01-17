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

Sometimes **--clean** does not remove everything that was created
during the last run which leads to failures or erratic results.  This
is an ongoing challenge working with the master branch of projects
as change is the rule rather then the exception.  The clean logic
is hardcoded to remove items that have been observed through trial
and error as not being properly addressed by devstack's unstack
and clean scripts.  This is not a problem for gate testing as devstack
is not used more than once, but here we would like to be able to run
trove integration and gate tests multiple times in a row without
re-installing the VM.

The best way to maintain a reusable environment is to run **--clean-only**
periodically and to manually clean the environment.  Here are some commands
to run that help show the state of things:

  > sudo systemctl status
  > ps -edf
  > df -h

Look for items placed in **/opt/stack** or associated with **devstack**.
