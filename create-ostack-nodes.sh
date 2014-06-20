#!/bin/bash

PROGNAME=`basename $0`

CONTROLLER_NAME=$1
CONTROLLER_DISK_SIZE=$2
CONTROLLER_MEM=$3
COMPUTE_NAME=$4
COMPUTE_DISK_SIZE=$5
COMPUTE_MEM=$6
ROOTPW=$7
IMAGES_HOME=/var/lib/libvirt/images
CONTROLLER_IMAGE=$IMAGES_HOME/$CONTROLLER_NAME.qcow2
COMPUTE_IMAGE=$IMAGES_HOME/$COMPUTE_NAME.qcow2

usage () {
    echo -e "
    ***NOTE***: Ensure you have at-least 100G free disk space and
                10G of free memory available before you invoke 
                this script.

    Usage: ./$PROGNAME CONTROLLER_NAME CONTROLLER_DISK_SIZE \\ \n \
                           CONTROLLER_MEM COMPUTE_NAME \\ \n \
                           COMPUTE_DISK_SIZE COMPUTE_MEM ROOTPW

        This script aims to setup two virtual machines -- first one, an
        OpenStack Controller node; second one, OpenStack Compute node.


        Examples:

            Create a Controller node with 40G disk, 4096MB memory and
            a Compute node with 50G disk, 6144MB memory with root
            password as 'fedora':

                ./$PROGNAME controller 40G 4096 compute 50G 6144 fedora


            Create a Controller node with 80G disk, 4096MB memory and
            a Compute node with 120G disk, 8192MB memory, with root
            password as 'fedora':

                ./$PROGNAME controller 80G 4096 compute 120G 8192 fedora
    "
}

# This must be run as root
check_if_root() {
    if [ `id -u` -ne 0 ] ; then
        echo "Please run as 'root' to execute $PROGNAME."
        exit 1
    fi
}


# Check free memory on the host
check_free_mem() {
    echo "Checking for free memory on your host. . ."
    FREEMEM=$(free -m | awk 'NR==3 {print $4}')
    if [ "$FREEMEM" -lt "10000" ]; then
        echo "Please ensure you have at-least 10G of free memory"
        exit 255
    fi
}


set_root_passwd() {
    # Create a secure tmp directory
    tmp=`(umask 077 && mktemp "vmpwdXXXXXXX") 2>/dev/null` && test $tmp
    echo "Create root password for virtual machines. . ."
    echo $ROOTPW > $tmp
}


create_nodes() {
    # Create Controller node
    echo "Preparing Controller node disk image. . ."
    virt-builder fedora-20 \
        --update \
        --selinux-relabel \
        --format qcow2 \
        --size $CONTROLLER_DISK_SIZE \
        --root-password file:$tmp \
        -o $IMAGES_HOME/$CONTROLLER_NAME.qcow2 

    # Create Compute node
    echo "Preparing Compute node disk image. . ."
    virt-builder fedora-20 \
        --update \
        --selinux-relabel \
        --format qcow2 \
        --size $COMPUTE_DISK_SIZE \
        --root-password file:$tmp \
        -o $IMAGES_HOME/$COMPUTE_NAME.qcow2

    rm $tmp
    return 0
}


# FIXME: Import with openstack libvirt networks
import_nodes_into_libvirt() {
    # Import the virtual machines into libvirt
    echo "Importing Controller and Compute images into libvirt. .  ."
    virt-install --name controller \
        --ram $CONTROLLER_MEM \
        --disk path=$CONTROLLER_IMAGE,format=qcow2 \
        --import --noautoconsole --noreboot

    # Import the Compute node disk image into libvirt
    virt-install --name compute \
        --ram $COMPUTE_MEM \
        --disk path=$COMPUTE_IMAGE,format=qcow2 \
        --import --noautoconsole --noreboot

    return 0
}


check_kvm_nesting() {
    CHECK_NESTING=$(cat /sys/module/kvm_intel/parameters/nested)
    if [ "$CHECK_NESTING" != "Y" ]; then
        echo "Please ensure you enable nested virt"
        echo "To enable nested virt, add 'options kvm-intel nested=y'
        (without quotes) to '/etc/modprobe.d/dist.conf', & reboot the
        host."
        exit 255
    fi
}


enable_nested_virt() {
    echo "Setup netsted virt on Compute host. . ."
    virt-xml compute \
        --edit \
        --cpu host-passthrough,clearxml=yes
}


create_snapshot() {
    # Take snapshots
    echo "Taking snapshots. . ."
    virsh snapshot-create-as \
        controller snap1 "Pristine Fedora"
    virsh snapshot-create-as \
        compute snap1 "Pristine Fedora"
    
    return 0
}


start_nodes() {
    echo "Starting Controller and Compute nodes. . ."
    virsh start controller
    virsh start compute
}


# main()
{

    # check if min no. of arguments are 6
    if [ "$#" != 7 ]; then
        usage
        exit 255
    fi


    check_if_root
    check_free_mem
    set_root_passwd
    create_nodes
    import_nodes_into_libvirt
    check_kvm_nesting
    enable_nested_virt
    create_snapshot
    start_nodes
}

