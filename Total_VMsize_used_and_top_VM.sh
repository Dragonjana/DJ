[UAT root @ ccuaweb3 /export/scripts/jc38549]
# cat VMsize/Total_VMsize_used_and_top_VM.sh
#!/bin/bash
#!/bin/sh
# jc38549



for file in /proc/*/status ; do awk '/VmSize|Pid:/{printf $2 " " $3}END{ print ""}' $file; done > /tmp/vmsize_list

cat  /tmp/vmsize_list | grep -i KB | awk '{if ($4 != "0") print $1 " " $4;}' | while read a b ; do  echo "$a  $b";done  > /tmp/vmsize_list1

echo "Total VMsize = `awk '{s+=$2/1024} END {print s}' /tmp/vmsize_list1` Mb"


cat /tmp/vmsize_list1 | sort -rnk 2 | head -20 | while read a b ; do echo "PID ==>$a  VMSIZE ==> $b 'KB'";done


