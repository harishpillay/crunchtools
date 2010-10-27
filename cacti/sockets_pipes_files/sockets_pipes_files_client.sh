#!/bin/bash
# Written By: Scott McCarty
# Created: 2/2008
# Description: Bash scripted used on the snmp/clinet to send data back to the cacti server and nagios server.

if [ $1  ]
then
  sleep 5
  files=`cat /proc/sys/fs/file-nr|cut -f1`
  pipes=`lsof -Ft 2>&1 | grep FIFO | wc -l`
  tcp=`netstat -anp | grep tcp | wc -l`
  udp=`netstat -anp | grep udp | wc -l`
  unix=`netstat -anp | grep unix | wc -l`
  echo -n "files:$files pipes:$pipes tcp:$tcp udp:$udp unix:$unix" > /tmp/sockets_pipes_files.tmp
  exit
else
  output=`tail -n 1 /tmp/sockets_pipes_files.tmp`
  echo -n $output
  $0 1&
  exit
fi
