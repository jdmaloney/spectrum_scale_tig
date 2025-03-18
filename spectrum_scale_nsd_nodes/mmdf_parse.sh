#!/bin/bash

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then

tempf=$(mktemp /tmp/mmdf.XXXXXX)

source /etc/telegraf/ss_config

for f in ${fs[@]}
do
	sudo /usr/lpp/mmfs/bin/mmdf $f -Y | grep -v HEADER > $tempf
	while read l; do
		read type <<< "$(echo ${l} | awk -F ":" '{print $2}')"
		case "$type" in
		'nsd')
			read nsdname pool failuregroup meta data size free_kb free frag_kb frag <<< "$(echo ${l} | awk -F ":" '{print $7" "$8" "$10" "$11" "$12" "$9" "$13" "$14" "$15" "$16}')"
			echo "mmdf,fs=$f,type=nsd,nsdname=$nsdname,pool=$pool,failuregroup=$failuregroup,meta=$meta,data=$data,size=$size free=$free,free_kb=$free_kb,frag=$frag,frag_kb=$frag_kb"
		;;
		'poolTotal')
			read pool size free_kb free frag_kb frag <<< "$(echo ${l} | awk -F ":" '{print $7" "$8" "$9" "$10" "$11" "$12}')"
                	echo "mmdf,fs=$f,type=pool,pool=$pool size=$size,free=$free,free_kb=$free_kb,frag=$frag,frag_kb=$frag_kb"
		;;
		'data')
			read size free_kb free frag_kb frag <<< "$(echo ${l} | awk -F ":" '{print $7" "$8" "$9" "$10" "$11}')"
                	echo "mmdf,fs=$f,type=fs,param=data size=$size,free=$free,free_kb=$free_kb,frag=$frag,frag_kb=$frag_kb"
		;;
		'metadata')
			read size free_kb free frag_kb frag <<< "$(echo ${l} | awk -F ":" '{print $7" "$8" "$9" "$10" "$11}')"
                	echo "mmdf,fs=$f,type=fs,param=meta size=$size,free=$free,free_kb=$free_kb,frag=$frag,frag_kb=$frag_kb"
		;;
		'fsTotal')
			read size free_kb free frag_kb frag <<< "$(echo ${l} | awk -F ":" '{print $7" "$8" "$9" "$10" "$11}')"
                	echo "mmdf,fs=$f,type=fs,param=total size=$size,free=$free,free_kb=$free_kb,frag=$frag,frag_kb=$frag_kb"
		;;
		'inode')
			read used free alloc max <<< "$(echo ${l} | awk -F ":" '{print $7" "$8" "$9" "$10}')"
                	echo "mmdf,fs=$f,type=fs,param=inode used=$used,free=$free,alloc=$alloc,max=$max"
		;;
		*)
			echo "Parsing Error"
		;;
		esac
	done < $tempf
done

rm -rf $tempf

else
	:
fi
