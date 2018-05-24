#!/bin/bash

if [ -z $MONGO_HOST ] ; then
	export MONGO_HOST=mongo
	echo "Warning : Environment variable MONGO_HOST not set, using default ($MONGO_HOST)."
fi

if [ -z $MONGO_PORT ] ; then
	export MONGO_PORT=27017
	echo "Warning : Environment variable MONGO_PORT not set, using default ($MONGO_PORT)."
fi

if [ -z $DATABASES ] && [ -z $DATABASE_FILE ] ; then
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