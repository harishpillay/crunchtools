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

# Cacti CLI functions
add_device() {
	php $cli/add_device.php --description="$1" --ip="$1" --community="$community" --template=0
}

add_tree() {
	php $cli/add_tree.php --type=node --node-type=host --host-id="$1"
}

add_graph() {
		php $cli/add_graphs.php \
			--graph-template-id=$1 \
			--host-id=$2 \
			--graph-type=cg \
			--input-fields="username=$mysql_mystats_username password=$mysql_mystats_password"
}

import_template() {
	cd $cli
	php import_template.php --filename=$src/$1
	cd -
}

get_template_ids() {
	php $cli/add_graphs.php --list-graph-templates | grep "$1" | cut -f1
}

get_host_id() {
	php $cli/add_graphs.php --list-hosts | grep $1 | cut -f1
}

poll_cacti() {
	sudo -uapache php $cacti_home/poller.php -d --force
}

# Plugin installs
mysql_stats() {

	# Set up variables
	source ./install_cacti.config

	# Get relative full path
	src="`dirname $PWD`/graph_mysql_stats"

	# Install server side script
	cp $src/mysql_stats.php $cacti_home/scripts || "Check directory $cacti_home/scripts"

	# Create test host
	add_device $cacti_test_server
	add_tree 2

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
	template_ids=`get_template_ids MySQL`
	host_id=`get_host_id $cacti_test_server`

	# Import the graph templates
	for template_id in $template_ids
	do
		add_graph $template_id $host_id
	done

	# Run the poller
	poll_cacti
}

init $*
