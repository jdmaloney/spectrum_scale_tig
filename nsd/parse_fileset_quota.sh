#!/bin/bash

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then

source /etc/telegraf/ss_config

for f in ${fs[@]}
do
	cat ${base_path}/${cluster}_${f}_fileset | cut -d':' -f 8,12,33,34 | grep -v filesetName | sed 's/:/\ /g' > /tmp/fileset.out
	while read l; do
		name=$(echo $l | awk '{print $1}')
		maxalloc_inode=$(echo $l | awk '{print $3}')
		used_inode=$(echo $l | awk '{print $4}')
		rawpath=$(echo $l | awk '{print $2}')
		path=$(sudo /usr/lpp/mmfs/bin/mmclidecode "$rawpath")

		## Send to InfluxDB
		echo "fileset,metric=gpfs,name=$name,path=$path maxinode=$maxalloc_inode,usedinode=$used_inode"
	done < /tmp/fileset.out
done
rm -rf /tmp/fileset.out


### Parse Quota

for f in ${fs[@]}
do

awk '
BEGIN{ FS=OFS=":" }
FNR == 1 { ++fidx }
fidx == 1 { umap[$3] = $1; next }
fidx == 2 { gmap[$3] = $1; next }
FNR==1 {next} \
   {fileset=$25} $8 ~ /FILESET/ {fileset=$10} \
   $8 ~ /USR/ { $10 = ($10 in umap ? umap[$10] : $10) } \
   $8 ~ /GRP/ { $10 = ($10 in gmap ? gmap[$10] : $10) } \
   {print "quota,metric=gpfs,fs="$7",fileset="fileset",type="$8",id="$9",name="$10" blockused="$11",blockquota="$12",blocklimit="$13",blockdoubt="$14",filesused="$16",filequota="$17",filelimit="$18",filedoubt="$19}' \
${base_path}/${cluster}_passwd ${base_path}/${cluster}_group ${base_path}/${cluster}_${f}_quota


done

else
	:
fi
