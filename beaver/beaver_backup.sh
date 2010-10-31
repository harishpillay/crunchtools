#!/bin/bash
#
# Writen By: Scott McCarty
# Date: 2/19/2007
# Email: scott.mccarty@gmail.com
# Version: .9
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
    echo "Where options is any of:"
    echo "    c <file> - Get config from <file>"
    echo "    f <file> - Get clients list from <file>"
    echo "    e <file> - Get excludes list from <file>"
    echo "    i <file> - Get excludes list config from <file>"
    echo "    s <directory> - Only backup certain directory"
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
    remote_clients_file=`get_config beaver_backup.list`
    config_file=`get_config beaver_backup.conf`
    exclude_list_file=`get_config beaver_backup.excludes`
    include_list_file=`get_config beaver_backup.includes`
    source_directory=""
    debug=0
    test_mode=0

    # Get options
    while getopts "f:c:e:i:s:tvh" options; do
        case $options in
            f ) remote_clients_file="$OPTARG";;
            c ) config_file="$OPTARG";;
            e ) exclude_list_file="$OPTARG";;
            i ) include_list_file="$OPTARG";;
            s ) source_directory="$OPTARG";;
            t ) test_mode=1;;
            v ) debug=1;;
            h ) usage;;
            \? ) usage;;
            * ) usage;;
        esac
    done

    # Initializations

    ## Commands
    awk=`which awk`
    grep=`which grep`
    tail=`which tail`
    ps=`which ps`
    sort=`which sort`
    wc=`which wc`
    echo=`which echo`
    cat=`which cat`
    mail=`which mail`
    sshd=`which sshd`
    rsync=`which rsync`
    rm=`which rm`
    mv=`which mv`
    sed=`which sed`
    scriptlog=`which echo`

    ## Turn on/off options
    option_keychain
    option_scriptlog
    option_snapshot
    
    ## Log start time
    $scriptlog "Starting Backup"
    start_time=`date`

    # Tunables
    ssh_options=""
    max_snapshots=3
    source $config_file

    ## Variables
    remote_clients=`cat $remote_clients_file|grep -v ^#`
    rsync_options="-aq --timeout=${rsync_timeout} --delete-excluded"
    rsync_fail_list=""
    rsync_success_list=""
    remote_client_number=0
    script_name=`basename $0`
    short_wait=3
    long_wait=300

    ## Exclude/include list logic
    exclude_list=`for i in \`cat $exclude_list_file\`; do $echo -n " --exclude=\"$i\""; done`
    include_list=`for i in \`cat $include_list_file\`; do $echo -n " --include=\"$i\""; done`

    display_debug

    # Setup logging
    exec 3>/tmp/${script_name}.tmp
}


display_debug() {

    # Debug Output	
    debug "Beaver Backup List: $remote_clients_file";
    debug "Beaver Backup Config: $config_file"
    debug "Email: $email_address"
    debug "Keychain Support: $keychain_support"
    debug "Slots: $max_slots"
    debug "Source Directory: $source_directory"
    debug "Destination Directory: $destination_directory"
}

option_keychain() {

    ## Use keyhain if available
    if [ -e /root/.keychain/$HOSTNAME-sh ]
    then
    	source /root/.keychain/$HOSTNAME-sh
        keychain_support="true"
    else
        keychain_support="false"
    fi
}

option_scriptlog() {

    ## Option: Use scriptlog if available
    if which scriptlog &>/dev/null
    then
        export scriptlog=`which scriptlog`
        export rsync="$scriptlog -i 24 `which rsync`"
        export scriptlog="$scriptlog -s "
    fi
}

option_snapshot() {

    ## find out if rsync supports snapshots
    if rsync -h | grep link-dest &>/dev/null
    then
        snapshot_support="true"
    else
        snapshot_support="false"
    fi
}

safe_run() {

    # Run from the tmp command file, because there is problems on different
    # shell/versions/operating systems and quoting.
    $echo $1 > /tmp/${script_name}.safe_command
    sh /tmp/${script_name}.safe_command
}

used_slots() {
    ls /tmp/$script_name.*.running 2>/dev/null | wc -l || $echo 0
}

test_mode() {

    # Override variables
    source_directory="/etc"
    remote_clients="server1.example.com server2.example.com server3.example.com"
    destination_directory="/tmp"
    debug=1
    short_wait=1
    long_wait=1
    rsync_options="-aq --timeout=${rsync_timeout} --delete-excluded"
    ssh_options="-o StrictHostKeyChecking=no"

    # Test Dependancies
    if [ ! -e "$rsync" ]; then $echo "Rsync not installed"; exit 1; fi
    if [ ! -e "$sshd" ]; then $echo "SSH daemon not installed"; exit 1; fi
    if ! ps -eF | grep -v "grep sshd" | grep sshd &>/dev/null; then $echo "SSH Daemon is not running, Run: service sshd start"; exit 1; fi
    if [ ! -e "$rsync" ]; then $echo "Keychain not found, you will be prompted for password"; fi
    

    display_debug

    # Add hosts entries
    $echo "127.0.0.1 ${remote_clients}" >> /etc/hosts

    # Run main
    main
    report

    # Show output email
    $echo "Email Output: Hit Enter to Continue"
    $cat /tmp/$script_name.tmp
    read junk

    # Remove hosts entries
    $sed -i -e "/127.0.0.1 ${remote_clients}/d" /etc/hosts

    # removed backup files
    for remote_client in $remote_clients
    do
        $rm -rf $destination_directory/$remote_client
	$sed -i -e "/$remote_client/d" /root/.ssh/known_hosts
    done
}

