#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
POD=$(kubectl get pod -n wikijs | grep wikijs-mariadb | awk '{print $1}')
echo $POD
echo $TIMESTAMP

