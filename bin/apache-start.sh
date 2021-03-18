#!/bin/bash
# apache-start.sh
#
# Written by David L. Whitehurst
# on Mar 13, 2021
#
# This script will remove an apache2 docker container
# and then create/run a new apache2 container from the
# resident image
#
# NOTE: Although this script can be used where an existing
# apache docker image exists, it's currently used only
# by our web host 192.168.1.21
#

export APACHE_CONTAINER=$(docker ps -a | grep apache2 | awk '{print $1}')
docker rm $APACHE_CONTAINER
docker run -dit --name apache2 -p 8081:80 -v /home/pi/www:/usr/local/apache2/htdocs/ httpd:2.4 &
