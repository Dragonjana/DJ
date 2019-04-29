[Admin root @ icgadmna1p /var/tmp/jc38549/Keys/pub_keys]
# cat runit.sh 
#!/usr/bin/ksh
#
# SSH Key install script v3.0
# jc38549@citi.com
#
# v3.0 - update
#       - enable script to add additional aliases/IPs
#       - connection mode alert
# v2.1 - update
#       - Added dns support fo apac/eur/jpn servers
# v2 - update
#       - Added check to detect missing target fid folder
#       - Script to terminate in case of duplicate keys
# v1 - Initial Release
#
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
sVer="3.0"
clear
tput rev
tput cup 3 15
echo "**********************************"
tput cup 4 15
echo "*"
tput cup 4 16
echo  " "
echo  "      SSH Key Install $sVer     "
echo  " "
tput cup 4 48
echo "*"
tput cup 5 15
echo "**********************************"
tput sgr0
echo "\n"

function getalias {
echo  "Enter Key file name for which additional aliases/IPs are to be allowed "
read key
echo "Enter aliases/IPs that are to be allowed (add all aliases one per line) "
aliases=$(sed '/^$/q')
awk "/$key/{getline; print}" /var/tmp/$snt/authfile |sed 's/.$/|/' > /var/tmp/$snt/newauthentry
for i in $aliases
do
        sshopt=`cat /var/tmp/$snt/newauthentry`
        echo "$sshopt$i|" > /var/tmp/$snt/newauthentry
done
sshopt=`cat /var/tmp/$snt/newauthentry|sed 's/.$/"/'`
sed -e "/$key/ {
N
d
}" /var/tmp/$snt/authfile > /var/tmp/$snt/authfile.1
mv /var/tmp/$snt/authfile.1 /var/tmp/$snt/authfile
echo "Key $key" >> /var/tmp/$snt/authfile
echo "$sshopt" >> /var/tmp/$snt/authfile
echo "### Below entries will be appended on target authorization file ###"
echo
echo "-------------------------------------------------------------------"
cat /var/tmp/$snt/authfile
echo "-------------------------------------------------------------------"
echo
echo  "Do you want to add extra alias/IP [n] (y/n) "
read opt
if [[ $opt == "y" || $opt == "Y" ]]; then
        getalias
fi
}

echo  "Enter the REQ/CHG No. "
read snt
echo  "Enter the Destination Hostname(s): "
servers=$(sed '/^$/q')
echo  "Enter the Destination FID: "
read dfid
echo  "Validating admin access              ... "
cat /dev/null > /tmp/noaccess
   for i in $servers
   do
        ssh $i exit 2>/dev/null
        if [[ $? != 0 ]]; then
        echo $i >> /tmp/noaccess
        fi
   done
echo "[$GREEN Ok $NC]"
   if [[ -s /tmp/noaccess ]]; then
        echo "Admin access not determined for servers "
        cat /tmp/noaccess
        rm -rf /tmp/noaccess
        exit
   fi
echo  "Creating directories                 ... "
mkdir -p /var/tmp/$snt
mkdir -p /var/tmp/$snt/keys
chmod -R 777 /var/tmp/$snt
echo "[$GREEN Ok $NC]"
echo "Waiting for Keys to be uploaded under /var/tmp/$snt/keys"
echo  "(Press <enter> to continue when done)"
read
source=`ls -l /var/tmp/$snt/keys|grep -v total|awk -F@ '{print $NF}'|awk -F. '{print $1}'|tr '\n' ' ' && echo`
echo "Detecting Connection modes           ... "
#/opt/SAtools/Scripts/server_info $source 2>/dev/null|grep Category|awk '{print $NF}' > /var/tmp/$snt/senv
sourcenv=`/opt/SAtools/Scripts/server_info $source 2>/dev/null|grep Category|sed s'/.$//'|awk '{print $NF}'|awk -F. '{print $1}'|tr '\n' ' ' && echo`
destenv=`/opt/SAtools/Scripts/server_info $servers 2>/dev/null|grep Category|sed s'/.$//'|awk '{print $NF}'|awk -F. '{print $1}'|tr '\n' ' ' && echo`
echo "-------------------"
for i in $sourcenv
do
        for j in $destenv
        do
                if [[ $i == "Dev" && $j == "Prod" || $i == "Dev" && $j == "COB" || $i == "UAT" && $j == "Prod" || $i == "UAT" && $j == "COB" || $i == "Dev" && $j == "UAT"  ]]; then
                echo "$RED$i -> $j$NC"
                violation="true"
                else
                echo "$GREEN$i -> $j$NC"
                fi
        done
done
echo "-------------------"
if [[ $violation == "true" ]]; then
        tput rev
        echo  "Alert:"
        tput sgr0
        echo  " Override Security Violation and Accept Risk (y/n) "
        read opt
        if [[ $opt == "n" || $opt == "N" ]]; then
        rm -rf /var/tmp/$snt
        exit
        fi
