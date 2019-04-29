[UAT root @ ccuaweb3 /repository/VTM]
# cat patch-2019Q1-rh7.sh
#!/bin/bash 
###############################################################
# Relevant Docs:
#https://catecollaboration.citigroup.net/domains/platstor/osunix/stdsrelateddocs/RFP-SOE-Linux-RHEL-Quarterly-Release-2019Q1-A0.pdf
#
###############################################################

mkdir /var/tmp/vtm 2>/dev/null
LOGFILE="/var/tmp/vtm/vtm.`date +%Y%m%d%H%M`.log"
exec &> >(tee -a $LOGFILE) 

ERRORFLAG=0
WORKDIR=`dirname $0`

VTM_BUNDLE="2019Q1"
RHEL7_BASEURL="http://tibuildks1lnp.eur.nsroot.net/SOELinux/repos/prod/soe7baselines-x86_64/2019Q1-A0.el7.x86_64"

LOCKFILE="/tmp/$( basename $0).lock"

BOOTUP=color
RES_COL=60
MOVE_TO_COL="echo -en \\033[${RES_COL}G"
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_WARNING="echo -en \\033[1;33m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

echo_yum_notice() {
cat << EOF
# In case of any issues with yum update, try updating individual packages with fai
led dependencies with --enablerepo=soe\*
# You may need to correct not-certified repository or remove duplicate repositiories
# 
# Check http://yum.nam.nsroot.net/wiki/Not_certified_yum_repository for more details
#
# e.g. yum --enablerepo=soe\* update glibc\*
# e.g. yum --enablerepo=NOT-CERTIFIED update gcc\*
#
# Please pay close attention to any kernel upgrade issues, do not reboot the server if yum update keeps failing 
#
EOF

}

recreate_not_cert_repo() {

PLATFORM="$1"
rm -f /etc/yum.repos.d/NOT-CERTIFIED.repo 2>/dev/null
cat > /etc/yum.repos.d/not-certified.repo << EOF
[NOT-CERTIFIED]
name=NOT-CERTIFIED
baseurl=http://openopen.nam.nsroot.net/openopen/not-cert/${PLATFORM}/latest/RPMS.all/
enabled=0
gpgcheck=0
EOF

}

create_soe_prod_repo() {

cat > /etc/yum.repos.d/soe-prod.repo << EOF
# SOE quarterly release repo 
[${VTM_BUNDLE}]
name=SOE quarterly release production repo
baseurl="${RHEL7_BASEURL}"
enabled=1
gpgcheck=0

}


echo_success() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "[  "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n "$1"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo "  ]"
}


echo_failure() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "[  "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
  echo -n "$1"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo  "  ]"
}

last_status() {

 if [ $1 -eq 0 ]; then
  echo_success "OK"
 else
  echo_failure "FAILED"
  exit 1
 fi

}

