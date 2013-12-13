#!/bin/sh
# Copyright (C) 2013 Red Hat Inc.
# Kashyap Chamarthy <kchamart@redhat.com>
# 
# # This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


# Purpose: To create a new Neutron tenant network
# 
# Assumption: An external network already exists, by name "ext" 

# Usage
    if [ $# -ne 6 ]; then
        echo "Usage: $0              \\
                        TENANTNAME USERNAME        \\
                        SUBNETSPACE ROUTERNAME     \\ 
                        PRIVNETNAME PRIVSUBNETNAME \\
        Examples: 

         1. To create a priv net with 14.0.0.0/24 subnet:
             $ ./`basename $0`    \\
                               demoten1 tuser1   \\
                               14.0.0.0 trouter1 \\
                               priv-net1 priv-subnet1

         2. To create a new user tenant with 15.0.0.0.24 subnet:
             $ ./`basename $0`    \\
                              demoten2 tuser2    \\
                              15.0.0.0 trouter2  \\
                              priv-net2 priv-subnet2
        "
        exit 1
    fi


# Source the admin credentials
source keystonerc_admin


# Positional parameters
tenantname=$1
username=$2
subnetspace=$3
routername=$4
privnetname=$5
privsubnetname=$6


# Create a tenant, user and associate a role/tenant to it.
keystone tenant-create       \
         --name $tenantname
 
keystone user-create         \
         --name $username    \
         --pass fedora

keystone user-role-add       \
         --user $username    \
         --role user         \
         --tenant $tenantname

# Create an RC file for this user and source the credentials
cat >> keystonerc_$username<<EOF
export OS_USERNAME=$username
export OS_TENANT_NAME=$tenantname
export OS_PASSWORD=fedora
export OS_AUTH_URL=http://localhost:5000/v2.0/
export PS1='[\u@\h \W(keystone_$username)]\$ '
EOF


# Source this user credentials
source keystonerc_$username


# Create new private network, subnet for this user tenant
neutron net-create $privnetname

neutron subnet-create $privnetname \
        $subnetspace/24            \
        --name $privsubnetname     \


# Create a router
neutron router-create $routername


# Associate the router to the external network by setting its gateway.
# NOTE: This assumes, the external network name is 'ext'
EXT_NET=$(neutron net-list | grep ext | awk '{print $2;}')
PRIV_NET=$(neutron subnet-list | grep $privsubnetname | awk '{print $2;}')
ROUTER_ID=$(neutron router-list | grep $routername | awk '{print $2;}')

neutron router-gateway-set  \
        $ROUTER_ID $EXT_NET \

neutron router-interface-add \
        $ROUTER_ID $PRIV_NET \


# Add Neutron security groups for this test tenant
neutron security-group-rule-create   \
        --protocol icmp              \
        --direction ingress          \
        --remote-ip-prefix 0.0.0.0/0 \
        default

neutron security-group-rule-create   \
        --protocol tcp               \
        --port-range-min 22          \
        --port-range-max 22          \
        --direction ingress          \
        --remote-ip-prefix 0.0.0.0/0 \
        default
