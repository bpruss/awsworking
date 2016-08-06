#!/bin/bash

# waits for completion of rds database

# load master vars into variables.
source ../mycredentials/vars.sh
set_vars_p
display_vars_p ALL

# wait for the db state to be available
echo -n "waiting for db"
while v_state=$(aws rds describe-db-instances --db-instance-identifier $v_dbinstancename --output text --query 'DBInstances[*].DBInstanceStatus'); test "$v_state" != "available"; do
 echo -n . ; sleep 3;
done; echo "v_state=$v_state"

# this is the address, or endpoint, for the db
v_dbendpoint=$(aws rds describe-db-instances --db-instance-identifier $v_dbinstancename --output text --query 'DBInstances[*].Endpoint.Address')
echo v_dbendpoint=$v_dbendpoint

echo "database ALIVE"
