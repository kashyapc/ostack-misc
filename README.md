
Create a new Neutron Tenant network 
===================================

A simple script that'll create a new Neutron tenant network for a new
user. More below.

Usage:

    $ ./create-new-tenant-network.sh                \
                        TENANTNAME USERNAME         \
                        SUBNETSPACE ROUTERNAME      \ 
                        PRIVNETNAME PRIVSUBNETNAME  \


To create a new tenatn network with 14.0.0.0/24 subnet:

    $ ./create-new-tenant-network.sh \
      demoten1 tuser1     \
      14.0.0.0 trouter1   \
      priv-net1 priv-subnet1


The script does the below, in that order:

  1. Creates a Keystone tenant called demoten1
  2. Creates a Keystone user called tuser1 and associates it to the
     demoten1
  3. Create an RC file for user tuser1 and sources the credentials

     $ export OS_USERNAME=tuser1
     export OS_TENANT_NAME=demoten1
     export OS_PASSWORD=fedora
     export OS_AUTH_URL=http://localhost:5000/v2.0/
     export PS1='[\u@\h \W(keystone_tuser1)]$ '

  4. Creates a new private network called priv-net1
  5. Creates a new private subnet called priv-subnet1 on priv-net1
  6. Creates a router called trouter1
  7. Associates the router ('trouter1' in this case) to an existing
     external network (the script assumes it's called 'ext') by setting
     it as its gateway.
  8. Associates the private network interface to the router.
  9. Adds Neutron security group rules for this test tenant for ICMP and
     Ping.


NOTE: Since the shell script is executed in a subprocess (of the parent
shell), you won't notice the keystone sourcing of the newly created
user. (You can notice it in the stdout of the script in debug mode --
./temp-stdout/stdout-new-tenant-creation.txt.)
 

To test it's all working, you can try boot a new guest in the tenant
network, and it should aquire an IP address from 14.0.0.0/24 subnet.

