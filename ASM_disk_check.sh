[UAT root @ ccuaweb3 /net/ccua/export/scripts/AixLVM]
# cat /net/ccua/export/scripts/ca02038/ASM_disk_check.sh
#!/bin/ksh
#
PATH=/bin:/sbin:/usr/bin:/usr/sbin;
NODENAME=`uname -n`;
TEMPFILE=/tmp/tempfile.chuck.`/bin/date '+%Y%m%d%H%M%S'`;
cat /dev/null > ${TEMPFILE};

# First, find the OS Version and SOE Machine Category of this host:
case `/bin/uname` in
        AIX)
                OS_VERSION="`uname -v`.`uname -r`";
                ENV_FOUND=no;
                for i in Prod COB IDENuacob UAT Dev Lab IDENbuild Admin
                do
                        lslpp -l ${i} > /dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                                ENVIRONMENT=${i};
                                ENV_FOUND=yes;
                                continue;
                        fi
                done
                if [ "${ENV_FOUND}" == "no" ]
                then
                        ENVIRONMENT=UNKNOWN_ENV;
                fi
                ;;
        SunOS)
                OS_VERSION=`uname -r`;
                ENV_FOUND=no;
                for i in Prod COB IDENuacob UAT Dev Lab IDENbuild Admin
                do
                        /usr/bin/pkginfo -q ${i};
                        if [ $? -eq 0 ]
                        then
                                ENVIRONMENT=${i};
                                ENV_FOUND=yes;
                                continue;
                        fi
                done
                if [ "${ENV_FOUND}" == "no" ]
                then
                        ENVIRONMENT=UNKNOWN_ENV;
                fi
                ;;
        Linux)
                if [ -f /etc/redhat-release ]
                then
                        OS_VERSION="`cat /etc/redhat-release |awk '{print $7}'`";
                else
                        OS_VERSION=UNKNOWN_OS_VERSION;
                fi
                ENV_FOUND=no;
                for i in Prod COB IDENuacob UAT Dev Lab IDENbuild Admin
                do
                        rpm -q ${i} > /dev/null;
                        if [ $? -eq 0 ]
                        then
                                ENVIRONMENT=${i};
                                ENV_FOUND=yes;
                                continue;
                        fi
                done
                if [ "${ENV_FOUND}" == "no" ]
                then
                        ENVIRONMENT=UNKNOWN_ENV;
                fi
                ;;
        *)
                OS_VERSION=UNKNOWN_OS_VERSION;
                ;;
esac

CHECKNAME=ASM_disk_perms;
ERROR_FOUND=no;

case `/bin/uname` in
        AIX)
                # Check that all disks that belong to any volume group are owned by root:
                for DISK in `lspv |grep -v None |awk '{print $1}'`
                do
                        OWNER=`/usr/bin/istat /dev/r${DISK} |grep Owner | awk '{print $2}'`;
                        if [ "${OWNER}" != "0(root)" ]
                        then
                                VG=`lspv ${DISK} |grep "VOLUME GROUP" |awk '{print $6}'`;
                                echo "FAIL:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:/dev/r${DISK} is not owned by root! (${DISK} exists in the ${VG} volume group)";
                                ERROR_FOUND=yes;
                        fi
                        OWNER=`/usr/bin/istat /dev/${DISK} |grep Owner | awk '{print $2}'`;
                        if [ "${OWNER}" != "0(root)" ]
                        then
                                VG=`lspv ${DISK} |grep "VOLUME GROUP" |awk '{print $6}'`;
                                echo "FAIL:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:/dev/${DISK} is not owned by root! (${DISK} exists in the ${VG} volume group)";
                                ERROR_FOUND=yes;
                        fi
                done

                if [ "${ERROR_FOUND}" == "no" ]
                then
                        echo "PASS:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:All disks that belong to a volume group are owned by root.";
                fi
                ;;
        Linux)
                # First, ensure all disks configured in the Linux native LVM are owned by root.
                for DISK in `/usr/sbin/pvs --noheadings |awk '{print $1}'`
                do
                        if [ -f ${DISK} ]
                        then
                                OWNER=`/usr/bin/stat --format=%U ${DISK}`;
                                if [ "${OWNER}" != "root" ]
                                then
                                        echo "FAIL:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:${DISK} belongs to a Linux VG, but is not owned by root!";
                                        ERROR_FOUND=yes;
                                fi
                        fi
                done

                # Second, confirm all disks configured in Veritas and belong to a volume group are owned by root (if Veritas is used).
                if [ -f /sbin/vxdisk ]
                then
                        /sbin/vxdisk list |grep -v "^DEVICE" |while read LINE
                        do
                                DISK_NAME=`echo ${LINE} |awk '{print $1}'`;
                                if [ -f /dev/${DISK_NAME} ]
                                then
                                        VG_COLUMN=`echo ${LINE} |awk '{print $4}'`;
                                        if [ "${VG_COLUMN}" != "-" ]
                                        then
                                                OWNER=`/usr/bin/stat --format=%U /dev/${DISK_NAME}`;
                                                if [ "${OWNER}" != "root" ]
                                                then
                                                        echo "FAIL:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:/dev/${DISK_NAME} belongs to a Veritas VG, but is not owned by root!";
                                                        ERROR_FOUND=yes;
                                                fi
                                        fi
                                fi
                        done
                fi
                if [ "${ERROR_FOUND}" == "no" ]
                then
                        echo "PASS:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:All disks that belong to a volume group are owned by root.";
                fi
                ;;
        SunOS)
                echo "PASS:${NODENAME}:${CHECKNAME}:`uname`:${OS_VERSION}:${ENVIRONMENT}:Script not written to check SunOS.";
                ;;
        *)
                echo "FAIL:${NODENAME}:ITM6_CHECK:`uname`:This OS is not supported by this script.  Get a real OS.  Exiting.";
                ;;
esac

\rm ${TEMPFILE};
exit 0;
[UAT root @ ccuaweb3 /net/ccua/export/scripts/AixLVM]
# 
