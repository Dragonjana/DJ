[UAT root @ ccuaweb3 /repository/VTM]
# cat patch-2019Q1.sh
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
#`RHEL5_BASEURL="SOE_PATCH_LEVEL=prod/soe5baselines-x86_64/2017Q1-A1.el5.x86_64/SOErelease-2017Q1.GSF-A1.el5.noarch.rpm"
#RHEL5i386_BASEURL="SOE_PATCH_LEVEL=prod/soe5baselines-i386/2017Q1-A1.el5.i386/SOErelease-2017Q1.GSF-A1.el5.noarch.rpm"
RHEL6_BASEURL="SOE_PATCH_LEVEL=prod/soe6baselines-x86_64/2019Q1-A0.el6.x86_64/SOErelease-2019Q1.GSF-A0.el6.noarch.rpm"


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
# In case of any issues with yum update, try updating individual packages with failed dependencies with --enablerepo=soe\*
# You may need to correct not-certified repository or remove duplicate repositiories
# 
# Check http://yum.nam.nsroot.net/wiki/Not_certified_yum_repository for more details
#
# e.g. yum --enablerepo=soe\* update glibc\*
# e.g. yum --enablerepo=NOT-CERTIFIED update gcc\*
#
# Please pay close attention to any kernel upgrade issues, do not reboot the server if yum update keeps failing 
#
# Django issue (RHEL5)
# 
# rpm -Uhv --force http://tibuildks1lnp/SOELinux/repos/prod/soe5baselines-x86_64/2017Q1-A0.el5.x86_64/openssl-0.9.8e-40.el5_11.i686.rpm
# rpm -Uhv --force http://tibuildks1lnp/SOELinux/repos/prod/soe5baselines-x86_64/2017Q1-A0.el5.x86_64/openssl-0.9.8e-40.el5_11.x86_64.rpm
#
# Python issue (RHEL6)
#
# rpm -ihv --force http://tibuildks1lnp/SOELinux/repos/prod/soe6baselines-x86_64/2017Q1-A0.el6.x86_64/python-libs-2.6.6-66.el6_8.x86_64.rpm
# rpm -ihv --force http://tibuildks1lnp/SOELinux/repos/prod/soe6baselines-x86_64/2017Q1-A0.el6.x86_64/python-2.6.6-66.el6_8.x86_64.rpm
#
# Fix the underlying issue and rerun the script
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

