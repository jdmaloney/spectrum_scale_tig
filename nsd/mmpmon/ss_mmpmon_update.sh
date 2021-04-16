#!/bin/bash

## Updates infiles and map for I/O Performance Metrics

/usr/lpp/mmfs/bin/mmlsnsd -Y > /tmp/mmlsnsd.out

## NSD Map File
cat /tmp/mmlsnsd.out | grep -v HEADER | cut -d':' -f 7,8 | sed 's/^:/none:/' | sed 's/:/\ /' > /etc/telegraf/mmpmon/nsd_map

## NSD infile
cat /tmp/mmlsnsd.out | grep -v HEADER | cut -d':' -f 10 | tr , '\n' | sort -u | xargs | sed 's/^/nlist\ add\ /' > /etc/telegraf/mmpmon/infile_nsd.new
echo nsd_ds >> /etc/telegraf/mmpmon/infile_nsd.new
mv /etc/telegraf/mmpmon/infile_nsd.new /etc/telegraf/mmpmon/infile_nsd

rm -rf /tmp/mmlsnsd.out

## Client infile
/usr/lpp/mmfs/bin/mmlscluster -Y | grep ":clusterNode:" | grep -v HEADER | cut -d':' -f 10 | sed 's/^/nlist\ add\ /' > /etc/telegraf/mmpmon/infile_clients.new
clusternodecount=$(cat /etc/telegraf/mmpmon/infile_clients.new | wc -l)
cat <<EOT >> /etc/telegraf/mmpmon/infile_clients.new
fs_io_s
reset
EOT
mv /etc/telegraf/mmpmon/infile_clients.new /etc/telegraf/mmpmon/infile_clients

echo gpfsclustersize count=${clusternodecount}
