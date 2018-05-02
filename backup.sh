#!/bin/bash

compare() {
	mongo --host mongo --eval "printjson(db.runCommand('dbHash').collections)" $1 --quiet > $1.md5
	mongo --host mongo --eval "printjson(db.runCommand('dbHash').collections)" $2 --quiet > $2.md5

	sdiff $1.md5 $2.md5
	RET=$?

	rm -f $1.md5 $2.md5

	return $RET
}

getdbs() {
	mongo --host mongo --eval "db.getMongo().getDBNames()" --quiet | tr ',' '\n' | grep -v admin | grep -v local
}

dbexists() {
	DD=`getdbs | grep $1`
	if [ -z $DD ] ; then
		return 1
	else
		return 0
	fi
}

backup () {
	DB=$1
	REMOTE_FILE=$2

	dbexists $DB
	if [ ! $? -eq 0 ] ; then
		echo "Database $DB does not exist, stopping."
		return
	fi

	echo "=============== Backing up database $DB..."
	aws s3 cp $REMOTE_FILE $DB.tgz
	if [ -f $DB.tgz ] ; then
		tar xvzf $DB.tgz
		mongorestore --host mongo -d backup-$DB $DB/$DB
		compare $DB backup-$DB

		if [ ! $? -eq 0 ] ; then
			echo "Database has changed, backing up..."
			rm -rf $DB.tgz $DB

			mongodump --host mongo -d $DB
			mv dump/* $DB/$DB 	#mongodump creates weird folder name - quick fix

			tar cvzf $DB.tgz $DB
			if [ $? -eq 0 ] ; then
				aws s3 cp $DB.tgz $REMOTE_FILE
			fi
		fi

		rm -rf $DB $DB.tgz
		mongo --host mongo --eval "db.dropDatabase()" backup-$DB --quiet
	else
		echo "Database $DB has never been backed up. Creating first time backup..."
		mongodump --host mongo -d $DB
		mv dump/* $DB/$DB 	#mongodump creates weird folder name - quick fix

		tar cvzf $DB.tgz $DB
		if [ $? -eq 0 ] ; then
			aws s3 cp $DB.tgz $REMOTE_FILE
		fi
	fi

	echo "=============== Done $DB..."
}

CMD="mongo --host mongo --eval 'db.serverStatus()' --quiet"
while $CMD ; ret=$? ; [ $ret -ne 0 ] ; do
	echo "Waiting for Mongo server before backing up"
	sleep 10
done

if [ ! -z $1 ] && [ ! -z $2 ]; then
	backup $1 $2
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

		let COUNT=`jq ".[] | length" $JSON`
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
		backup $NAME $FILE
	done
fi
