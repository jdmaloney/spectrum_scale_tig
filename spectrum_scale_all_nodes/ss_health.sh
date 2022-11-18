#!/bin/bash

## Check if GPFS is up
if [ $(ps -ef | grep "/usr/lpp/mmfs/bin/mmfsd" | grep -v grep | wc -l) -eq 1 ]; then
echo "ss_health,health_check=mmfsd_up up=1"

source /etc/telegraf/ss_config

## Waiters
wtemp=$(mktemp /tmp/waiter.XXXXX)
sudo /usr/lpp/mmfs/bin/mmdiag --waiters | grep -v = | tail -n +2 > ${wtemp}
count_w=$(cat ${wtemp} | wc -l)
if [ $count_w -ne 0 ]; then
    longest_w=$(head -1 ${wtemp} | cut -d',' -f 1 | sed 's/.*[Ww]aiting //;s/ sec.*//')
else
    longest_w=0.0
fi
rm -rf ${wtemp}

## mmfsd Info
pid=$(ps -ef | grep mmfsd | grep lpp | awk '{print $2}')
read -r cpu_usage mem_usage <<< $(top -b -n 2 -p $pid | grep mmfsd | tail -1 | awk '{print $9,$10}')

if [ -z $cpu_usage ]; then
        cpu_usage=0
        m_count=0
fi
if [ -z $mem_usage ]; then
        mem_usage=0
        m_count=0
fi

echo "ss_health,health_check=waitercount,type=client count=$count_w"
echo "ss_health,health_check=longestwaiter,type=client length=$longest_w"
echo "ss_health,health_check=daemoncpu,type=client usage=$cpu_usage"
echo "ss_heatlh,health_check=daemonmem,type=client usage=$mem_usage"

## FS Responsive Test ##
tfile1=$(mktemp /tmp/ls.XXXXXX)
tfile2=$(mktemp /tmp/stat.XXXXXXX)

for p in ${paths[@]}
do
	{ time ls ${p} ; } 2> ${tfile1} 1> /dev/null
	min=$(cat ${tfile1} | grep real | awk '{print $2}' | cut -d'm' -f 1)
	sec=$(cat ${tfile1} | grep real | awk '{print $2}' | cut -d'm' -f 2 | cut -d's' -f 1)
	time=$( bc -l <<<"60*$min + $sec" )
	echo "ss_health,health_check=fs_ls_time,path=${p} duration=${time}"
done

for f in ${files[@]}
do
	{ time stat ${f} ; } 2> ${tfile2} 1> /dev/null
	min=$(cat ${tfile2} | grep real | awk '{print $2}' | cut -d'm' -f 1)
	sec=$(cat ${tfile2} | grep real | awk '{print $2}' | cut -d'm' -f 2 | cut -d's' -f 1)
	time=$( bc -l <<<"60*$min + $sec" )
	echo "ss_health,health_check=fs_stat_time,path=${f} duration=${time}"
done

rm -rf $tfile1
rm -rf $tfile2

## Get File System List to Check
all_fs_list=($(cat /etc/fstab | awk '$3 == "gpfs" { print $1 }'))
no_mount_list=($(ls /var/mmfs/etc/ | grep -i ignoreAnyMount | cut -d'.' -f 2))
fs_list=()
for a in ${all_fs_list[@]}
do
	if [[ ! " ${no_mount_list[@]} " =~ " ${a} " ]]; then
		fs_list+=(${a})
	fi

done

## Check the list
for f in ${fs_list[@]}
do
        check=$(grep $f /proc/mounts | grep gpfs)
                if [ -n "$check" ]; then
			#It's in /proc/mounts
                	proc_check=0
		else
			proc_check=1
		fi
	mpoint=$(cat /etc/fstab | grep gpfs | grep ${f} | awk '{print $2}')
	stat=$(stat ${mpoint}/${check_file})
	if [ -n "$stat" ]; then
		#We can stat a file
		stat_check=0
	else
		stat_check=1
	fi
	if [ $proc_check -eq 0 ] && [ $stat_check -eq 0 ]; then
		#All is healthy
		echo "ss_health,health_check=mountcheck,fs=${f} presence=1"
	else
		echo "ss_health,health_check=mountcheck,fs=${f} presence=0"
	fi

done

### mmfsd memory info
read heap pool_1 pool_2 pool_3 <<< "$(sudo /usr/lpp/mmfs/bin/mmdiag --memory | grep bytes | grep -v committed | sed 's/[^0-9]*//g' | xargs)"
echo "ss_health,health_check=mmfsd_memory heap=${heap},pool_1=${pool_1},pool_2=${pool_2},pool_3=${pool_3}"

## mmdiag stats
counters=$(sudo /usr/lpp/mmfs/bin/mmdiag --stats -Y | grep -v HEADER | cut -d':' -f 8-10 | sed 's/:/_/' | sed 's/:/=/' | xargs | sed 's/\ /,/g')
echo "ss_health,health_check=mmdiag_stats ${counters}"

else
        echo "ss_health,health_check=mmfsd_up up=0"
fi
