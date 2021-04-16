#!/bin/bash

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then
tempf=$(mktemp /tmp/lsdisk.XXXXXX)

source /etc/telegraf/ss_config

for f in ${fs[@]}
do
	sudo /usr/lpp/mmfs/bin/mmlsdisk $f -Y | grep -v HEADER > $tempf
	while read l; do
		read nsdname failuregroup meta data status avail <<< "$(echo ${l} | awk -F ":" '{print $7" "$10" "$11" "$12" "$13" "$14}')"
		if [ "$avail" == "up" ]; then
			avail_state=0
		else
			avail_state=1
		fi
		echo mmlsdisk,fs=$f,nsdname=$nsdname,failuregroup=$failuregroup,meta=$meta,data=$data status=\"$status\",avail=\"$avail\",avail_state=$avail_state
	done < $tempf
done

rm -rf $tempf

else
	:
fi
