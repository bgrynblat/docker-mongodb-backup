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

	dbexists $DB
	if [ ! $? -eq 0 ] ; then
		echo "Database $DB does not exist, stopping."
		return
	fi

	echo "=============== Backing up database $DB..."
	aws s3 cp s3://$BUCKET/$DB.tgz $DB.tgz
	if [ -f $DB.tgz ] ; then
		tar xvzf $DB.tgz
		/usr/bin/mongorestore --host mongo -d backup-$DB $DB/$DB
		compare $DB backup-$DB

		if [ ! $? -eq 0 ] ; then
			echo "Database has changed, backing up..."
			rm -rf $DB.tgz $DB

			/usr/bin/mongodump --host mongo -d $DB
			mv dump/* $DB/$DB 	#mongodump creates weird folder name - quick fix

			tar cvzf $DB.tgz $DB
			if [ $? -eq 0 ] ; then
				aws s3 cp $DB.tgz s3://$BUCKET/
			fi
		fi

		rm -rf $DB $DB.tgz
		mongo --host mongo --eval "db.dropDatabase()" backup-$DB --quiet
	else
		echo "Database $DB has never been backed up. Creating first time backup..."
		/usr/bin/mongodump --host mongo -d $DB
		mv dump/* $DB/$DB 	#mongodump creates weird folder name - quick fix

		tar cvzf $DB.tgz $DB
		if [ $? -eq 0 ] ; then
			aws s3 cp $DB.tgz s3://$BUCKET/
		fi
	fi

	echo "=============== Done $DB..."
}

CMD="mongo --host mongo --eval 'db.serverStatus()' --quiet"
while $CMD ; ret=$? ; [ $ret -ne 0 ] ; do
	echo "Waiting for Mongo server before backing up"
	sleep 10
done

if [ ! -z $1 ] ; then
	backup $1
else
	DBS=${DATABASES//','/' '}
	DBS=${DBS//';'/' '}

	for DB in $DBS; do
		backup $DB
	done
fi
