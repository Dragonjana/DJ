[UAT root @ ccuaweb3 /net/ccua/export/scripts/ca02038]
# cat /net/ccua/export/scripts/ca02038/find_free_SAN_disks.AIX.sh
#!/bin/ksh
# AIX - Find free SAN disks in a volume group.
# Acaldo 03/22/2011

# Confirm this is a AIX host:
if [ "`/bin/uname`" != "AIX" ]
then
        echo "$0 only valid on AIX hosts.  Exiting.";
        exit 1;
fi

# Confirm one command line argument was provided:
if [ $# -ne 1 ]
then
        echo "YOU MUST PROVIDE A VOLUME GROUP NAME.";
        echo "Usage: $0 <volume_group_name>;";
        exit 1;
fi

VG_NAME=$1;

# Is the command line arg a valid volume group?
lsvg ${VG_NAME} > /dev/null 2>&1;
if [ $? -ne 0 ]
then
        echo "${VG_NAME} IS NOT A VALID VOLUME GROUP.";
        echo "Usage: $0 <volume_group_name>;";
        exit 1;
fi

# First, find the disks in a volume group:
lspv |grep ${VG_NAME} > /tmp/${VG_NAME}_disks.txt;


echo "DISK      TOTAL_PPs     FREE_PPs      USED_PPs";
cat /tmp/${VG_NAME}_disks.txt | while read DISK SERIAL VG STATE
do
        TOTAL=`lspv ${DISK} | grep "TOTAL PPs" |awk '{print $3}'`;
        FREE=`lspv ${DISK} | grep "FREE PPs" |awk '{print $3}'`;
        USED=`lspv ${DISK} | grep "USED PPs" |awk '{print $3}'`;

        echo "${DISK}   ${TOTAL}        ${FREE}                 ${USED}";
done
