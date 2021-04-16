#!/bin/bash

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then

## Get File System List to Check
all_fs_list=($(cat /etc/fstab | grep gpfs | awk '{print $1}'))
no_mount_list=($(ls /var/mmfs/etc/ | grep -i ignoreAnyMount | cut -d'.' -f 2))
fs_list=()
for a in ${all_fs_list[@]}
do
        if [[ ! " ${no_mount_list[@]} " =~ " ${a} " ]]; then
                fs_list+=(${a})
        fi

done

for f in ${fs_list[@]}
do
	count=$(/usr/lpp/mmfs/bin/mmlsmount ${f} | awk '{print $(NF-1)}')
	echo gpfsmountcount,fs=${f} count=${count}
done

### Run deadlock check
deadlock_file=$(mktemp /tmp/dlcheck.XXXXXXX)
sudo /usr/lpp/mmfs/bin/mmdiag --deadlock > ${deadlock_file}
is_deadlock=$(cat ${deadlock_file} | grep -i waiting)
if [ -z ${is_deadlock} ]; then
	clusters=($(cat ${deadlock_file} | grep Cluster | awk '{print $2}' | xargs))
	for c in ${clusters[@]}
	do
		overload_index=$(cat ${deadlock_file} | grep overload | grep ${c} | awk '{print $NF}')
		echo deadlock_detect,cluster=${c} overload_index=${overload_index},deadlock=0,duration=0.0
	done
else
	duration=$(cat ${deadlock_file} | grep -i waiting | sed 's/.*[Ww]aiting //;s/ sec.*//')
	echo deadlock_detect overload_index=100,deadlock=1,duration=${duration}
fi
rm -rf ${deadlock_file}


else
	:
fi
