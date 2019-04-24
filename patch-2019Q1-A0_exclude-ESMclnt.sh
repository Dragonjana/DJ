# cd OS/
[UAT root @ ccuaweb3 /export/scripts/jc38549/OS]
# cat patch-2019Q1-A0_exclude-ESMclnt.sh
#!/bin/bash
###############################################################
# Relevant Docs:
# https://cedt-confluence.nam.nsroot.net/confluence/pages/viewpage.action?spaceKey=150305&title=EMEA+TTS+-+RHEL+2018Q1+patching+procedure
# https://catecollaboration.citigroup.net/domains/platstor/osunix/stdsrelateddocs/RFP-SOE-Linux-RHEL-Quarterly-Release-2018Q1-A0.pdf
#
###############################################################

LOGFILE="/var/tmp/vtm.`date +%Y%m%d%H%M`.log"
exec &> >(tee -a $LOGFILE)

WORKDIR="/net/ccuaweb3/export/scripts/jc38549/OS/"

VTM_BUNDLE="2019Q1-A0"

#RHEL6i386_BASEURL="SOE_PATCH_LEVEL=prod/soe6baselines-s390x/2018Q2-A0.el6.s390x/SOErelease-2018Q2.GSF-A0.el6.noarch.rpm"
RHEL6_BASEURL="SOE_PATCH_LEVEL=prod/soe6baselines-x86_64/2019Q1-A0.el6.x86_64/SOErelease-2019Q1.GSF-A0.el6.noarch.rpm"

LOCKFILE="/tmp/$( basename $0).lock"

BOOTUP=color
RES_COL=60
MOVE_TO_COL="echo -en \\033[${RES_COL}G"
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_WARNING="echo -en \\033[1;33m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"


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

