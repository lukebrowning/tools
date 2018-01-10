Test and debug trove development patches before upstreaming
===========================================================

trovestack-run.sh contains code for patching several
OpenStack projects including trove, diskimage-builder,
devstack, requirements, ... 

1) transfer patch from gerrit to local machine

2) perform the following::

     X=~/gerritpatch.diff

     git clone git://github.com/openstack/trove /tmp/trove
     cd /tmp/trove
     patch -p1 < $X
     patch  p1 < ~/patches/master/trove-localrc.patch
     git diff > ~/patches/master/trove.patch
     rm -rf /tmp/trove

3) run trovestack-run-gate.sh or trovestack-run-int.sh

   Specify --help for command arguments

   It is necessary to specify --clean between invocations
   assuming one gets beyond the cloning and patching step
   which occurs in the beginning.  Code is placed in
   /opt/stack/ or /opt/stack/new depending on whether one
   runs integration or gate tests.

Debug
-----

log files are provided.

One can exercise Trove through the OpenStack GUI by attaching
a browser to the local host's IP address.  For example,
http://x.x.x.x/dashboard. The default users are admin and
demo.  The password is 'passw0rd'.

Some times when a test fails the guest images still exist
and are visible through the browser.  In this case, the datastore
instance detail tab may contain a stack traceback.

One can also log into the guest datastore - ssh ubuntu@y.y.y.y
from the localhost.  There is no password.
