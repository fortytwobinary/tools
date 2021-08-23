#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
POD=$(kubectl get pod -n wikijs | grep wikijs-mariadb | awk '{print $1}')

echo $TIMESTAMP
echo $POD

kubectl cp /home/david/tools/bin/.my.cnf -n wikijs $POD:root/.my.cnf
kubectl cp /home/david/tools/bin/pod-dump.sql -n wikijs $POD:tmp/pod-dump.sql

kubectl exec -i $POD -n wikijs -- bash -c 'tmp/pod-dump.sql'
kubectl cp -n wikijs $POD:tmp/wikijs.sql /backups/wikijs-$TIMESTAMP.sql
kubectl exec -i $POD -n wikijs -- bash -c 'rm -f tmp/wikijs*' 

