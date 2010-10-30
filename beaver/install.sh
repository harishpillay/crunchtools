#!/bin/bash

# Basic checks
if [ `whoami` != "root" ]
then
    echo "You need to be root to install to /usr/local/"
    exit 1
fi

if [ ! -d /usr/local/bin ] && [ ! -d /usr/local/etc ]
then
    echo "/usr/local/bin or /usr/local/etc does not exist!"
    exit 1
fi

# Optional Checks
keychain=`which keychain`

if [ -e "$keychain" ]
then
    echo "Good: Keychain is installed"
else
    echo "Bad: You will need to install keychain to do ssh key authentication automatically"
fi

# Install process
cp -v beaver_backup.sh /usr/local/bin/
cp -v beaver_backup.conf /usr/local/etc/
cp -v beaver_backup.excludes /usr/local/etc/
cp -v beaver_backup.includes /usr/local/etc/
cp -v beaver_backup.list /usr/local/etc/

if [ -e /usr/local/bin/beaver_backup.sh ] && \
   [ -e /usr/local/bin/beaver_backup.conf ] && \
   [ -e /usr/local/bin/beaver_backup.excludes ] && \
   [ -e /usr/local/bin/beaver_backup.includes ] && \
   [ -e /usr/local/bin/beaver_backup.list ]
then
    echo "Success"
    echo "Now add your servers to /usr/local/bin/beaver_backup.list and configure ssh key authentication"
fi
