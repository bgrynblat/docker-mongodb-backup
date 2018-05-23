#!/bin/bash

restore() {
	DB=$1
	REMOTE_FILE=$2
	echo "=============== Restoring database $DB..."
	aws s3 cp $REMOTE_FILE $DB.tgz
	if [ ! -f $DB.tgz ] ; then
		echo "Unable to restore $DB, skipping."
		return 1
	fi
	tar xvzf $DB.tgz
	mongorestore --host mongo --drop $DB
	rm -rf $DB.tgz $DB
	echo "=============== Done $DB..."
}

echo "Starting restore script..."
CMD="mongo --host mongo --eval 'db.serverStatus()' --quiet"
while $CMD ; ret=$? ; [ $ret -ne 0 ] ; do
	echo "Waiting for Mongo server before restore"
	sleep 5
done

if [ ! -z $1 ] && [ ! -z $2 ] ; then
	restore $1 $2
else

	if [ -z "$DATABASES" ] && [ -z $DATABASE_FILE ] ; then
		echo "Error: no variable DATABASE or DATABASE_FILE defined. Exiting."
		exit 1
	fi

	if [ ! -z "$DATABASE_FILE" ] ; then
		JSON=dbs.json
		aws s3 cp $DATABASE_FILE $JSON
		if [ ! -f $JSON ] ; then
			echo "Error: Cannot fetch databases file, stopping."
			exit 1
		fi

		let COUNT=`jq ". | length" $JSON`
		let MAX=$COUNT-1

		for i in `seq 0 $MAX`; do
			NAME=`jq -r ".[$i].name" $JSON`
			FILE=`jq -r ".[$i].file" $JSON`

			DBS="$NAME@$FILE $DBS"
		done
		rm -f $JSON
	else
		DBS=${DATABASES//','/' '}
		DBS=${DBS//';'/' '}
	fi

	for DB in $DBS; do
		NAME=`echo $DB | cut -d@ -f1`
		FILE=`echo $DB | cut -d@ -f2`
		restore $NAME $FILE
	done
fi

