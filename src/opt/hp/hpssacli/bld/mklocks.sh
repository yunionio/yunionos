#!/bin/sh

APP_SOCKET_DIR=/var/run

if [ "$1" = "hpssa" -o "$1" = "hpadu" ]
then
	mkdir -p ${APP_SOCKET_DIR} 2>/dev/null
fi

exit 0
