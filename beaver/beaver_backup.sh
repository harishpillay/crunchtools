#!/bin/bash
#
# Writen By: Scott McCarty
# Date: 2/19/2007
# Email: scott.mccarty@gmail.com
# Version: .5
# Description: Simple Bash/Rsync backup utility needed to backup all servers
# accessable from the network. You can rely on DNS for name resolution or 
# use ip addresses instead. 
#
# Copyright (C) 2009 Scott McCarty
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc.
# 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
###############################################################################

debug() {
	if [ $debug -eq 1 ]
	then
		echo "Debug: $1";
	fi
}

usage() {
	echo ""
	echo "USAGE:"
	echo "    $0 [options]"
	echo "where options is any of:"
	echo "    f <file> - get Rsync clients from <file>"
	echo "    F <file> - get Databse clients from <file>"
	echo "    v - Verbose"
	echo "    h - Help"
	echo ""
	exit 1;
}

get_config() {
    if [ -e "/usr/local/etc/$1" ]
    then
         echo "/usr/local/etc/$1"
    elif [ -e ./$1 ]
    then
         echo "$1"
    else
        echo "Could not find: $1" >&2
        exit 1
    fi
}

init() {


	# Set Defaults
	rsync_clients_file=`get_config beaver_backup.list`
	debug=0

	# main
	while getopts "f:vh" options; do
		case $options in
		f ) rsync_clients_file="$OPTARG";;
		v ) debug=1;;
		h ) usage;;
		\? ) usage;;
		* ) usage;;
		esac
	done

	# Initializations

	## Use keyhain if available
    if [ -e /root/.keychain/$HOSTNAME-sh ]
    then
    	source /root/.keychain/$HOSTNAME-sh
        keychain_support="true"
    else
        keychain_support="false"
    fi

    ## Option: Use scriptlog if available
    if which scriptlog &>/dev/null
    then
        scriptlog=`which scriptlog`
        scriptlog_i="$scriptlog -i 24"
        scriptlog_s="$scriptlog -s "
    else
        # Define simple takeover function
        scriptlog=""
        scriptlog_i="eval"
        scriptlog_s="echo"
    fi

	# Log start time
	$scriptlog_s "Starting Backup"
	start_time=`date`

	# Variables
	job_id=`/bin/date | /usr/bin/md5sum | /bin/cut -f1  -d" "`
	rsync_clients=`cat $rsync_clients_file|grep -v ^#`
	rsync_fail_list=""
	rsync_success_list=""
	rsync_client_number=0

    ## Exclude list logic
    exclude_list_file=`get_config beaver_backup.excludes`
    exclude_list=`for i in \`cat $exclude_list_file\`; do echo -n " --exclude=$i"; done`

    # Tunables
    config_file=`get_config beaver_backup.conf`
    source $config_file

	# Debug Output	
	debug "Beaver Backup List: $rsync_clients_file";
    debug "Beaver Backup Config: $config_file"
    debug "Email: $email_address"
    debug "Keychain Support: $keychain_support"
	debug "Job ID: $job_id"
	debug "Slots: $max_slots"


	# Setup logging
	exec 3>/tmp/$0.tmp
}

find_open_slot() {

	# This monstrousity finds the correct number of running rsyncs
	used_slots=`/bin/ps -ef | /bin/grep $job_id | /bin/grep -v grep | awk '{ print $9" "$NF}' | grep $job_id | sort -u | /usr/bin/wc -l `

	# Debug Output
	debug "Slots are filled with: "
	if [ $debug -eq 1 ]
	then
		/bin/ps -ef | /bin/grep $job_id | /bin/grep -v grep | awk '{ print $9" "$NF}' | grep $job_id | sort -u
	fi

	if  [ "$used_slots" -lt "$max_slots" ]
	then
		debug "Found open slot"
		return 0
	else
		debug "Did not find open slot"
		return 1
	fi
}

async_backup() {
###############################################################################
# Keep track of start/stop times
###############################################################################

	debug  "Backing up client: $rsync_client"
	$scriptlog_s "Begin rsync client: $rsync_client"

	# Check to see if destination directory exists
	if [ ! -e $backup_destination/$rsync_client ]
	then
		mkdir -p $backup_destination/$rsync_client
	fi

    # Perform Backup
	debug "Running: /usr/bin/rsync --exclude=$job_id $rsync_options $exclude_list root@$rsync_client:/ /srv/backup/$rsync_client/"
	$scriptlog_i"/usr/bin/rsync --exclude=$job_id $rsync_options $exclude_list root@$rsync_client:/ /srv/backup/$rsync_client/"

	# Log time finished
	$scriptlog_s "Finished rsync client: $rsync_client"
}

run_job() {
###############################################################################
# Use the magic of recursion to try and find an open slot
# May have to fine tune sleep time for bash
###############################################################################

		if find_open_slot
		then
			# If there is an open slot, fire off another job
			async_backup &
			sleep 3
		else
			sleep 300
			run_job
		fi
}

wait_jobs() {
###############################################################################
# Use a little magical recurstion to wait for all jobs to finish
###############################################################################

	# This monstrousity finds the correct number of running rsyncs
	used_slots=`/bin/ps -ef | /bin/grep $job_id | /bin/grep -v grep | awk '{ print $9" "$NF}' | grep $job_id | sort -u | /usr/bin/wc -l `

	if  [ "$used_slots" -eq "0" ]
	then
		debug "All jobs have completed"
		return 0
	else
		debug "Waiting for running jobs"
		sleep 300
		wait_jobs
	fi
}

rsync_backup () {

	# Main loop
	for rsync_client in $rsync_clients
	do

		run_job

		# Check/Calculat results of rsync
		#let "rsync_client_result = $rsync_client_result + $RETVAL"
		let "rsync_client_number = $rsync_client_number + 1" 
	done

	# After all jobs have begaon, wait for final job to finish
	wait_jobs

	# Calculate final end time
	end_time=`date`

}

report () {

	# Build lists
	for rsync_client in $rsync_clients
	do
		if [ `(/bin/zcat /var/log/script.log.1.gz;/bin/cat /var/log/script.log) | \
            /bin/grep $0 | \
            /bin/grep rsync | \
            /bin/grep " root@${rsync_client}:/ " | \
            /usr/bin/tail -n1 | \
            /bin/awk '{print $7}'` = "SUCCESS" ]
		then
			debug "Adding $rsync_client to success list"
			rsync_success_list="$rsync_success_list $rsync_client"
		else
			debug "Adding $rsync_client to fail list"
			rsync_fail_list="$rsync_fail_list $rsync_client"
		fi
	done


	# Reporting
	echo "Rsync backup from $HOSTNAME: Completed, $rsync_client_number client(s)" >&3
	echo "" >&3
	echo "Start time: $start_time" >&3
	echo "End time:   $end_time" >&3
	echo "" >&3

	if [ "$rsync_fail_list" = "" ]
	then
		echo "--- Successful Save Sets ---" >&3

		for i in $rsync_success_list
		do
			echo $i >&3
		done
	else
		echo "--- Unsuccessful Save Sets ---" >&3
	
		for i in $rsync_fail_list
		do
			echo $i >&3
		done

		echo "" >&3

    		echo "--- Successful Save Sets ---" >&3
    		for i in $rsync_success_list
    		do
			echo $i >&3
		done
	fi

	# Send report
	cat /tmp/$0.tmp|mail -s "Beaver Backup Complete" $email_address

} # end report


# main
init $*
exit
rsync_backup
report
