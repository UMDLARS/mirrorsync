#!/bin/bash
## Mirror Synchronization Script /usr/local/bin/ubuntu-mirror-sync.sh
## Version 1.01 Updated 13 Feb 2007 by Peter Noble

## Point our log file to somewhere and setup our admin email
log=/var/log/mirrorsync.log

adminmail=root
# Set to 0 if you do not want to receive email
sendemail=1

# Subject is the subject of our email
subject="Ubuntu Mirror Sync "

## Setup the server to mirror
remote=rsync://archive.ubuntu.com/ubuntu

## Setup the local directory / Our mirror
local=/var/www/html/ubuntu

## Initialize some other variables
complete="false"
failures=0
status=1
pid=$$

echo "`date +%x-%R` - $pid - Started Ubuntu Mirror Sync" >> $log

while [[ "$complete" != "true" && $failures -lt 2 ]]; 
do

        if [[ $failures -gt 0 ]]; then
                ## Sleep for 5 minutes for sanity's sake
                ## The most common reason for a failure at this point
		## is that the server updated while you were syncing.

                sleep 5m
        fi

        if [[ $1 == "debug" ]]; then
		# debug, print to stdout
                echo "Working on attempt number $failures"
                rsync -a --delete-after --progress $remote $local
                status=$?
        else
		# not debug -- log to logfile
                rsync -a --delete-after $remote $local >> $log
                status=$?
        fi
        
	# check status for failure
        if [[ $status -ne "0" ]]; then
		# we failed - increment fail count
                complete="false"
                (( failures += 1 ))
        else
		# success!
                echo "`date +%x-%R` - $pid - Finished Ubuntu Mirror Sync" >> $log
        	complete="true"

        fi
done

# Send the email
if [[ -x /usr/bin/mail && "$sendemail" -eq "1" ]]; then

MDSTAT=$(cat /proc/mdstat | grep -v "Personalities" | grep -v "unused devices")
DISKFULL=$(df -h | grep "/dev/md0")

if (( failures > 0 ))
then
	subject="$subject -- ***FAILURES***"
	failline="There were $failures failures."
else
	subject="$subject -- OK"
	failline="There were no failures."
fi

subject="$subject (run: $(date -u +%s))"

mail -s "$subject" "$adminmail" <<OUTMAIL
Summary of Ubuntu Mirror Synchronization
PID: $pid
$failline
Last status (should be 0): $status
Finish Time: `date`

Disk space:
$DISKFULL

RAID1 Status:
$MDSTAT

Sincerely,
$HOSTNAME

OUTMAIL
fi

exit 0
