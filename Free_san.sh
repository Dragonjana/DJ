#!/bin/bash
#!/bin/sh
#!/bin/ksh
# jc38549
# Free disk finder in LINUX box V4

case `/bin/uname` in
        SunOS)
                echo "This scirpt is for only AIX and LINUX OS, exiting.";
                exit 1;
        ;;
        AIX)
                /net/ccuaweb3/export/scripts/WTS/total_san.lvm_asm.sh.tmp;
				lspv | grep -i power | while read a b c 
				do
					if [ $b == none ] && [ $c == None ]
					then 
						echo $a `lquerypv -h /dev/$a 40 50 | egrep -i '40|80'|awk '{print  $1" "$6$7$8}'|sed 'N;s/\n/ /'`
					elif [ "$b" != none ] && [ "$c" == None ]
					then	
						echo $a `lquerypv -h /dev/$a 40 50 | egrep -i '40|80'|awk '{print  $1" "$6$7$8}'|sed 'N;s/\n/ /'`
					fi
				done > /tmp/first_list
				echo
				echo "Free PV and VG disk"
				echo "-------------------------"
				for i in `awk '{print $1}' /tmp/first_list`
				do
					lspv | grep -i $i
				done
				echo
				echo
				
				cat /tmp/first_list | awk '$3 == "|................|" && $5 == "|................|" || $2=="" {print $0}' > /tmp/second_list
				
				echo "Header status"
				echo "-------------------------"
				cat /tmp/second_list
				echo
				echo
				
				echo "Disk permission"
				echo "-------------------------"
				for i in `awk '{print $1}' /tmp/second_list`
				do
					ls -ltr /dev/*$i
				echo
				done
				echo
				echo
				
				echo "Free disk size"
				echo "-------------------------"
				for i in `awk '{print $1}' /tmp/second_list`
				do
					ls -ltr /dev/*$i | grep -v oracle|awk '{print $NF}' > /tmp/third_list;
					cat /tmp/third_list | awk -F"/" '{print $NF}' | sed -e '/^rhdisk/d'| while read a 
					do
						echo " $a \c " 
						bootinfo -s $a|awk '{sum+=$1/1024}END{print $1 " " sum }'|awk '$1 > 7 { print $1" GB" }'
					done
				echo
				done
				
				rm /tmp/first_list /tmp/second_list /tmp/third_list 
			echo
			
        ;;
        Linux)

                SSPV=0
                SANGRIA=0
                SANINFO=0

				if [ -f /opt/SSPV/bin/inq -o /opt/VRTS/bin/vxdisk ]
                    then
                        SSPV=1
                
                elif [ -f /opt/SANinfo/bin/inq ]
                    then 
                        SANINFO=1
                elif [ -f /opt/sangria/bin/inq  ]
                    then
                        SANGRIA=1
                fi


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
					echo "`uname -n`  is a VMWARE machine"
					fdisk -l 2>/dev/null | egrep '^Disk'|grep -i GB|egrep -v 'dm-'
					echo "ACTIVE LVM DISKS (includes rootvg) : ` pvdisplay -C --separator : -o pv_name,vg_name 2>/dev/null | grep /dev/sd |   awk -F: '$NF != ""' |wc -l`"
					(id oracle >& /dev/null ) && echo "ASM DISKS  : $(find /dev -type b -user oracle  2>/dev/null | grep -v /dev/pts 2>/dev/null |wc -l)"
				
				cat /proc/partitions|awk '$4 ~ /^sd.$/ { print $4 }' > /tmp/freedisk_list
				pvs | grep -i dev | awk '{print $1}'| awk -F"/" '{print $3}'| sed 's/[0-9]*//g' >> /tmp/freedisk_list
				if [ -f /etc/udev/rules.d/99-oracle.rules ]; 
				then
					cat /etc/udev/rules.d/99-oracle.rules |awk -F'"' '{print $2}' | awk -F'"' '{print $1}' >> /tmp/freedisk_list;
				fi
				
				echo 
				
				freeVM=`cat /tmp/freedisk_list | sort | uniq -u |wc -l`
				
				if [ $freeVM -eq 0 ]
				then
				echo " Total storage disk size ==> $TOTALSAN GB"
				
				echo " There is no any unallocated/unpartition disk available on `uname -n`"
				else
				
				
				echo " Free Disk details "
				echo "-------------------------------------------"
				cat /tmp/freedisk_list | sort | uniq -u | while read a ; do fdisk -ll 2>/dev/null| grep -w /dev/$a | awk '{print $2" " $3 " " $4}'; done
				echo "-------------------------------------------"
				
				echo " Total storage disk size ==> $TOTALSAN GB"
				echo " Total free disk size ==> `cat /tmp/freedisk_list | sort | uniq -u | while read a ; do fdisk -ll 2>/dev/null | grep -w /dev/$a | awk '{print $2" " $3 " " $4}'; done|awk {'sum+=$2}END{print sum'}`"
				
				fi
					
                else

                /net/ccuaweb3/export/scripts/WTS/total_san.lvm_asm.sh.tmp  | tee /tmp/SAN_output

                TUASD=`echo $(( $( cat /tmp/SAN_output| egrep -i "disk" | grep -v "=" | awk -F":" '{print $2}'| tr "\n" "-" | xargs -I{} echo {} 0  ) ))`
                echo


				if [ $SSPV -eq 1 ]
                    then
                        CN="SSPV"
                
                elif [ $SANINFO -eq 1 ]
                    then
                        CN="SANINFO"
                elif [ $SANGRIA -eq 1 ]
                    then
						CN="SANGRIA"
                fi

                case "${CN}" in
                        "SANGRIA" ) 
                        if [[ $TUASD != 0 ]]; then
                                echo "Disk different is $TUASD "
                                echo
                                echo "This node is in multipath. This may take a few moments, so be patient.."
                                echo "---------------------------------------------------------------"
                                echo
                                echo "Free disk  Size"
                                echo "----------------------------"
                                > /tmp/Udisk_list
                                        multipath -ll | grep -i mpath | awk '{print $1}' > /tmp/Udisk_list

                                        pvs 2>/dev/null | grep -i mpath | awk '{print $1}' | awk -F "/" '{print $4}' | sed 's#p1##g' >> /tmp/Udisk_list
										if [ -f /etc/udev/rules.d/99-oracle.rules ]; 
										then
											cat /etc/udev/rules.d/99-oracle.rules |awk -F'mpath-' '{print $2}' | awk -F'"' '{print $1}' | while read i; do multipath -ll | grep -w $i | awk '{print $1}'; done >> /tmp/Udisk_list
										fi
                                                cat /tmp/Udisk_list | sort | uniq -u | while read i; do lvmdiskscan |grep -i /dev/mapper/$i|awk '$3 > 7  { print $1 " " $3" GB"  }'; done
                                                echo "----------------------------"
                                                echo "  `grep -i space /tmp/SAN_output`"
                                                echo " Total Free SAN space ==> `cat /tmp/Udisk_list | sort | uniq -u | while read i; do lvmdiskscan |grep -i /dev/mapper/$i; done|awk '{sum+=$3}END{print sum "GB"}'`"

                                                if [ -f /opt/VRTS/bin/hastatus ]
                                                then
                                                        echo "This is Cluster server, Kindly check with other node";
                                                        echo "`/opt/VRTS/bin/hasys -list`";
                                                fi

                        else
                                echo
                                echo " There is no any unallocated/unpartition disk available on `uname -n`"
                        fi
                        ;;
                        "SANINFO" ) 
                        if [[ $TUASD != 0 ]]; then
                                echo "Disk different is $TUASD "
                                echo
                                echo "This node is in powerpath, Please wait until data is being fetched"
                                echo "------------------------------------------------------------------"
                                echo
                                echo "       Free disk                  Size"
                                echo "-------------------------------------------------------------------"
                                > /tmp/Udisk_list
                                        /opt/SANinfo/bin/inq -nodots | grep -i power | awk '{print $1}' | awk -F "/" '{print $3}' > /tmp/Udisk_list

                                        pvs | grep -i power | awk '{print $1}' | awk -F "/" '{print $3}' | tr -d "1" >> /tmp/Udisk_list
										if [ -f /etc/udev/rules.d/99-oracle.rules ]; 
										then
											cat /etc/udev/rules.d/99-oracle.rules | grep -i power |awk -F "\"" '{print $2}' | tr -d "1" >> /tmp/Udisk_list
										fi
                                                cat /tmp/Udisk_list | sort | uniq -u | while read i; do lvmdiskscan |grep -i /dev/$i|awk '$3 > 7  { print $1 " " $3" GB"  }'; done
                                                echo "----------------------------"
                                                echo "  `grep -i space /tmp/SAN_output`"
                                                echo " Total Free SAN space  ==> `cat /tmp/Udisk_list | sort | uniq -u | while read i; do lvmdiskscan |grep -i /dev/$i; done|awk '{sum+=$3}END{print sum "GB"}'`"
                        else
                                echo
                                echo " There is no any unallocated/unpartition disk available on `uname -n`"
                        fi
                        ;;
                        "SSPV" )
                                #echo "ASSIGNED VERITAS DISKS : `vxprint -hrt | grep "^dm" |wc -l`"
                                #echo
                                #echo "VERITAS DISK GROUP DETAILS"
                                #echo "==================================================================="
                                #printf "%-20s%-20s%-10s%-10s%-20s\n" "DGNAME" "Total Size" "NVOL" "NDISK" "Free Space"
                                #for dgname in `vxdg list | grep enabled |awk '{print $1}'`
                                #do 
                                #       TS=`vxprint -g $dgname -dF "%publen" | awk 'BEGIN {s = 0} {s += $1} END {print s/2097152, "GB"}'`
                                #       NV=`vxprint -hrtg $dgname | grep "^v" |wc -l | tr -d " "`
                                #       ND=`vxprint -hrtg $dgname | grep "^dm" |wc -l | tr -d " "`
                                #       val=$(vxassist -g $dgname maxsize 2>/dev/null || echo 0)  
                                #       FS=`echo $val |  awk '{print $NF}' | tr -d '(' | tr -d ')'`
                                #printf "%-20s%-20s%-10s%-10s%-20s\n" $dgname "$TS" "$NV" "$ND" "$FS"
                                #done
						ps -ef | grep -wi hashadow | grep -v grep > /dev/null
						if [ $? -eq 0 ]
						then
							echo
							Rnode=`vxdisk -eo alldgs list| awk '(index($4, "(") != 0) {print $4}'|sort -nrk 4| uniq -c | awk '{ sum += $1 } END { print sum }'`
							echo " $Rnode disk are mapped with other node "
							echo "========================================"
							vxdisk -eo alldgs list| awk '(index($4, "(") != 0) {print $4}'|sort -nrk 4| uniq -c
						fi
                        echo "==================================================================="

                        echo " Free Disk details "
                        echo "-------------------------------------------"
                                vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("

                        echo
                        echo " Free disk size (except quourm disk's)"
                        echo "-------------------------------------------"
							if [ -f /opt/SSPV/bin/inq ]
							then
                                
								vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("| awk '{print $1}' | while  read a ; do /opt/SSPV/bin/inq -nodots | grep -w $a |awk '{sum+=$7/1024/1024}END{print $1 " " sum }'|awk '$2 > 7 { print $1 " " $2" GB" }' ;done;
								vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("| awk '{print $1}' | while  read a ; do /opt/SSPV/bin/inq -nodots | grep -w $a |awk '{sum+=$7/1024/1024}END{print $1 " " sum }'|awk '{ print $1 " " $2}' ;done > /tmp/freedisk1_list;
								#TF=`awk '{s+=$1} END {printf "%.0f", s}' /tmp/freedisk1_list`
								#[[ $TF -le 10 ]] || { echo " There is no any unallocated/unpartition disk available on `uname -n`"; }
								
                			elif [ -f /opt/SANinfo/bin/inq ]
							then
                                vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("| awk '{print $1}' | while  read a ; do /opt/SANinfo/bin/inq -nodots | grep -w $a |grep -v "/vx/"|awk '{sum+=$7/1024/1024}END{print $1 " " sum }'|awk '$2 > 7 { print $1 " " $2" GB" }' ;done;
								vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("| awk '{print $1}' | while  read a ; do /opt/SANinfo/bin/inq -nodots | grep -w $a |grep -v "/vx/"|awk '{sum+=$7/1024/1024}END{print $1 " " sum }'|awk '{ print $2}' ;done > /tmp/freedisk1_list;
								#TF=`awk '{s+=$1} END {printf "%.0f", s}' /tmp/freedisk1_list`							
								#[[ $TF -le 10 ]] || { echo " There is no any unallocated/unpartition disk available on `uname -n`"; }                          
							fi
							TF=`awk '{s+=$2} END {printf "%.0f", s}' /tmp/freedisk1_list`
							 if [ $TF -le 10 ]; then
								echo
								echo " There is no any unallocated/unpartition disk available on `uname -n`"
								echo
							 fi 

							
                        echo "-------------------------------------------"
						echo " `grep -i 'Total SAN space' /tmp/SAN_output`"
                        echo " Total Used SAN space  ==> `vxprint -hrt | grep "^dm" |awk '{sum+=$6/2/1024/1024}END{print sum "GB"}'`"
						if [ -f /opt/SSPV/bin/inq ]
							then
                        echo " Total Free SAN space  ==> ` vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("| awk '{print $1}' | while  read a ; do /opt/SSPV/bin/inq -nodots | grep -w $a |awk '{sum+=$7/1024/1024}END{print $1 " " sum }'|awk '$2 > 7 { print $1 " " $2" GB" }' ;done|awk '{sum+=$2}END{print sum "GB"}'`"
						elif [ -f /opt/SANinfo/bin/inq ]
							then
							echo " Total Free SAN space  ==> ` vxdisk -eo alldgs list | awk '{if ($4 == "-") print $0;}'|egrep -v "cciss|disk_|_dg|\("| awk '{print $1}' | while  read a ; do /opt/SANinfo/bin/inq -nodots |grep -v "/vx/"| grep -w $a |awk '{sum+=$7/1024/1024}END{print $1 " " sum }'|awk '$2 > 7 { print $1 " " $2" GB" }' ;done|awk '{sum+=$2}END{print sum "GB"}'`"
						fi
                        echo "==================================================================="
                        #ps -ef | grep -wi hashadow | grep -v grep > /dev/null
                        #if [ $? -eq 0 ]
                        #       then
                        #       echo
                        #       echo "This node is in VCS cluster and below are the cluster pairs , verify storage on both nodes "
                        #               /opt/VRTSvcs/bin/hasys -list
                        #fi
                        ;;
                        *) echo "This node is in not in SANGRIA , SANINFO or SSPV ";;
                        esac
                fi

                ;;
        *)
                echo "This is not a recognized OS, exiting.";
                exit 1;
                ;;
esac
rm -rf /tmp/freedisk_list /tmp/SAN_output /tmp/Udisk_list /tmp/freedisk1_list
