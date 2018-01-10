Test and debug trove development patches before upstreaming
===========================================================

The scripts run by the user are trovestack-run-gate-tests.sh
and trovestack-run-int-tests.sh which respectively run OpenStack
Trove gate tests and Trove Integration tests.  They invoke
trovestack-run.sh which contains code for patching several
OpenStack projects including trove, diskimage-builder,
devstack, requirements, ... with user provided patches.

The basic development process is shown below.

Note:  if there are no development patches and you
just want to test the upstream code as is, then skip step 1.
You will need to apply the trove-localrc.patch in step 2.

1) transfer patch from gerrit to local machine and place
   them in ~/patches/master

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

   It is necessary to specify --clean between invocations
   assuming one gets beyond the cloning and patching step
   which occurs in the beginning.  Code is placed in
   /opt/stack/ or /opt/stack/new depending on whether one
   runs integration or gate tests.

Debug
-----

log files are generated.

One can exercise Trove through the OpenStack GUI by attaching
a browser to the local host's IP address.  For example,
http://x.x.x.x/dashboard. The default users are admin and
demo.  The password is 'passw0rd'.

Sometimes when a test fails the guest images are still present
and are visible through the browser.  In this case, the datastore
instance detail tab may contain a stack traceback.

One can also log into the guest datastore - ssh ubuntu@y.y.y.y
from the localhost.  There is no password.
