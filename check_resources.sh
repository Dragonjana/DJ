[UAT root @ ccuaweb3 ~]
# cat /export/scripts/check_resources.sh
#!/bin/bash

# NAME:        check_resources.sh
# VERSION:     1.4
# DATE:               Wed Nov 21 16:57:10 EST 2012
# AUTHOR:      Tommy Butler <tommy.butler@citi.com>
# LICENSE:     Citigroup internal use only,
# COPYRIGHT:   Copyright Citicorp 2012, All Rights Reserved
# PURPOSE:     Report if a machine is CPU, memory, network, or I/O bound
# NOTES:       Should not need to be run with root privileges.

# If I have to explain the reason for the aliases below then
# you should consider studying a bit of unix scripting security
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin

FREE=/usr/bin/free
TOP=/usr/bin/top
PS=/bin/ps
CAT=/bin/cat
DF=/bin/df
W=/usr/bin/w
UPTIME=/usr/bin/uptime
SED=/bin/sed
GREP=/bin/grep
HEAD=/usr/bin/head
TAC=/usr/bin/tac
PERL=/usr/bin/perl
AWK=/bin/awk
TR=/usr/bin/tr
IOSTAT=/usr/bin/iostat
WC=/usr/bin/wc
PRINTF=/usr/bin/printf
HOSTNAME=/bin/hostname
SORT=/bin/sort
COLUMN=/usr/bin/column

cpucount="$( $CAT /proc/cpuinfo | $GREP '^processor\W' | $WC -l )"
load5min="$( $UPTIME | $SED 's/.*load average: \([0-9]\{1,\}\.[0-9]\{2\}\),.*/\1/' )"
iowait="$( $TOP -bn1 | $HEAD | $GREP '%wa' | $SED 's/.*\([0-9]\{1,\}\.[0-9]\)%wa.*/\1/' )"
swaptotal=$( $FREE | $GREP Swap | $AWK '{ print $2 }')
swapused=$( $FREE | $GREP Swap | $AWK '{ print $3 }')
swapused=$( $PERL -e "printf '%0.6f', +( $swapused / $swaptotal ) * 100" )

echo '.--------------------------------------------------------------------.'
banner="RESOURCE REPORT FOR `$HOSTNAME -f` `$HOSTNAME -i`"
$PRINTF "| %-66s |\n" "$banner"
echo "'--------------------------------------------------------------------'"
echo
echo  CPU
echo "   ( Load to processor ratio must be less than 1.0 per processor )"
echo "      Number of CPUs: $cpucount";
echo "      5 minute load average: $load5min";


loadok=$( $PERL -e "print $load5min < $cpucount || 0" ) # need float precision

if [[ "$loadok" == "1" ]];
then
   echo "      CPU load to processor ratio is within optimal range.";
else
   echo "      Load exceeds optimal conditions!";
fi

echo
echo I/O AND DISKS
echo "   ( iowait times greater than 20 are BAD when CPU load is not optimal )"
echo "   ( if load optimal, sustained iowait should be lower than 30 )"
echo "      I/O CPU wait time: $iowait";

iowaitok=$( $PERL -e "print +( $iowait < 30 && $loadok ) || 0" ) # need float precision
iowaitwarn=$( $PERL -e "print +( $iowait < 5 && !$loadok ) || 0" ) # need float precision
iowaitalert=$( $PERL -e "print +( $iowait > 20 && !$loadok ) || 0" ) # need float precision

if [[ "$iowaitok" == "1" ]];
then
   echo "      I/O wait metric is within optimal range.";
elif [[ "$iowaitwarn" ]];
then
   echo "      WARNING! I/O wait metric above optimal threshold.";
elif [[ "$iowaitalert" ]];
then
   echo "      ALERT!  I/O WAIT METRIC INDICATES MACHINE IS I/O BOUND!"
fi

echo
echo "   Percentage of swap in use: $swapused%"
echo "      ( swap must be less than 60% to avoid RAM exhaustion and thrashing )"

swapok=$( $PERL -e "print $swapused < 60 || 0" )

if [[ "$swapok" == "1" ]];
then
   echo "      swap usage within acceptable range.";
else
   echo "      CURRENT SWAP USAGE INDICATES POTENTIAL MEMORY EXHAUSTION!";
fi

echo
echo "   Analysis of disk PERFORMANCE utilization--NOT capacity/usage"
echo "      ( optimal values are 50% or lower, report excludes values of 0.00 )"

