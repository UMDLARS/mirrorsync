#!/bin/bash
## Mirror Synchronization Script /usr/local/bin/ubuntu-mirror-sync.sh
## Version 1.01 Updated 13 Feb 2007 by Peter Noble

## Point our log file to somewhere
log=/var/log/mirrorsync.log

# who should get emails (comma-separated, no spaces!)
adminmail=pahp@d.umn.edu,grif0735@d.umn.edu

# Set to 0 if you do not want to receive email for some reason
sendemail=1

# Subject is the subject of our email
subject="Ubuntu Mirror Sync "

## Setup the server to mirror
#RSYNCSOURCE=rsync://us.rsync.archive.ubuntu.com/ubuntu/
RSYNCSOURCE=rsync://mirror.math.princeton.edu/pub/ubuntu/

## Setup the local directory / Our mirror
BASEDIR=/var/www/html/ubuntu/

## Initialize some other variables
complete="false"
failures=0
retries=2
status=1
pid=$$
debugflags=""

fatal() {
  echo "$1" >> $log
  exit 1
}

warn() {
  echo "$1" >> $log
}


if [[ $1 == "debug" ]]; then
	debugflags="-vP"
	echo "Extra verbosity enabled."
	echo "To watch progress, run 'tail -f $log'..."
	sleep 10
fi

warn "`date +%x-%R` - $pid - Started Ubuntu Mirror Sync" 

if [ ! -d ${BASEDIR} ]; then
  warn "${BASEDIR} does not exist yet, trying to create it..."
  mkdir -p ${BASEDIR} || fatal "Creation of ${BASEDIR} failed."
fi



while [[ "$complete" != "true" && $failures -lt $retries ]]; 
do

        if [[ $failures -gt 0 ]]; then
                ## Sleep for 10 minutes for sanity's sake
                ## The most common reason for a failure at this point
		## is that the server updated while you were syncing.

		warn " - we had a failure. Sleeping for 10m... ($failures failures)" 
                sleep 10m
        fi

	warn "Working on attempt $failures..."

	# step one of rsync
	rsync -a $debugflags --recursive --times --links --safe-links --hard-links \
	  --stats \
	  --exclude "Packages*" --exclude "Sources*" \
	  --exclude "Release*" --exclude "InRelease" \
	  ${RSYNCSOURCE} ${BASEDIR} &>> $log
	
	status=$?

	if [[ $status -ne "0" ]]
	then	
		warn "First stage of sync failed with status $status."
		(( failures += 1))
		continue
	else
		warn "First stage of rsync succeeded."
	fi

	# step two of rsync
	rsync -a $debugflags --recursive --times --links --safe-links --hard-links \
	  --stats --delete --delete-after \
	  ${RSYNCSOURCE} ${BASEDIR} &>> $log

	status=$?

	if [[ $status -ne "0" ]]
	then	
		warn "Second stage of sync failed with status $status."
		(( failures += 1 ))
		continue
	else
		warn "Second stage of rsync succeeded."
	fi

	# if we got here, then we made it!

        # write timestamp to mirror	
	date -u > ${BASEDIR}/project/trace/$(hostname -f)

	warn "Rsync succeeded with status: $status!"
	warn "`date +%x-%R` - $pid - Finished Ubuntu Mirror Sync Successfully!"
	complete="true"

done

# Send the email
if [[ -x /usr/bin/mail && "$sendemail" -eq "1" ]]; then

MDSTAT=$(cat /proc/mdstat | grep -v "Personalities" | grep -v "unused devices")
RAIDSTATUS="RAIDs are not degraded."

# check to see that both RAIDs are completely up.
if ! cat /proc/mdstat | grep "finish" ||
	cat /proc/mdstat | grep -v "Personalities" | grep "[UUU]" > /dev/null &&
	cat /proc/mdstat | grep -v "Personalities" | grep "[UU]" > /dev/null
then
	RAIDSTATUS="One or more RAID devices is degraded! Please inspect manually!"
	failures=$(( failures + 1))
fi
	
DISKFULL=$(df -h | grep "/dev/md")

if (( failures > 0 ))
then
	subject="$subject -- ***FAILURES***"
	failline="There were $failures failures (complete: $complete)."
	loglines="The last 20 lines of $log were:\n\n$(tail -n 20 $log)"
else
	subject="$subject -- OK (complete: $complete)"
	failline="There were no failures."
fi

subject="$subject (run: $(date -u +%s))"

mail -a "From:root@mirror.d.umn.edu" -s "$subject" "$adminmail" <<OUTMAIL
Summary of Ubuntu Mirror Synchronization
PID: $pid
$failline
Last status (should be 0): $status
Finish Time: `date`

Disk space:
$DISKFULL

RAID1 Status:
$MDSTAT
$RAIDSTATUS

Sincerely,
$HOSTNAME

$loglines

OUTMAIL
fi

exit 0
