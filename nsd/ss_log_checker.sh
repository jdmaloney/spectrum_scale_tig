#!/bin/bash

tfile=$(mktemp /tmp/mmlog.XXXXXXX)

awk '($0 >= from)' from="$(LC_ALL=C date +'%Y-%m-%d_%H:%M:%S.%3N-0600' -d -1minute)" /var/adm/ras/mmfs.log.latest | tail -n +5 > ${tfile}

###
### Cluster Expels ###
##

myid=$(sudo /usr/lpp/mmfs/bin/mmgetstate | awk 'END {print $2}')
cmgr=$(sudo /usr/lpp/mmfs/bin/mmlsmgr -c | cut -d'(' -f 2 | cut -d')' -f 1)

if [[ "$cmgr" == *"$myid"* ]]; then
expel_count=$(cat ${tfile} | grep 'is being expelled\|Expelling' | wc -l)
echo mmfsd_log,match_rule=node_expel count=${expel_count}
fi


##
### IB Errors ###
##

## Example string match: IBV_WC_RETRY_EXC_ERR ##
ib_errors=$(cat ${tfile} | grep "IBV_WC_RETRY_EXC_ERR" | wc -l)
echo mmfsd_log,match_rule=ib_errors count=${ib_errors}


rm -rf ${tfile}