function iostat_dx {
   $IOSTAT -dx | $SED '1,3d' | {
      wrappedvol=''

      { while read diskstat;
         do
            disk=$( echo $diskstat | $AWK '{ print $1 }' );

            if [[ "$( echo $diskstat | $AWK '{ print $3 }' )" == "" ]];
            then
               wrappedvol="$disk"
               continue;
            fi;

            utilized=$( echo "$wrappedvol $diskstat" | $AWK '{ print $12 }' );

            if [[ "$wrappedvol" != "" ]];
            then
               disk="$wrappedvol"
               wrappedvol=""
            fi;

            [[ "$disk" != "" ]] || continue;

            util_ok=$( $PERL -e "print int( '$utilized' || 0 ) <= 50 || 0" ) # need float precision

            if [[ "$util_ok" == "1" ]]; then
               $PRINTF "Disk %-5s OK  at $utilized%%\n" $disk
            else
               $PRINTF "Disk %-5s NOT-OK at  $utilized%%\n" $disk
            fi;
         done; } | $COLUMN -t | $SORT -k5 -nr | $GREP -v '0\.00' | $SED 's/^/         /'
   }
}

iostat_formatted="$( iostat_dx | $SORT -k5 -nr )"

if [[ "$iostat_formatted" =~ "NOT-OK" ]];
then
   echo "         ALERT!  SOME volumes NOT OK.  Listing all problems:"
   echo "$iostat_formatted" | $GREP 'NOT-OK'
else
   echo "         All volumes OK.  Listing top volumes by utilization:"
   echo "$iostat_formatted" | $HEAD -n10
fi

echo
echo "   Checking for mounted volumes over 80% USAGE..."
echo "      ( greater than 80% indicate potential disk bottlenecks/slowdowns. )"
echo "      ( greater than 90% indicate possible disk thrashing! )"
echo
$DF -hP | $SED 1d | {

   while read useprct;
   do
      volume=$( echo $useprct | $AWK '{ print $1 }' );
      usage=$( echo $useprct | $AWK '{ print $5 }' | sed 's/.$//' );

      if [[ $usage -gt 89 ]];
      then
         printf "      ALERT! %3d%% ON $volume\n" $usage
      elif [[ $usage -gt 79 ]];
      then
         printf "      WARN!  %3d%% ON $volume\n" $usage
      fi;
   done;

   echo "   ...done with disk usage checks.  Please note any warnings/alerts."
}

echo
echo MEMORY

$FREE | $GREP Mem | $AWK '{ print $2, $3, $4, $6, $7 }' | $TR ' ' '\n' | {

   read total;
   read used;
   read free;
   read buffered;
   read cached;

   percent_used=$( $PERL -e "printf '%0.2f', +( ( $used - $buffered - $cached ) * 100 ) / $total" );
   memok=$( $PERL -e "print $percent_used <= 90 || 0" ) # need float precision

   echo "   Real percentage of memory in use: $percent_used%";

   if [[ "$memok" == 1 ]];
   then
      echo "   True memory usage within acceptable range (less than 90%)";
   else
      echo "   MEMORY USAGE ABOVE 90%!  SYSTEM STABILITY AT RISK!";
   fi
}

echo
echo NETWORK
echo "   Collision to TX percentages per interface, including any bond/vmnic"
echo "      ( rates greater than 5% indicate network saturation )"

$PERL -e '$netstat = qx{/bin/netstat -ie | /bin/sed 1d}; $netstat =~ s/(^\w+).*?TX packets:(\d+).*?collisions:(\d+)/push @ints, { int => $1, tx => $2, cls => $3 }/gsme; @ints = grep { $_->{int} ne "lo" } @ints; for ( @ints ) { $clspcnt = ( $_->{cls} * 100) / $_->{tx}; printf "%12s: %-.2f%%", $_->{int}, $clspcnt; print $clspcnt >= 5 ? " DANGER, APPROACHING NETWORK SATURATION!!!\n" : " - OK, within acceptable range\n" };'

echo
echo EXTRA
echo "   Top active processes by CPU usage, excluding zero-CPU (sleeping) proc's"
echo "   If this list is empty, all processes are \"S\" status (sleeping)"
$CAT <<EOF | $COLUMN -tc80 | $SED 's/^/   /'
USE% PID TASK
$( $PS -eo pmem,pid,comm | $SED 1d | $GREP -v '^ 0.0' | $SORT -nr | $HEAD -n10 )
EOF

echo
echo "   Top processes by MEMORY usage, excluding zero-RAM (swapped out) proc's"
$CAT <<EOF | $COLUMN -tc80 | $SED 's/^/   /'
USE% USE(kb) PID TASK
$( $PS -eo pcpu,rss,pid,comm | $SED 1d | $GREP -v '^ 0.0' | $SORT -nr | $HEAD -n10 )
EOF


echo
echo '_ _ _ _ _ _ _ _ _ _ _ _ _ END OF REPORT _ _ _ _ _ _ _ _ _ _ _ _ _ _ _'
echo

exit
