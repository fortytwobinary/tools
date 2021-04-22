#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
POD=$(kubectl get pod -n wordpress | grep wordpress-mysql | awk '{print $1}')

echo $TIMESTAMP
echo $POD

kubectl cp /home/ubuntu/tools/bin/.my.cnf -n wordpress $POD:root/.my.cnf
kubectl cp /home/ubuntu/tools/bin/wp-pod-dump.sql -n wordpress $POD:tmp/wp-pod-dump.sql

kubectl exec -i $POD -n wordpress -- bash -c ./tmp/wp-pod-dump.sql
kubectl cp -n wordpress $POD:tmp/wordpress.sql /mnt/ext/backups/wordpress-$TIMESTAMP.sql
kubectl exec -i $POD -n wordpress -- bash -c 'rm -f tmp/wordpress*' 

