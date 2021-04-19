#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
POD=$(kubectl get pod -n wordpress | grep wordpress-mysql | awk '{print $1}')
echo $POD
echo $TIMESTAMP

kubectl cp .my.cnf -n wordpress $POD:root/.my.cnf
kubectl cp wp-pod-dump.sql -n wordpress $POD:tmp/wp-pod-dump.sql

kubectl exec -it $POD -n wordpress -- bash -c ./tmp/wp-pod-dump.sql
kubectl cp -n wordpress $POD:tmp/wordpress.sql /mnt/ext/backups/wordpress-$TIMESTAMP.sql
kubectl exec -it $POD -n wordpress -- bash -c 'rm -f tmp/wordpress*' 