#This is a simple check on the reboot job in cron. It checks against the hour, minute and day of the week only.
check_for_reboot()
{
 #Check for the reboot job
 REBOOT_JOB=$( crontab -l | egrep "reboot|init |shutdown" | egrep -v "^[[:space:]]*#" | head -1 | awk '{ print $1, $2, $5 }' )
 [ -z "${REBOOT_JOB}" ] && echo_success "OK" && return

 #Split the current time to calculate the minute of the day
 CHOUR=$( date +%k )
 CMINUTE=$( date +%M )
 CDAY=$( date +%w )
 CMINUTE_OF_DAY=$(( ${CHOUR#0}*60 + ${CMINUTE#0} ))

 #Calcuate the next day. Required if the reboot happens close to midnight.
 NDAY=$( date +%w -d "now + 1 day" )

 #Calculate minute of the day of the reboot job
 RHOUR=$( echo "${REBOOT_JOB}" | cut -f2 -d" ")
 #Remove leading 0 unless it is 0 alone
 [ "$RHOUR" = "0" ] || RHOUR=${RHOUR#0}
 RMINUTE=$( echo "${REBOOT_JOB}" | cut -f1 -d" ")
 [ "$RMINUTE" = "0" ] || RMINUTE=${RMINUTE#0}
 RDAY=$( echo "${REBOOT_JOB}" | cut -f3 -d" ")
 [ "${RDAY}" = "*" ] && RDAY=${CDAY}
 #We need 0 for Sunday as opposed to 7.
 RDAY=$(( ${RDAY} % 7 ))
 RMINUTE_OF_DAY=$(( ${RHOUR}*60 + ${RMINUTE} ))

 #Set the time to reboot to an arbitrary high value for now
 TIME_DIFFERENCE=999
 
 if [  ${CDAY} -eq ${RDAY} ] && [ ${RMINUTE_OF_DAY} -ge ${CMINUTE_OF_DAY}  ]; then
  TIME_DIFFERENCE=$(( ${RMINUTE_OF_DAY} - ${CMINUTE_OF_DAY} ))
 #We might be patching close to midnight and the reboot might be scheduled after midnight 
 elif [ ${NDAY} -eq ${RDAY} ] ; then
  TIME_DIFFERENCE=$(( 1440 - ${CMINUTE_OF_DAY} + ${RMINUTE_OF_DAY} ))
 fi
 
 if [ ${TIME_DIFFERENCE} -lt 30 ]; then 
  echo_failure "Reboot might be scheduled in ${TIME_DIFFERENCE} minutes."
  echo -e "Verify the crontab job:\n"
  crontab -l | egrep "reboot|init|shutdown" | egrep -v "^[[:space:]]*#"
  echo -e "\nComment out the job above and rerun the script. Don't forget to reinstate the job after the patching."
  exit 1
 else
  echo_success OK 
 fi 

}

checkFS() {

 FREESPACE=$( df -kP $1 | grep -v "^Filesystem" | awk '{ print $4 }' )
 if [ $FREESPACE -lt $2 ]; then
  echo_failure "$1 < $2 kB. Clear it first!"
  exit 1
 else
  echo_success "OK" 
fi

}

####################################################################################
#
# MAIN BODY STARTS HERE
#
###################################################################################

#We don't run this script in PROD yet
#[ -e /var/log/rpmpkgs ] && egrep -q '^COB-|^Prod-' /var/log/rpmpkgs && echo_failure "VTM bundle ${VTM_BUNDLE} not ready for Production yet" && exit 1

echo "Disabling CRS reboot ..."
touch /tmp/disable_crs_reboot

echo -n "Checking RHEL flavor ..."

if grep -q 'release 7' /etc/redhat-release
then
 RHEL="rhel7"
 BASEURL="${RHEL7_BASEURL}"
 PLATFORM="rhel7-x86_64"
fi

if [ -z "${RHEL}" ]; then
 echo_failure "Unsupported RHEL flavor. RHEL7 supported only"
 exit 1
else
 echo_success "$RHEL"
fi

echo -n "Checking SOErelease...."
SOERELEASE=$( rpm -q SOErelease 2>/dev/null | cut -f2 -d"-" )
if [ "${SOERELEASE}" = "${VTM_BUNDLE}.GSF" ]  ; then
 echo_success "${SOERELEASE}"
 exit 0
elif [ ! -z "${SOERELEASE}" ]; then
 echo_success "${SOERELEASE}" 
else
 echo_failure "Unknown SOErelease"
 exit 1
fi

echo -n "Checking for reboot job ...."
check_for_reboot

if [ ! -f ${LOCKFILE}.stage1 ]; then

echo "Collecting some useful outputs ...."
rpm -q perl-Switch-2.16-7.el7.noarch >/dev/null || yum -y install perl-Switch-2.16-7.el7.noarch 
${WORKDIR}/checker

ps -ef > /var/tmp/vtm/ps_ef.pre
mount > /var/tmp/vtm/mount.pre
df -hP > /var/tmp/vtm/df_hP.pre
#tar cf /var/tmp/vtm/ssh_keys.tar /etc/ssh2/keys/

#Check whether /boot has sufficient disk space available and remove the old kernel versions 

rpm -qa kernel | egrep -v $(uname -r) | xargs rpm -e 2>/dev/null
rm -f /boot/initrd*img.san.bak*

echo -n "Checking / utilization ..."
checkFS / 1048576

echo -n "Checking /boot utilization ..."
checkFS /boot 51200

echo -n "Checking /var utilization ..."
checkFS /var 1048576 

echo -n "Checking /opt utilization ..."
checkFS /opt 1048576

#end of stage1
fi

touch ${LOCKFILE}.stage1
 
if [ ! -f ${LOCKFILE}.stage2 ]; then

#echo "london1" | passwd --stdin root
#RC=$?
#echo -n "Root password changed ..."
#last_status $RC

echo "Running backsnap for RHEL6 ..." 
rpm -q backsnap >/dev/null || yum -y install backsnap
backsnap --snap
backsnap --status

#end of stage2
fi

touch ${LOCKFILE}.stage2

#echo -e "\nChange bonding mode to active-backup with arp_validate=1"
#${WORKDIR}/fix.bonding.sh --apply

if [ ! -f ${LOCKFILE}.stage3 ]; then
 
echo -n "Creating soe-prod repo ..."
create_soe_prod_repo
last_status $?

#if ls -1 /etc/yum.repos.d | grep -qi not-certified; then
# echo "Recreating NOT-CERTIFIED repo ...."
# recreate_not_cert_repo ${PLATFORM}
#fi

echo -n "Checking for ${VTM_BUNDLE} ..."
grep -q ${VTM_BUNDLE} /etc/yum.repos.d/soe-prod.repo 
last_status $?

#end of stage3
fi

touch ${LOCKFILE}.stage3

if [ ! -f ${LOCKFILE}.stage4 ]; then

echo "Running yum clean ..."
yum clean all
RC=$?
echo -n "Yum clean status ..."
last_status $RC

#end of stage4
fi

touch ${LOCKFILE}.stage4

if [ ! -f ${LOCKFILE}.stage5 ]; then

echo "Running yum update ..."
yum -y update 
RC=$?

if [ $RC -ne 0 ] ; then
 echo_yum_notice 
fi
echo -n "Yum update status ..."
last_status $RC

#echo "Post patching cleanups ..."

#end of stage5
fi

touch ${LOCKFILE}.stage5

echo "Checking for firmware updates ...."
${WORKDIR}/checkFirmware.sh -u

#Remove the lock files
rm -f ${LOCKFILE}.stage*
rm -f /tmp/disable_crs_reboot

if [ $ERRORFLAG = 0 ] ; then
 echo "Patching completed successfully"
else
 echo "Patching completed with some errors. Please check the log above for details"
fi
