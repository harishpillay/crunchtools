#!/bin/bash
# Written By: Scott McCarty
# Created: 2/2008
# Description: Little bash script used to collect the follwing information on servers. 
# This data is very useful in determining the health of a server.
#
#
# Copyright (C) 2012 Scott McCarty
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

output=`/usr/bin/snmpwalk -v1 -c $2 $1 .1.3.6.1.4.1.2021.54.101.1 | cut -d '"' -f 2`
echo $output
