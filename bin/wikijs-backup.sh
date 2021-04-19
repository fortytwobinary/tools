#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
POD=$(kubectl get pod -n wikijs | grep wikijs-mariadb | awk '{print $1}')
echo $POD
echo $TIMESTAMP

kubectl cp .my.cnf -n wikijs $POD:root/.my.cnf
kubectl cp pod-dump.sql -n wikijs $POD:tmp/pod-dump.sql

kubectl exec -it $POD -n wikijs -- bash

