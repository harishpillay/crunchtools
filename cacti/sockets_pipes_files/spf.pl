# Written By: Scott McCarty
# Created: 05/2012
# Description: Perl based AgentX server to send data back to the 
# cacti server and nagios server. Originally this was just a bash
# script which was called from a sh/exec directive in the snmpd.conf
# but that feature has been deprecated because of a lack of adherence 
# snmp standards. Oh well, perl/C let's one work around it with a
# module :-)
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

use NetSNMP::agent (':all');
use NetSNMP::ASN (':all');
use NetSNMP::OID (':all');

my $spf_oid = ".1.3.6.1.4.1.2021.54";
my $value;
my $tmp = '/var/lib/net-snmp';	# Also, hard coded in refresh_data() because
				# because perl can't interpret variables when
				# using back ticks to run commands
				# /var/lib/net-snmp was used because CentOS
				# has some selinux problem that prevents the 
				# use of /tmp

sub poll {

	# Hack to handle the lack of background subroutines in perl
	# There are CPAN modules, but I didn't want users to have
	# to install such things for such a small program :-)
	 
	system("lsof -Ft 2>&1 | grep FIFO | wc -l > /$tmp/spf_pipes &");
	system("netstat -anp | grep tcp | wc -l > /$tmp/spf_tcp &");
	system("netstat -anp | grep udp | wc -l > /$tmp/spf_udp &");
	system("netstat -anp | grep unix | wc -l > /$tmp/spf_unix &");
}

sub refresh_data {
	
	# System commands might be optimized, but it works for now
	# see also poll()

	chomp(my $files = `cat /proc/sys/fs/file-nr | cut -f1`);
	chomp(my $pipes = `cat /var/lib/net-snmp/spf_pipes`);
	chomp(my $tcp = `cat /var/lib/net-snmp/spf_tcp`);
	chomp(my $udp = `cat /var/lib/net-snmp/spf_udp`);
	chomp(my $unix = `cat /var/lib/net-snmp/spf_unix`);
	$value = "files:$files pipes:$pipes tcp:$tcp udp:$udp unix:$unix";
	poll();
}

sub myhandler {

	# Standard call back function to handle incoming SNMP requests
	# this was used to replace the old sh/exec command that was
	# removed from snmpd.conf
	
	my ($handler, $registration_info, $request_info, $requests) = @_;
	my $request;

	for($request = $requests; $request; $request = $request->next()) {
		my $oid = $request->getOID();
		refresh_data();

		if ($request_info->getMode() == MODE_GET) {
			if ($oid == new NetSNMP::OID("$spf_oid.101.1")) {
				$request->setValue(ASN_OCTET_STR, $value);
			}

		}

		elsif ($request_info->getMode() == MODE_GETNEXT) {
			if ($oid < new NetSNMP::OID("$spf_oid.101.1")) {
				$request->setOID("$spf_oid.101.1");
				$request->setValue(ASN_OCTET_STR, $value);
			}

		}
	}
}

$agent->register("spf", "$spf_oid", \&myhandler);
poll();
