#!/bin/bash

if [ -z $DATABASES ] || [ -z $BUCKET ] ; then
	echo "WARNING: Environment variables not set, no backups will be performed."
else
	./restore.sh
fi

if [ -z $INTERVAL ] ; then
	INTERVAL=300
fi

echo "Starting backup scripts every $INTERVAL seconds"

while [ 1 -eq 1 ] ; do
	sleep $INTERVAL
	./backup.sh
done