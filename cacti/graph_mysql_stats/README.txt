README
======
description: enables cacti to read mysql statistics
files: mysql_stats.php and associated graph templates
version: 2.5.0
author: Otto Berger <berger{at}hk-net{dot}de> 2004 - 2011
support: Scott McCarty <scott{dot}mccarty{at}gmail{dot}com> 2011 - 2012
date: date: 2005/01/18 - 2012

contributors:
Kyle Milnes 2012/04 https://bit.ly/kyle0r
dainiookas 2012/03 https://bit.ly/HN2F6A

Full docs at http://crunchtools.com/software/crunchtools/cacti/graph-mysql-stats/

INSTALLATION
============
1. Put the mysql_stats.php file inside the cacti/scripts/ directory
2. Import the .xml files using the cacti web interface
   Cacti -> Console -> Import/Export -> Import Templates
3. Create graphs
   Cacti -> Console -> Create -> New Graphs

The script and templates have been tested up to cacti 0.8.7i


MYSQL SET UP
============
Configure your mysql-server(s) you want to graph. To enable access from the
cacti-machine to the mysql-status information, you must have the
"process" right.

For example, the following mysql-command to set the process-right for the
mysql-user "cacti-stats" with the password "cacti-passwd":

CREATE USER 'cacti_stats'@'your-host.local' IDENTIFIED BY 'cacti-passwd';
GRANT PROCESS ON *.* TO 'cacti_stats'@'your-host.local' IDENTIFIED BY 'cacti-passwd'
WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;

GRAPH CREATION
==============
1. Click inside cacti on "New Graphs"
2. Choose host and a MySQL - *something* template
3. Click create
4. Adjust the MySQL port, username and password as required for the given server
5. Finished!

Automation of adding the graphs is possible, via cli/add_graphs.php.
Further reading at http://crunchtools.com/software/crunchtools/cacti/graph-mysql-stats/

TROUBLESHOOTING
===============
Feel free to run the mysql_stats.php script from the command line with some relevant parameters,
to check connectivity etc.

$ php mysql_stats.php preset db_host[:db_port] db_user db_password [status_section]

presets are: q_cache, cache, command, handler, thread, traffic, status
if preset 'status' is supplied, the script expects status_section to be supplied.
status_section represents an associative array index, from the status results.
Further reading: http://dev.mysql.com/doc/refman/5.0/en/mysqld-option-tables.html

Check the cacti logs if your having problems, you can also run the php script from the command
line to test things manually. Don't forget you can adjust the logging verbosity in:
Cacti -> Console -> Configuration -> Settings -> General -> Poller Logging Level

UPGRADE
=======
see UPGRADE.txt

HISTORY
=======
see HISTORY.txt
