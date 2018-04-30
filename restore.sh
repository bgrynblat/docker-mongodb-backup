#!/bin/bash

restore() {
	DB=$1
	echo "=============== Restoring database $DB..."
	aws s3 cp s3://$BUCKET/$DB.tgz $DB.tgz
	if [ ! -f $DB.tgz ] ; then
		echo "Unable to restore $DB, skipping."
		return 1
	fi
	tar xvzf $DB.tgz
	mongorestore --host mongo $DB
	rm -rf $DB.tgz $DB
	echo "=============== Done $DB..."
}

echo "Starting restore script..."
CMD="mongo --host mongo --eval 'db.serverStatus()' --quiet"
while $CMD ; ret=$? ; [ $ret -ne 0 ] ; do
	echo "Waiting for Mongo server before restore"
	sleep 5
done

if [ ! -z $1 ] ; then
	restore $1
else
	DBS=${DATABASES//','/' '}
	DBS=${DBS//';'/' '}

	for DB in $DBS; do
		restore $DB
	done
fi

