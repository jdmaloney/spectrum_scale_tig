# Spectrum Scale TIG Repository

## Description
Telegraf Checks and Grafana Dashboards for Monitoring GPFS with TIG

### Author
J.D. Maloney --> Sr. HPC Storage Engineer @ NCSA

### Contributors
J.D. Maloney
Sean Stevens --> Sr. HPC Storage Engineer @ NCSA

## Deployment Details

### Telegraf

* Install Telegraf per its standard documentation
* If machine is an NSD server or participates in quorum (generally if machine is licensed as a server): 
  * Place the contents of the "nsd" directory in this repo AS WELL AS the contents of the "all" directory in this repo in the /etc/telegraf directory
  * If needed edit the ss_nsd_server.conf file to set appropriate frequency of the various checks to ones you are comfortable with; the assumed frequency unless specified is 1 minute
  * Place the ss_nsd_server.conf file in the /etc/telegraf/telegraf.d directory
  * If needed edit the ss_client.conf file to set appropriate frequency of the check to one you are comfortable with; the assumed frequency unless specified is 1 minute
  * Place the ss_client.conf file in the /etc/telegraf/telegraf.d directory
  * Edit the ss_config file to contain the approparite information (see note below with regard to the base_path variable); the ss_config file in the nsd directory in this repo supercedes the one that comes from the "all" directory
  * Give the telegraf user the ability to sudo to run the following Spectrum Scale commands: mmdf, mmlsdisk, mmgetstate, mmlsmgr, mmlsmount, mmclidecode, mmdiag, mmlscluster, mmpmon
  * Give the telegraf user the ability to sudo to run the following general linux commands: multipath
  * Make sure the telegraf user has permission to execute all scripts and read all config files; usually a "chown -R telegraf /etc/telegraf" is sufficient

* If a machine is a client: 
  * Place the contents of the "all" directory in this repo in the /etc/telegraf directory
  * If needed edit the ss_client.conf file to set appropriate frequency of the check to one you are comfortable with; the assumed frequency unless specified is 1 minute
  * Place the ss_client.conf file in the /etc/telegraf/telegraf.d directory
  * Edit the ss_config file to contain the appropriate information
  * Give the telegraf user the ability to sudo to run the following Spectrum Scale commands: mmdiag
  * Make sure the telegraf user has permission to execute all scripts and read all config files; usually a "chown -R telegraf /etc/telegraf" is sufficient

NOTE: With regard to the base_path variable -- The parse_fileset_quota.sh script expects the output of "mmlsfileset $device -L -Y", "mmrepquota -Y $device", "getent passwd", and "getent group" to be located in the directory path specified by this variable.  This generally should be somewhere on the Spectrum Scale File System (eg. an admin diretory or something).  File names for the output of the aformentioned commands are expected to be: $cluster_$fs_fileset, $cluster_$fs_quota, $cluster_passwd, $cluster_group.  This format can be observed by reading the parse_fileset_quota.sh script.  Details on the reasoning behind this is in supporting implementation details below.

### Telegraf Supporting Implementation Details
Most of the above is very flexible and dynamic; care was taken when developing to make this as portable as possible.  However HPC can be complicated and there are some parts that are made a bit rigid to conform to our best practices.  This section details these situations.  You can tweak the scripts in this repo (mainly the parse_fileset_quota.sh script) to get around some of this if it unnecessary in your environment.  

#### Auto generation of mmrepquota and mmlsfileset data
The output of these commands is useful both for data ingestion with Telegraf but also other uses.  In our environments for example we print quota stats into user's terminal sessions upon login so they see that information.  That script needs to source its quota information also.  Instead of having all tools that need quota information running their own invocations of mmrepquota/mmlsfileset, we do this centrally and the tools can all parse through these same files.  We dump the output of the mmrepquota and mmlsfileset commands described above on 15 minute intervals; we have a cron job on all NSD servers that checks if it is the cluster manager, and if so dumps this output for all file systems.  

#### Auto generation of getent passwd/getent group files
As noted above the parse_fileset_quota.sh script relies on the output of these two commands.  These files are needed to map UIDs and GIDs of users to their pretty names.  We do not run sssd, or similar on our NSD servers as that can cause issues if there is an interuption in LDAP or AD services, and in general it takes longer to run certain commands (like variants of "ls" on directories with a lot of files/sub-directories).  This results in the output of mmrepquota not having the user and group pretty names.  These files provide that mapping so that what goes into the InfluxDB database is easy for humans to understand.  If the server you use to dump mmrepquota data ties into your authentication infrastructure then these files won't be necessary; but you'll want to update the parsing script accordingly.  We update these files regularly via a cron job every hour to ensure we have up to date mappings. 

### Grafana Dashboards

