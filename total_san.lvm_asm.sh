#V3 updates
#Included addtional valdiation for sangria
#Removed pts devices from ASM ownership check
#Removed non VG disks from LVM check
#Added GPFS check 2/8

SSPV=0
SANGRIA=0

INQF="/tmp/.inq.txt"
DISKF="/tmp/.disks.txt"
INQTMPF="/tmp/.inq_tmp.txt"
SRDFBCVF="/tmp/.srdfbcv.txt"
SERIALF="/tmp/.serial.out"

>$INQF ; >$DISKF ; >$INQTMPF ; >$SRDFBCVF ; >$SERIALF

if [ -f /opt/sangria/bin/inq  ]
then
INQ=/opt/sangria/bin/inq ; SANGRIA=1
elif [ -f /opt/SANinfo/bin/inq ]
then
INQ=/opt/SANinfo/bin/inq
elif [ -f /opt/SSPV/bin/inq ]
then
INQ="/opt/SSPV/bin/inq"
SSPV=1
fi

TSIZE=0
HWINFO=""
OS=`uname`

if [ -f /usr/sbin/dmidecode ]
then
HWINFO=$( dmidecode | grep -PC3 '^System Information$' | grep -P '\tProduct Name:' | sed 's/.*Product Name: //' | grep -v '^$' );
fi

if [[ "$HWINFO" = "VMware Virtual Platform" ]]
then
        TOTALSAN=`fdisk -l 2>/dev/null | grep Disk | grep sd | awk {'sum+=$3}END{print sum'}`
        echo "==========================";
        echo "DISK DETAILS FOR `uname -n`";
        echo "==========================";
        echo "`uname -n`  is a vmware machine and total storage amount is $TOTALSAN GB "
        fdisk -l | grep Disk | grep /dev/sd
        echo "ACTIVE LVM DISKS (includes rootvg) : ` pvdisplay -C --separator : -o pv_name,vg_name 2>/dev/null | grep /dev/sd |   awk -F: '$NF != ""' |wc -l`"
        (id oracle >& /dev/null ) && echo "ASM DISKS  : $(find /dev -type b -user oracle  2>/dev/null | grep -v /dev/pts 2>/dev/null |wc -l)"

else


ps -ef | grep vxconfig | grep -v grep >/dev/null 2>&1
if [ $? -eq 0 ]
then
veritas=yes
fi

if [ -f $INQ ]
then

        if [ "$veritas" == "yes" ]
                then
                $INQ -no_dots | grep rdmp | egrep 'EMC|HITACHI|DGC' > $INQF
                $INQ  -no_dots -wwn | egrep 'EMC|HITACHI|DGC' | grep rdmp |grep -v "N\/A"  |  awk '{print $1}' | awk -F/ '{print $NF}'  > $DISKF

        elif [ "$OS" == "AIX" ]
                then

                $INQ -no_dots > $INQTMPF
                cat $INQTMPF | egrep 'power|dm\-'  | egrep 'EMC|HITACHI|DGC' >  $INQF
                cat $INQTMPF  |  egrep 'power|dm-'  | grep -v "N/A" | awk '{print $1}' | awk -F/ '{print $NF}'  > $DISKF

        elif [ $SANGRIA -eq 1 ]
        then

        $INQ -no_dots |  egrep 'EMC|HITACHI|DGC' >  $INQTMPF
        cat $INQTMPF | grep ":EMC" | awk -F:  '{ print $5 }' | sort | uniq | sed '/^$/d' > $SERIALF
        >$INQF ; for i in `cat $SERIALF `; do cat $INQTMPF | grep $i | head -1 >> $INQF; done
        cat $INQTMPF | grep ":HITACHI :OPEN-V" | egrep 'dm\-' >>  $INQF
        cat $INQF  | awk '{print $1}' | awk -F/ '{print $NF}'  > $DISKF

        else 

        $INQ -no_dots | egrep 'power|dm\-'  | egrep 'EMC|HITACHI|DGC' >  $INQF 
        $INQ  -no_dots -wwn |  egrep 'power|dm-'  | grep -v "N/A" | awk '{print $1}' | awk -F/ '{print $NF}'  > $DISKF


        fi
else
        echo "inq not found under /opt/SANinfo OR /opt/sangria. Exiting !"
        exit 1
fi

if [ $SSPV -eq 1 ]
then
$INQ -no_dots -et |  grep   rdmp | egrep 'R2|BCV' > $SRDFBCVF
else
$INQ -no_dots -et | egrep 'power|dm\-' | grep -v  rdmp | egrep 'R2|BCV' > $SRDFBCVF
fi

NBCV=`grep BCV $SRDFBCVF | wc -l | awk '{print $1}'`
NSRDF=`grep R2 $SRDFBCVF | wc -l | awk '{print $1}'`

for diskname  in `cat $DISKF `
do 

val=`grep -w $diskname $INQF | awk '{print $NF}'`
TSIZE=`expr  $val + $TSIZE`
done

#GBSIZE=`echo "scale=2; $TSIZE / 1024 / 1024" | bc`
GBSIZE=$(( $TSIZE / 1024 / 1024))
NDISKS=`wc -l $DISKF | awk '{print $1}' | tr -d " "`
echo "==========================";
echo "SAN DETAILS FOR `uname -n`";
echo "==========================";
echo "Total Number of SAN disks (includes R2/BCV disk count) : $NDISKS"
SRDFC=`wc -l $SRDFBCVF| awk '{print $1}' `
echo "R2 + BCV Disk count = $SRDFC ($NSRDF + $NBCV)"
echo "Total SAN space  : ${GBSIZE}GB"
cat  $INQF | awk '{print $NF}' | sort | uniq -c | awk '{print $1" x "$2"KB"}'

rm $DISKF $INQF

if [ "$OS" == "Linux" ]
then

echo "ACTIVE LVM DISKS  : ` pvdisplay -C --separator : -o pv_name,vg_name 2>/dev/null | egrep 'power|mpath'  | awk -F: '$NF != ""' |wc -l`"
echo "ASM DISKS  : ` find /dev -type b -user oracle  | grep -v /dev/pts 2>/dev/null |wc -l`"

elif [ "$OS" == "AIX" ]
then

echo "ACTIVE LVM DISKS : `lspv | grep power | grep active | wc -l|xargs`"
echo "ASM DISKS : `find /dev -type c -user oracle | egrep 'power|asm|hdisk'  | grep -v /dev/pts 2>/dev/null | wc -l | xargs`"

fi

if [ -f /usr/lpp/mmfs/bin/mmlsnsd ]
        then
                echo "GPFS DISKS : `/usr/lpp/mmfs/bin/mmlsnsd -X | grep $(uname -n) | grep server | grep -v "not found" | wc -l | xargs ` "

        fi

fi


if [ "$veritas" == "yes" ]
then
echo "VERITAS DISKS : `vxprint -hrt | grep "^dm" |wc -l`"
echo
echo "VERITAS DISK GROUP DETAILS"
 echo "==================================================================="
 /net/ccuaweb3/export/scripts/WTS/veritas_dginfo.sh
  echo "==================================================================="
ps -ef | grep -wi hashadow | grep -v grep > /dev/null
if [ $? -eq 0 ]
then
echo
echo "This node is in VCS cluster and below are the cluster pairs , verify storage on both nodes "
/opt/VRTSvcs/bin/hasys -list
fi

fi
