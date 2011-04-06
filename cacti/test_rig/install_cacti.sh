#!/bin/bash
# Written By: Scott McCarty
# Date: 12/2010
# Email: scott.mccarty@gmail.com
# Description: very simple install/wipe for testing

init() {

	if [ "$1" == "cacti" ]
	then
		install $2
	elif [ "$1" == "mystats" ]
	then
		mysql_stats
	else
		echo "Usage: install_cacti.sh [cacti, mystats]"
	fi
}

install() {

	# Setup variables
	source install_cacti.config

	# Download
	if [ ! -e $cacti_version.tar.gz ]
	then
		wget http://www.cacti.net/downloads/$cacti_version.tar.gz
	fi

	# Wipe
	mv /usr/web/cacti-test /usr/web/cacti-test.`date +"%Y-%m-%d-%s"`

	# Install
	mkdir -p /usr/web/cacti-test/
	tar xvfz /root/software/cacti/$cacti_version.tar.gz --strip-components 1 -C /usr/web/cacti-test/

	# Configure
	cp -f config.php /usr/web/cacti-test/include/
	chown -R apache.apache /usr/web/cacti-test/

	# Database
	mysql_admin="mysql -u$mysql_admin_username -p$mysql_admin_password"

	$mysql_admin -e "drop database cacti_test;"
	$mysql_admin -e "create database cacti_test;"
	$mysql_admin -e "grant all on cacti_test.* TO '$mysql_cacti_username'@'localhost' identified by '$mysql_cacti_password';"
	$mysql_admin cacti_test < /usr/web/cacti-test/cacti.sql

	exit
}

import_template() {
	cd $cli
	php import_template.php --filename=$gms_home/$1
	cd -
}

mysql_stats() {

	# Set up variables
	source ./install_cacti.config
	gms_home="`pwd`/graph_mysql_stats"

	# Install server side script
	cp $gms_home/mysql_stats.php $cacti_home/scripts || "Check directory $cacti_home/scripts"

	# Create test host
	php $cli/add_device.php --description="$cts" --ip=$cts --community="$community" --template=0
	php $cli/add_tree.php --type=node --node-type=host --host-id=2

	# Import templates
	import_template cacti_graph_template_mysql_command_statistics.xml
	import_template cacti_graph_template_mysql_connections.xml 
	import_template cacti_graph_template_mysql_handler_statistics.xml 
	import_template cacti_graph_template_mysql_querycache_statistics.xml 
	import_template cacti_graph_template_mysql_questions.xml 
	import_template cacti_graph_template_mysql_single_statistics.xml 
	import_template cacti_graph_template_mysql_thread_statistics.xml 
	import_template cacti_graph_template_mysql_traffic.xml

	# Enumerate IDs of MySQL templates
	template_ids=`php $cli/add_graphs.php --list-graph-templates | grep MySQL | cut -f1`
	host_id=`php $cli/add_graphs.php --list-hosts | grep $cts | cut -f1`

	# Import the graph templates
	for id in $template_ids
	do
		php $cli/add_graphs.php --graph-template-id=$id --host-id=$host_id --graph-type=cg --input-fields="username=$mysql_mystats_username password=$mysql_mystats_password"
	done

	# Run the poller
	sudo -uapache /usr/bin/php /usr/web/cacti-test/poller.php -d --force
}

init $*
