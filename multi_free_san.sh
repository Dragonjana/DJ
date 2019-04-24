if [ -f /opt/sangria/bin/inq -o /sbin/multipath ]
then
> /tmp/Disk_list.txt

multipathd show maps format "%n %S"|awk '{if (NR>1)print}'|awk '{print $1}' > /tmp/Disk_list.txt

mpath_disk=$(multipathd show maps format "%n %S"|awk '{if (NR>1)print}'|wc -l)
echo "Total disk under multipath ---> $mpath_disk"

for d in `multipathd show maps format "%n %S"|awk '{if (NR>1)print}'|awk '{print $2}'|sort -u`
do
disk_count=$(multipathd show maps format "%n %S"|awk '{if (NR>1)print}'|grep $d|wc -l)
echo " Number of multipath disk with $d size ---> $disk_count"
done

pvs|grep mapper |cut -d'/' -f4| awk '{print $1}'|sed 's#p1##g' >> /tmp/Disk_list.txt

lvm_disk=$(pvs|grep mapper|wc -l)
echo "Number of Multipath disk under LVM ---> $lvm_disk"

if [ -f /etc/udev/rules.d/99-oracle.rules ]
then
cat /etc/udev/rules.d/99-oracle.rules | awk -F'mpath-' '{print $2}'|awk -F'"' '{print $1}' > /tmp/udev_list.txt
cat  /tmp/udev_list.txt | while read a 
do
multipath -ll|grep -i $a|awk '{print $1}' >> /tmp/Disk_list.txt
done

t_asm_disk=$(cat /etc/udev/rules.d/99-oracle.rules|grep -i "^KERNEL"|grep -i oracl|wc -l)
echo "Total disk allocated to ASM ---> $t_asm_disk"
fi
fi
f_disk=$(echo " $mpath_disk-($t_asm_disk+$lvm_disk)"|bc)
echo "Number of free disk available ---> $f_disk "
echo "---------------------------------------"

cat /tmp/Disk_list.txt| sort | uniq -u > /tmp/Free_disk_list1

echo " Free disk size (except quourm disk's)"
for i in ` cat /tmp/Free_disk_list1` ; do multipathd show maps format "%n %S"|grep -i $i; done|sort -nk 2|sed 's/G//g'|awk '($2 > 7 )'|sed 's/$/G/'|tee /tmp/Free_disk_list
echo "---------------------------------"
echo " Total Free Disk Space : `cat /tmp/Free_disk_list | awk '{print $2}'|sed 's/G//g'|awk '{sum+=$1}END{print sum "GB"}'`"