fi
echo  "Creating Map Entries                 ... "
echo "" > /var/tmp/$snt/authfile
echo "# $snt" >> /var/tmp/$snt/authfile
   for i in `ls -l /var/tmp/$snt/keys/*.pub|awk '{print $NF}'|awk -F/ '{print $NF}'`
   do
        echo "Key $i" >> /var/tmp/$snt/authfile
        dhost=`echo $i|awk -F@ '{print $NF}'|awk -F. '{print $1}'`
        dn=`nslookup $dhost|grep Name|awk '{print $NF}'`
        dnip=`nslookup $dhost|grep Address|tail -1|awk '{print $NF}'`
        if [[ ! -n $dn  ]]; then
                dn=`nslookup $dhost.eur.nsroot.net|grep Name|awk '{print $NF}'`
                dnip=`nslookup $dhost.eur.nsroot.net|grep Address|tail -1|awk '{print $NF}'`
        fi
        if [[ ! -n $dn ]]; then
                dn=`nslookup $dhost.apac.nsroot.net|grep Name|awk '{print $NF}'`
                dnip=`nslookup $dhost.apac.nsroot.net|grep Address|tail -1|awk '{print $NF}'`
        fi
        if [[ ! -n $dn ]]; then
                dn=`nslookup $dhost.jpn.nsroot.net|grep Name|awk '{print $NF}'`
                dnip=`nslookup $dhost.jpn.nsroot.net|grep Address|tail -1|awk '{print $NF}'`
        fi
        if [[ ! -n $dn ]]; then
                dn=`nslookup $dhost.ap.ssmb.com|grep Name|awk '{print $NF}'`
                dnip=`nslookup $dhost.ap.ssmb.com|grep Address|tail -1|awk '{print $NF}'`
        fi
        echo "Options command=\"eval \$SSH_ORIGINAL_COMMAND\",allow-from=\"$dn|$dnip\"" >> /var/tmp/$snt/authfile
   done
echo "[$GREEN Ok $NC]"
echo "### Below entries will be appended on target authorization file ###"
echo
echo "-------------------------------------------------------------------"
cat /var/tmp/$snt/authfile
echo "-------------------------------------------------------------------"
echo
echo  "Do you want to add extra alias/IP [n] (y/n) "
read opt
if [[ $opt == "y" || $opt == "Y" ]]; then
getalias
fi


   for i in $servers
   do
        echo "Copying .pub files                   ... "
        ssh $i ls -ld /etc/opt/SSHtectia/keys/$dfid 2>/dev/null
        if [[ $? != 0 ]]; then
                echo "Destination FID directory NOT found  ... "
                echo  "Creating folder & setting permission ... "
                ssh $i "mkdir -p /etc/opt/SSHtectia/keys/$dfid/; chmod 111 /etc/opt/SSHtectia/keys/$dfid"
                echo  "Creating folder & setting permission ... "
                echo "[$GREEN Ok $NC]"
        fi
        scp -q /var/tmp/$snt/keys/*.pub $i:/etc/opt/SSHtectia/keys/$dfid/ 2>/dev/null
        echo  "Copying .pub files                   ... "
        echo "[$GREEN Ok $NC]"
        echo "Updating Authorization file          ... "
        ls -l /var/tmp/$snt/keys/*.pub|awk '{print $NF}'|awk -F/ '{print $NF}' > /var/tmp/$snt/keylist
        ssh $i "test -e /etc/opt/SSHtectia/keys/$dfid/authorization"
        if [[ $? == 0 ]]; then
                ssh $i "cat /etc/opt/SSHtectia/keys/$dfid/authorization" |egrep -f /var/tmp/$snt/keylist 2>/dev/null
                if [[ $? != 0 ]]; then
                dup="true"
                else
                dup="false"
                fi
        fi
        dup="false"
        if [[ $dup == "false" ]]; then
                ssh $i "test -e /etc/opt/SSHtectia/keys/$dfid/authorization"
                if [[ $? == 0 ]]; then
                ssh $i "cp /etc/opt/SSHtectia/keys/$dfid/authorization /etc/opt/SSHtectia/keys/$dfid/authorization.`date '+%Y%m%d'`_`date '+%H%M'`" 2>/dev/null
                fi
                cat /var/tmp/$snt/authfile | ssh $i "cat >> /etc/opt/SSHtectia/keys/$dfid/authorization" 2>/dev/null
                echo  "Updating Authorization file          ... "
                echo "[$GREEN Ok $NC]"
        else
                echo "Duplicate Keys detected               ... "
                echo  "Update Authorization skipped on $i   ... "
                echo "[$RED FAIL $NC]"
        fi
   done
echo  "Performing Cleanup                   ... "
rm -rf /var/tmp/$snt
echo "[$GREEN Ok $NC]"
### End

