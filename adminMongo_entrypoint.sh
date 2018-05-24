#!/bin/bash

if [ -z $MONGO_HOST ] ; then
	export MONGO_HOST=mongo
	echo "Warning : Environment variable MONGO_HOST not set, using default ($MONGO_HOST)."
fi

if [ -z $MONGO_PORT ] ; then
	export MONGO_PORT=27017
	echo "Warning : Environment variable MONGO_PORT not set, using default ($MONGO_PORT)."
fi

sed -i -e "s/<MONGO_HOST>/$MONGO_HOST/" config/config.json
sed -i -e "s/<MONGO_PORT>/$MONGO_PORT/" config/config.json

if [ ! -z $PASSWORD ] ; then
	echo "{\"app\": {\"password\": \"$PASSWORD\"}}" > config/app.json
else
	echo "Warning : No password specified, the app doesn't require authentication !"
fi

node app.js