gen_IIENV()
{
 RC=0
 sed 's/SOE_PATCH_LEVEL=.*//g' /var/opt/yum-config/II_ENV | egrep -v "^[[:space:]]*$" > /var/opt/yum-config/II_ENV.new
 mv -f /var/opt/yum-config/II_ENV.new /var/opt/yum-config/II_ENV
 RC=$?
 echo $1 >> /var/opt/yum-config/II_ENV
 return $RC
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

####################################################################################
#
# MAIN BODY STARTS HERE
#
###################################################################################

#We don't run this script in PROD yet
#[ -e /var/log/rpmpkgs ] && egrep -q '^COB-|^Prod-' /var/log/rpmpkgs && echo_failure "VTM bundle ${VTM_BUNDLE} not ready for Production yet" && exit 1

#echo -n "Checking SOErelease...."
#SOERELEASE=$( rpm -q SOErelease 2>/dev/null | cut -f2 -d"-" )
#if [ "${SOERELEASE}" = "${VTM_BUNDLE}.GSF" ]  ; then
 #echo_success "${SOERELEASE}"
 #exit 0
#elif [ ! -z "${SOERELEASE}" ]; then
 #echo_success "${SOERELEASE}"
#else
 #echo_failure "Unknown SOErelease"
 #exit 1
#fi

echo -n "Checking for reboot job ...."
check_for_reboot

echo -n "Checking RHEL flavor ..."

if grep -q 'release 5' /etc/redhat-release
then
 RHEL="rhel5"
 if uname -m | grep -q i686 ; then
  BASEURL="${RHEL5i386_BASEURL}"
  PLATFORM="rhel5-i386"
 elif uname -m | grep -q x86_64 ; then
  BASEURL="${RHEL5_BASEURL}"
  PLATFORM="rhel5-x86_64"
 else
  echo_failure "Unknown RHEL5 flavor: not x86_64 nor i386"
 fi
 elif grep -q 'release 6' /etc/redhat-release
then
 RHEL="rhel6"
 BASEURL="${RHEL6_BASEURL}"
 PLATFORM="rhel6-x86_64"
fi

if [ -z "${RHEL}" ]; then
 echo_failure "Unsupported RHEL flavor"
 exit 1
else
 echo_success "$RHEL"
fi

if [ ! -f ${LOCKFILE}.stage1 ]; then

echo "Collecting some useful outputs ...."
cp /net/ldnvnasnfsu0141.eur.nsroot.net/ldneqtv0052/eqtqt0052/VTM/checker.tar /var/tmp/;
cd /var/tmp;
tar -xvf checker.tar;
cd checker;
./checker;

/net/ccuaweb3/export/scripts/jc38549/sanity/sanity.sh;

ps -ef > /var/tmp/ps_ef.pre

#Check whether /boot has sufficient disk space available and remove the old kernel versions

#rpm -qa kernel | egrep -v $(uname -r) | xargs rpm -e 2>/dev/null
#rm -f /boot/initrd*img.san.bak*

echo -n "Checking /boot utilization"
BOOTSIZE=$( df -kP /boot | grep "/boot" | awk '{ print $4 }' )


if [ $BOOTSIZE -le 1200 ]; then
  echo_failure "/boot < 50 MB. Clean it up first!"
  exit 1
else
  echo_success "OK"
fi

#end of stage1
fi

touch ${LOCKFILE}.stage1

if [ ! -f ${LOCKFILE}.stage2 ]; then

echo "abc@123" | passwd --stdin root
RC=$?
echo -n "Root password changed ..."
last_status $RC

if [ "$RHEL" = "rhel6" ]
then
 echo "Running backsnap for RHEL6 ..."
 rpm -q backsnap >/dev/null || yum -y install backsnap
 backsnap --snap
 backsnap --status
fi
#end of stage2
fi

touch ${LOCKFILE}.stage2

echo -e "\nChange bonding mode to active-backup with arp_validate=1"
${WORKDIR}/fix.bonding.sh --apply

if [ ! -f ${LOCKFILE}.stage3 ]; then

echo -n "Updating II_ENV file ..."
gen_IIENV "${BASEURL}"
last_status $?

if ls -1 /etc/yum.repos.d | grep -qi not-certified; then
 echo "Recreating NOT-CERTIFIED repo ...."
 recreate_not_cert_repo ${PLATFORM}
fi

echo -n "Running mkrepoconf ..."
MKREPOCHECK=$( /opt/yum-config/bin/mkrepoconf 2>&1 )
if [ -z "$MKREPOCHECK" ] ; then
 last_status 0
else
 echo $MKREPOCHECK
 echo -n "mkrepoconf"
 last_status 1
fi

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

echo "Checking for SolarFlare NICs...."
if rpm -qi enterpriseonload >/dev/null; then
 echo "Updating enterpriseonload modules ..."

 if [ "$RHEL" = "rhel5" ] ; then
   yum -y remove enterpriseonload-kmod\*
   yum -y install enterpriseonload-kmod-2.6.18-419.el5.x86_64
   RC=$?
 else
   yum -y remove enterpriseonload\*
   yum -y install enterpriseonload.x86_64 enterpriseonload-kmod-2.6.32-642.13.1.el6.x86_64
   RC=$?
 fi
  echo -n "enterpriseonload install ..."
  last_status $RC
fi


#end of stage4
fi

touch ${LOCKFILE}.stage4

if [ ! -f ${LOCKFILE}.stage5 ]; then

echo "Running yum update ..."
yum -y update --exclude=ESMclnt
RC=$?

if [ $RC -ne 0 ] ; then
 echo_yum_notice
fi
echo -n "Yum update status ..."
last_status $RC

echo "Post patching cleanups ..."
[ "$RHEL" = "rhel6" ] && service ntpd stop && service ntpclient start
#[ -f /etc/init.d/netbackup ] && /etc/init.d/netbackup start

echo "Fixing SCpier config ..."
sed -i 's/scpierrpt2/scpierrpt/g' /etc/opt/SCpier/app.cf

#end of stage5
fi

touch ${LOCKFILE}.stage5

echo "Checking for SANgria ..."
if rpm -qi sangria-1.0-B2.el6.x86_64 > /dev/null ; then

 yum -y remove sangria-1.0-B2.el6.x86_64
 yum -y --enablerepo=soe6products install sangria
 RC=$?
 echo -n "SANgria update ..."
 last_status $RC

fi


echo "Checking for firmware updates ...."
${WORKDIR}/checkFirmware.sh

#Remove the lock files
rm -f ${LOCKFILE}.stage*

echo "Patching completed successfully"
