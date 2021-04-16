#!/bin/bash

tfile=$(mktemp /tmp/multipath.XXXXX)
sudo multipath -ll > ${tfile}

## If there is a Mellanox switch pair between the DDN(s) and the NSD servers, set the below variable to 1
source /etc/telegraf/ss_config

lun_count=$(cat ${tfile} | grep -E 'DDN|NETAPP' | wc -l)

if [ ${ib_san_switch} -eq 0 ]; then
	expected_ready=$((expected_luns*2))
	expected_enabled=${expected_luns}
	found_ready=$(cat ${tfile} | grep -EA5 'DDN|NETAPP' | grep "active ready running" | wc -l)
	found_active=$(cat ${tfile} | grep -EA5 'DDN|NETAPP' | grep "status=active" | wc -l)
	found_enabled=$(cat ${tfile} | grep -EA5 'DDN|NETAPP' | grep "status=enabled" | wc -l)
elif [ ${ib_san_switch} -eq 1 ]; then
	expected_ready=$((expected_luns*4))
	expected_enabled=$((expected_luns*3))
	found_ready=$(cat ${tfile} | grep -EA9 'DDN|NETAPP' | grep "active ready running" | wc -l)
	found_active=$(cat ${tfile} | grep -EA9 'DDN|NETAPP' | grep "status=active" | wc -l)
	found_enabled=$(cat ${tfile} | grep -EA9 'DDN|NETAPP' | grep "status=enabled" | wc -l)
fi

if [ ${expected_luns} -eq ${lun_count} ] && [ ${expected_luns} -eq ${found_active} ] && [ ${expected_enabled} -eq ${found_enabled} ] && [ ${expected_ready} -eq ${found_ready} ]; then
	echo multipath_health luns=${lun_count},ready=${found_ready},active=${found_active},enabled=${found_enabled},state=0

else
	echo multipath_health luns=${lun_count},ready=${found_ready},active=${found_active},enabled=${found_enabled},state=1
fi

rm -rf ${tfile}
