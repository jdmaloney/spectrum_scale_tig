#!/bin/bash

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then

sudo /usr/lpp/mmfs/bin/mmpmon -i /etc/telegraf/mmpmon/infile_clients -p | awk '!/_rc_ 0/ {next;} /fs_io_s/ {print "gpfsperf,fs="$15",node="$5" br="$19",bw="$21",oc="$23",cc="$25",rr="$27",wr="$29}'

sudo /usr/lpp/mmfs/bin/mmpmon -i /etc/telegraf/mmpmon/infile_nsd -p > /tmp/nsd_perf.out
awk '
# read in mapfile
NR==FNR { nsds[$2]=$1; next; }
# skip lines with RC==1
!/_rc_ 0/ {next;}
# process nsd_ds lines
/_nsd_ds_/ {
   nsd=$15;
   node=$5;
   for(i=0;i<=1;i++) {
      getline;
      if($1 ~ /^_r_/) {
         rops=$3;
         rbytes=$5;
      }
      if($1~/^_w_/) {
         wops=$3;
         wbytes=$5;
      }
   }
   printf "gpfsnsdperf,fs=%s,node=%s,nsd=%s rops=%s,wops=%s,rbytes=%s,wbytes=%s\n",nsds[nsd],node,nsd,rops,wops,rbytes,wbytes;
}' /etc/telegraf/mmpmon/nsd_map /tmp/nsd_perf.out

rm -rf /tmp/nsd_perf.out

else
	:
fi
