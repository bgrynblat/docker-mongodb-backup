#!/bin/bash

uploadMd5() {
	DB=$1
	REMOTE_FILE_MD5="$2".md5
	mongo --host mongo --eval "printjson(db.runCommand('dbHash').collections)" $1 --quiet > $DB.md5

	aws s3 cp $DB.md5 $REMOTE_FILE_MD5

	rm -f $DB.md5
}

compare() {
	DB=$1
	REMOTE_FILE_MD5="$2".md5

	mongo --host mongo --eval "printjson(db.runCommand('dbHash').collections)" $1 --quiet > $1.md5
	aws s3 cp $REMOTE_FILE_MD5 - | cat > $1.remote.md5

	sdiff $1.md5 $1.remote.md5
	RET=$?

	rm -f $1.md5 $1.remote.md5

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

	echo "=============== Comparing $1 with remote backup..."
	compare $DB $REMOTE_FILE
	if [ ! $? -eq 0 ] ; then
		echo "Database has changed, backing up..."

		mongodump --host mongo -d $DB --out $DB

		tar cvzf $DB.tgz $DB
		if [ $? -eq 0 ] ; then
			aws s3 cp $DB.tgz $REMOTE_FILE
			uploadMd5 $DB $REMOTE_FILE
		fi
		rm -rf $DB $DB.tgz
	else
		echo "Database has not changed, skipping..."
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
