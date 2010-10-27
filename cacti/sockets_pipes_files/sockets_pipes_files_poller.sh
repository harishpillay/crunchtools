#!/bin/bash
# Written By: Scott McCarty
# Created: 2/2008
# Description: Little bash script used to collect the follwing information on servers. This data is very useful in determining the health of a server.

output=`/usr/bin/snmpwalk -v1 -c $2 $1 .1.3.6.1.4.1.2021.54.101.1 | cut -d '"' -f 2`
echo $output