find_open_slot() {

    if  [ `used_slots` -lt "$max_slots" ]
    then
        debug "Found open slot"
        return 0
    else
        debug "Did not find open slot"
        return 1
    fi
}

rotate_snapshots() {
    
    ultimate=$max_snapshots
    
    $rm -rf "${destination_directory}/${remote_client}/current${ultimate}"
    
    while [ $ultimate -ne 1 ]
    do    
        let "penultimate = $ultimate - 1"

        $mv -f "${destination_directory}/${remote_client}/current${penultimate}/" \
            "${destination_directory}/${remote_client}/current${ultimate}/"
        
        let "ultimate = $penultimate"
        
    done
    
    $mv -f "${destination_directory}/${remote_client}/new/" \
        "${destination_directory}/${remote_client}/current1/"

}

async_backup() {
###############################################################################
# Keep track of start/stop times
###############################################################################

    $scriptlog "Backing up client: $remote_client"

    touch /tmp/${script_name}.$remote_client.running

    # Check to see if destination directory exists
    if [ ! -e $destination_directory/$remote_client ]
    then
        mkdir -p $destination_directory/$remote_client
    fi

    # Perform Backup
    export RSYNC_RSH="ssh $ssh_options -o ConnectTimeout=${ssh_timeout} -o ConnectionAttempts=3"

    if [ "$snapshot_support" == "true" ]
    then
        command="$rsync $rsync_options $exclude_list $include_list \
            --link-dest=${destination_directory}/${remote_client}/current1/
            root@${remote_client}:${source_directory}/ \
            ${destination_directory}/${remote_client}/new/"
    else
        command="$rsync $rsync_options $exclude_list $include_list \        
            root@${remote_client}:${source_directory}/ \
            ${destination_directory}/${remote_client}/new/"
    fi


    debug "Running: $command"

    # Keep track of running processes using tmp files
    if safe_run "$command"
    then
        mv /tmp/${script_name}.${remote_client}.running /tmp/${script_name}.${remote_client}.success
    else
        mv /tmp/${script_name}.${remote_client}.running /tmp/${script_name}.${remote_client}.failed
    fi

    # Rotate directories    
    if [ "$snapshot_support" == "true" ]
    then
        rotate_snapshots
    fi

    # Log time finished
    $scriptlog "Finished rsync client: $remote_client"
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
        sleep $short_wait
    else
        sleep $long_wait
        run_job
    fi
}

wait_jobs() {
###############################################################################
# Use a little magical recurstion to wait for all jobs to finish
###############################################################################

    if  [ `used_slots` -eq "0" ]
    then
        debug "All jobs have completed"
        return 0
    else
        debug "Waiting for running jobs"
        sleep $long_wait
        wait_jobs
    fi
}

main() {

    # Main loop
    for remote_client in $remote_clients
    do
        run_job

        # Check/Calculat results of rsync
        let "remote_client_number = $remote_client_number + 1" 
    done

    # After all jobs have begaon, wait for final job to finish
    wait_jobs

    # Calculate final end time
    end_time=`date`

}

report () {

    # Build lists
    for remote_client in $remote_clients
    do
        sleep $short_wait
        if [ -e /tmp/${script_name}.${remote_client}.success ]
        then
            debug "Adding $remote_client to success list"
            rsync_success_list="$rsync_success_list $remote_client"
            rm -f /tmp/${script_name}.$remote_client.success
        else
            debug "Adding $remote_client to fail list"
            rsync_fail_list="$rsync_fail_list $remote_client"
            rm -f /tmp/${script_name}.$remote_client.failed
        fi
    done

    # Reporting
    $echo "Rsync backup from $HOSTNAME: Completed, $remote_client_number client(s)" >&3
    $echo "" >&3
    $echo "Start time: $start_time" >&3
    $echo "End time:   $end_time" >&3
    $echo "" >&3

    if [ "$rsync_fail_list" = "" ]
    then
        $echo "--- Successful Save Sets ---" >&3

        for i in $rsync_success_list
        do
            $echo $i >&3
        done
    else
        $echo "--- Unsuccessful Save Sets ---" >&3
	
        for i in $rsync_fail_list
        do
            $echo $i >&3
        done

        $echo "" >&3

        $echo "--- Successful Save Sets ---" >&3
        for i in $rsync_success_list
        do
            $echo $i >&3
        done
    fi

    # Send report
    $cat /tmp/${script_name}.tmp|$mail -s "Beaver Backup Complete" $email_address

    # Safety Net Cleanup
    rm -f /tmp/${script_name}.*.success
    rm -f /tmp/${script_name}.*.failed
    rm -f /tmp/${script_name}.*.running
}


# main
init $*
if [ $test_mode -eq 1 ]
then
    test_mode
else
    main
    report
fi
