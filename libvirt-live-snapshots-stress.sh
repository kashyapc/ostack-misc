#!/bin/bash
# Purpose: For a given libvirt guest, create 100 external live-snapshots
# i.e. each snapshot is stored in a unique QCOW2 file

#set -x

PROGNAME=`basename $0`

DOMAIN=$1

SNAPSHOTS_DIR=/export/vmimages

# Create external snapshots
create_external_snapshot() {
let i=0
while [ $i -lt 100 ];do
    echo "Creating $DOMAIN-snap$i"
    virsh snapshot-create-as --domain $DOMAIN \
     --name snap-$i \
     --description snap$i-desc \
     --disk-only \
     --diskspec hda,snapshot=external,file=$SNAPSHOTS_DIR/$DOMAIN-snap$i.qcow2 \
     --atomic
    let i=i+1
done    
}

# main ()
{

    # Check if min no. of arguments are 1
    if [ "$#" != 1 ]; then
        echo "Provide the libvirt guest name."
        echo "e.g. $PROGNAME f20vm1"
        exit 255
    fi 


    create_external_snapshot

}    
