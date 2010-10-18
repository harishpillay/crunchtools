#!/bin/bash

# Variables
remote_destination="/var/www/html/crunchtools.com/wp-content/files/crunchtools"

copy_latest() {

    echo "Copying $1.${version}.tgz to server"
    scp $1.${version}.tgz scott@crunchtools.com:$remote_destination/$1
    if [ `ssh scott@crunchtools.com "ls -tr $remote_destination/$1 | tail -n 1"` == beaver.${version}.tgz ]
    then
        echo "Success"
    fi
}

link_latest() {

    latest_version=`ssh scott@crunchtools.com "ls $remote_destination/$1/* | grep -v current | tail -n 1"`
    echo "Latest Version: $latest_version"
    ssh scott@crunchtools.com ln -fs $latest_version $remote_destination/$1/$1-current.$2
    latest_link=`ssh scott@crunchtools.com "ls -ltrh $remote_destination/$1 | tail -n 1"`
    echo "Latest Link: $latest_link"
}

if [ "$1" == "beaver" ]
then
    hg update beaver
    version=`cat beaver/version`
    tar cvvzf beaver.${version}.tgz beaver/
    copy_latest beaver
    link_latest beaver tgz
else
    echo "No package specified"
fi

