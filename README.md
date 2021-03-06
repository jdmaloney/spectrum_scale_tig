# Spectrum Scale TIG

## Description
Telegraf Checks and Grafana Dashboards for Monitoring Spectrum Scale with TIG

### Author
J.D. Maloney --> Sr. HPC Storage Engineer @ NCSA

### Contributors
* J.D. Maloney
* Sean Stevens --> Sr. HPC Storage Engineer @ NCSA

### Development & Disclaimer
This repository exists for public access to this information; we run our own internal git that tracks our production repositories with this information in it (mainly the telegraf check scripts).  I will do my best to regularly sync our internal changes with this repository to keep this up to date.  However because this repo isn't guaranteed to be up to date with our latest, I will not be accepting pull requests.  Lastly of note, while these checks are things we run on our systems and they do not cause any issue, that is not 100% guaranteed in your environment as it will be different and may have different tolerences and behaviors.  Use these scripts and checks at your own risk.

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

## Telegraf Supporting Implementation Details
Most of the above is very flexible and dynamic; care was taken when developing to make this as portable as possible.  However HPC can be complicated and there are some parts that are made a bit rigid to conform to our best practices.  This section details these situations.  You can tweak the scripts in this repo (mainly the parse_fileset_quota.sh script) to get around some of this if it unnecessary in your environment.  

### Auto generation of mmrepquota and mmlsfileset data
The output of these commands is useful both for data ingestion with Telegraf but also other uses.  In our environments for example we print quota stats into user's terminal sessions upon login so they see that information.  That script needs to source its quota information also.  Instead of having all tools that need quota information running their own invocations of mmrepquota/mmlsfileset, we do this centrally and the tools can all parse through these same files.  We dump the output of the mmrepquota and mmlsfileset commands described above on 15 minute intervals; we have a cron job on all NSD servers that checks if it is the cluster manager, and if so dumps this output for all file systems.  

### Auto generation of getent passwd/getent group files
As noted above the parse_fileset_quota.sh script relies on the output of these two commands.  These files are needed to map UIDs and GIDs of users to their pretty names.  We do not run sssd, or similar on our NSD servers as that can cause issues if there is an interuption in LDAP or AD services, and in general it takes longer to run certain commands (like variants of "ls" on directories with a lot of files/sub-directories).  This results in the output of mmrepquota not having the user and group pretty names.  These files provide that mapping so that what goes into the InfluxDB database is easy for humans to understand.  If the server you use to dump mmrepquota data ties into your authentication infrastructure then these files won't be necessary; but you'll want to update the parsing script accordingly.  We update these files regularly via a cron job every hour to ensure we have up to date mappings. 

### Leveraging of Telegraf community plugins
The Telegraf community has developed a large amount of their own plugins for use by everyone.  We leverage some of those for some of these dashboards, the ones we use are the following: cpu, disk, infiniband, mem, processes, system, systemd_units, ipmi_sensor, net.  A couple of the included dashboards pull data that comes from these plugins.  

## Known Bugs
* The detection of cluster deadlock events is not fully reliable at this time; it has not yet proven to catch them all for us.  This will depend on how the deadlock manifests and other cluster state.  Work to harden this is on our task list to work on
* Grabbing the length of the longest waiter is generally very reliable; what we have has been working for us for a bit over a year; however, since we have not seen all possible waiter messages/types in our environment, the regex may not be perfect to catch everything IBM may want to print in the waiter message.  Some edge cases could conceivably crop up and break it if you get waiter messages we haven't seen that defy the current regex. 

## Grafana Dashboards
JSON files that define some of our favorite dashboards and some png screenshots of them are in the granfana directory.  We are tweaking dashboards all the time and these may fall out of date a bit with what we run internally.  Also we tweak some of these queries to optimize dashboard load performance, these tweaks will be specific to your environment.  For example:
* On a panel that plots overall Spectrum Scale file system usage; we use data from Telegraf's native "disk" input plugin.  This runs on all our NSD servers, however since this is a parallel file system and the FS usage is of course the same across all nodes that mount it, we have this query filter to a single one of our NSD servers to limit the plot time.  The hostname of your NSD server will be different so adjust accordingly.  
* On the NSD servers dashboard; we plot the health of some systemd services; these use a query that does not match output from a community input plugin or from a script I've included.  Currently our dashboards use a legacy systemd service check script that we wrote before the community introduced the systemd_units plugin; our migration to this plugin is still ongoing.  We recommend you convert these panel queries to the appropriate ones for the systemd_units plugin.

Some other adjustmenst you will need to make to the panel queris include:
* Some panels ask for the device name or "fs" name, replace the "your_fs0_here" string with your file system's name
* Some panels also require specifiying the relevant file system mount path, yours will be different of course also
* Some of our clusters run services yours may not; eg. ddn-ibsrp may not be something you run.  Feel free to delete that panel; same with muliptath or iptables or any other service panel not relevant
* Your NSD servers may not give you all the same temp/voltage sensors these panels show, feel free to remove or adjust as needed.  These sensor names often vary from vendor to vendor
* The datasource for these panels was anonymized to one name "Spectrum Scale InfluxDB"; Grafana should prompt you to select the backing datasource when you import the JSON files
