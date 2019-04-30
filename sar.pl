#!/usr/bin/perl

# written by Chris Purcell (cp90874) on 6/21/2011
# updated on 9/5/2013
# outputs common sar stats into an easier to read format

chomp($uname = `uname`);
if ($uname ne 'Linux') { die "This script was written for Linux\n"; }

if (!$ARGV[0]) { print "usage: $0 [day of the month to check or today]\n"; exit; }
$day = $ARGV[0];
$sar = '/usr/bin/sar';
$free = '/usr/bin/free';
chomp($rhrelease = `cat /etc/redhat-release`);
if ($rhrelease =~ /release (\d)/) { $rh = $1; }

# force sar to output in 24-hour format
$ENV{LC_TIME}="POSIX";

chomp($totalmemKB = `$free | grep Mem | awk \'{print \$2}\'`);
chomp($tmpswap = `$free | grep Swap | awk \'{print \$2,\$3}\'`);
($totalswap,$usedswap) = split(/ /, $tmpswap);

if ($day !~ /today/) {
  if ($day =~ /^\d$/) { $day = '0' . "$day"; }
  $sar_ram = "$sar -f /var/log/sa/sa$day -r";
  $sar_cpu = "$sar -f /var/log/sa/sa$day -p";
  $sar_swap = "$sar -f /var/log/sa/sa$day -S";
  $sar_runq = "$sar -f /var/log/sa/sa$day -q";
} else {
  $sar_ram = "$sar -r";
  $sar_cpu = "$sar -p";
  $sar_swap = "$sar -S";
  $sar_runq = "$sar -q";
}

chomp(@sar_ram = `$sar_ram`);

if ($rh eq '3' or $rh eq '4') {
  chomp(@sar_cpu = `$sar_cpu | grep all | grep -v Average | awk '{print \$1,\$6,\$7}'`);
} else {
  chomp(@sar_cpu = `$sar_cpu | grep all | grep -v Average | awk '{print \$1,\$6,\$8}'`);
}

if ($rh eq '3' or $rh eq '4' or $rh eq '5') {
 foreach (@sar_ram) {
      if ($_ =~ /(..:..:..)\s+(\d+?)\s+\d+\s+..\...\s+(\d+?)\s+(\d+?)\s+\d+?\s+\d+?\s+(.+\...)/) {
         $time = $1;
         $kbmemfree = $2;
         $kbbuffers = $3;
         $kbcached = $4;
         $swpused_perc = $5;
      } 
       $swap_perc = int($swpused_perc) . '%';
       $freememKB = ($kbmemfree + $kbbuffers + $kbcached);
       $usedmemKB = ($totalmemKB - $freememKB);
       $usedperc = sprintf("%2.f", ($usedmemKB/$totalmemKB * 100)) . '%';
       $hash{$time} = "$usedperc;$swap_perc";
 }

# sar changed starting in RH6
} else {
 foreach (@sar_ram) {
      if ($_ =~ /(..:..:..)\s+(\d+?)\s+\d+\s+..\...\s+(\d+?)\s+(\d+?)\s+/) {
         $time = $1;
         $kbmemfree = $2;
         $kbbuffers = $3;
         $kbcached = $4;
      }
       $swap_perc = int($swpused_perc) . '%';
       $freememKB = ($kbmemfree + $kbbuffers + $kbcached);
       $usedmemKB = ($totalmemKB - $freememKB);
       $usedperc = sprintf("%2.f", ($usedmemKB/$totalmemKB * 100)) . '%';
       $hash{$time} = "$usedperc";
 }

 chomp(@sar_swap = `$sar_swap`);
 foreach (@sar_swap) {
    if ($_ =~ /(..:..:..)\s+\d+\s+\d+\s+(\d+\.\d+)\s+/) {
       $time = $1;
       $swpused_perc = $2;
       $swap_perc = int($swpused_perc) . '%';
       $hash{$time} .= ";$swap_perc";
    }
 }

}


foreach (@sar_cpu) {
   ($time,$iowait,$idle) = split(/ /, $_);
   $usedCPU = int(100 - $idle) . '%';
   $iowait = int($iowait) . '%';
   $hash{$time} .= ";$usedCPU;$iowait";
}


chomp(@sar_runq = `$sar_runq | egrep -v "Linux|Average|runq" | awk '{print \$1,\$2}'`);
foreach (@sar_runq) {
   ($time,$runq) = split(/ /, $_);
   $hash{$time} .= ";$runq";
}

foreach $key (sort keys %hash) {
    if ($key =~ /.+/) {
      ($ram,$swap,$cpu,$iowait,$runq) = split(';', $hash{$key});
      $ram = "Memory:  $ram";
      $swap = "Swap:  $swap";
      $cpu = "CPU:  $cpu";
      $iowait = "CPU_IO_wait:  $iowait";
      $runq = "RunQ:  $runq";
format STDOUT =
@<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<
$key                   $ram             $swap         $cpu          $iowait               $runq
.
write STDOUT;
    }
}