recreate_soe6gdeproducts_repo() {

cat > /etc/yum.repos.d/soe6gdeproducts.repo << EOF
[soe6gdeproducts]
name=soe6gdeproducts
baseurl=http://tibuildks1lnp.eur.nsroot.net/SOELinux/repos/prod/soe6gdeproducts-x86_64
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

checkFS() {

 FREESPACE=$( df -kP $1 | grep -v "^Filesystem" | awk '{ print $4 }' )
 if [ $FREESPACE -lt $2 ]; then
  echo_failure "$1 < $2kB. Clear it first!"
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

if grep -q 'release 6' /etc/redhat-release
then
 RHEL="rhel6"
 BASEURL="${RHEL6_BASEURL}"
 PLATFORM="rhel6-x86_64"
fi

if [ -z "${RHEL}" ]; then
 echo_failure "Unsupported RHEL flavor. RHEL6 supported only"
 exit 1
else
 echo_success "$RHEL"
fi

echo -n "Checking RPMDB ..."
/usr/lib/rpm/rpmdb_verify -o /var/lib/rpm/Packages
rpm --rebuilddb
last_status $?

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

#echo "Checking for EnterpriseOnload modules ..."
#if rpm -qi enterpriseonload >/dev/null; then
# echo_failure "enterpriseonload modules installed but no update for ${SOERELEASE} available"
#exit 1 
#fi

echo -n "Checking for misbehaving MSTAgent ..."
MSTAGENT=$( ps -ef | grep -c MSTAgent )
if [ ${MSTAGENT} -ge 10 ] ; then
 echo_failure "High number of MSTAgent instances. Kill them!!"
 exit 1
else
 echo_success "OK"
fi



echo -n "Checking for reboot job ...."
check_for_reboot

if [ ! -f ${LOCKFILE}.stage1 ]; then

echo "Collecting some useful outputs ...."
${WORKDIR}/checker

ps -ef > /var/tmp/vtm/ps_ef.pre
mount > /var/tmp/vtm/mount.pre
df -hP > /var/tmp/vtm/df_hP.pre
#tar cf /var/tmp/vtm/ssh_keys.tar /etc/ssh2/keys/

#Check whether /boot has sufficient disk space available and remove the old kernel versions 

rpm -qa kernel | egrep -v $(uname -r) | xargs rpm -e 2>/dev/null
rm -f /boot/initrd*img.san.bak*

echo -n "Checking / utilization"
checkFS / 1048576

echo -n "Checking /boot utilization"
checkFS /boot 51200

echo -n "Checking /var utilization"
checkFS /var 1048576 

echo -n "Checking /opt utilization"
checkFS /opt 1048576

#end of stage1
fi

touch ${LOCKFILE}.stage1
 
if [ ! -f ${LOCKFILE}.stage2 ]; then

#echo "london1" | passwd --stdin root
#RC=$?
#echo -n "Root password changed ..."
#last_status $RC

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

#echo "Checking for glibc-headers...."
#if rpm -qi glibc-headers  >/dev/null; then
echo "Recreating soe6gdeproducts repository ..."
recreate_soe6gdeproducts_repo
# echo "Updating glibc-headers ..."
# yum -y --enablerepo=soe6gdeproducts update glibc\*
# RC=$?
# echo -n "glibc update ..."
# last_status $RC
#fi

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

echo "Checking further for RPMDB corruption ..."
yum -y update SOErelease 
RC=$?
echo -n "Simple package update ..."
last_status $RC

echo "Checking for SolarFlare NICs...."
if rpm -qi enterpriseonload >/dev/null; then
 echo "Updating enterpriseonload modules ..."
 
# if [ "$RHEL" = "rhel5" ] ; then 
#   yum -y remove enterpriseonload-kmod\*
#   yum -y install enterpriseonload-kmod-2.6.18-419.el5.x86_64
#   RC=$?
# else
   yum -y remove enterpriseonload-kmod-2.6.32-754.2.1.el6.x86_64
#   yum -y install ${WORKDIR}/enterpriseonload-5.0.5-1.el6.x86_64.rpm ${WORKDIR}/enterpriseonload-kmod-2.6.32-696.23.1.el6-5.0.5-1.el6.x86_64.rpm
   yum -y install enterpriseonload.x86_64 enterpriseonload-kmod-2.6.32-754.9.1.el6.x86_64
   RC=$?
# fi
 echo -n "enterpriseonload install ..."
 last_status $RC
fi

#end of stage4
fi

touch ${LOCKFILE}.stage4

if [ ! -f ${LOCKFILE}.stage5 ]; then

echo "Running yum update ..."
PRODUCT=$( dmidecode -t 1 | grep "Product Name:" | cut -f2 -d":" | sed -e 's/[ ]*//g' )
if [ "$PRODUCT" = "ProLiantDL580G4" ] ; then
 yum -y update --enablerepo=soe6gdeproducts --exclude=ITM\*,hp\*,ESMclnt
else
 yum -y update --enablerepo=soe6gdeproducts --exclude=ITM\*,ESMclnt,srvadmin\*
fi
RC=$?

if [ $RC -ne 0 ] ; then
 echo_yum_notice 
fi
echo -n "Yum update status ..."
last_status $RC

echo "Post patching cleanups ..."
[ "$RHEL" = "rhel6" ] && service ntpd stop && service ntpclient start
#[ -f /etc/init.d/netbackup ] && /etc/init.d/netbackup start

echo "Removing duplicate TIscan jobs ..."
crontab -l | grep -v "^#" | grep -q "TIscan/bin/scan" && crontab -l | grep -q "TIscanUtils/bin/config_and_run" && crontab -l | sed -s 's/\(.*TIscan\/bin\/scan\)/#\1/g' > /tmp/crontab.temp && crontab -u root /tmp/crontab.temp && rm -f /tmp/crontab.temp

echo -n "Checking for SSHtectia configuration issue ..."
if grep -q dummy /etc/ssh2/ssh-server-config.xml ; then
 echo_failure "ERROR"
 ERRORFLAG=1
 echo "Check /etc/ssh2/ssh-server-config.xml and /etc/ssh2/ssh-broker-config.xml"
else
 echo_success "OK"
fi

#echo "Tweaking /etc/auto.net to mount /net with the soft option ..."
#if [ -f /etc/auto.net ]
#then
#if cat /etc/auto.net  | egrep "^ *opts=\".*, *hard *,.*\"" >/dev/null ||  ! cat /etc/auto.net  | egrep "^ *opts=\".*, *soft *,.*\"" >/dev/null
#then
#                                cp /etc/auto.net /etc/auto.net.bk-hard2soft
#sed -i  '/^opts="/ s/.*/opts="-fstype=nfs,soft,intr,nodev,nosuid"/' /etc/auto.net
#                fi
#fi 

#echo "Fixing SCpier config ..."
#sed -i 's/scpierrpt2/scpierrpt/g' /etc/opt/SCpier/app.cf

#echo -n "Updating rcpbind ..."
#rpm -U ${WORKDIR}/rpcbind-0.2.0-13.el6_9.1.x86_64.rpm 
#last_status $?

#end of stage5
fi

touch ${LOCKFILE}.stage5

echo "Checking for SANgria ..."
if rpm -qi sangria-1.0-B2.el6.x86_64 > /dev/null ; then

 yum -y remove sangria-1.0-B2.el6.x86_64
 yum -y --enablerepo=soe6products install sangria
 RC=$?
 echo -n "SANgria update ..."
 if [ $RC -eq 0 ] ; then
  echo_success "OK" 
 else
  echo_failure "ERROR"
  ERRORFLAG=1
 fi
 
 #last_status $RC
fi


#echo "Checking for samba3x-3.6.23-12.el5_11 ..."
#if rpm -qi samba3x-3.6.23-12.el5_11 > /dev/null ; then
# yum -y --enablerepo=NOT-CERTIFIED update samba3x
# RC=$?
# if [ $RC -ne 0 ]; then
#   echo "Ooops! It seems samba upgrade failed. This is might be due to the NOT-CERTIFIED repo not configured"
#   echo "Let's create the NOT-CERTIFIED repo and give it another try ..."
#   recreate_not_cert_repo ${PLATFORM}
#   echo "Rerunning yum -y --enablerepo=NOT-CERTIFIED update samba3x"
#   yum -y --enablerepo=NOT-CERTIFIED update samba3x
#   RC=$?
# fi
# echo -n "samba3x updated ..." 
# if [ $RC -eq 0 ]; then
#   echo_success "OK"
# else
#   echo_failure "FAILED"
# fi
#fi

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
