#!/bin/bash

# makes an rds database
# database is populated in admin server setup

# load master vars into variables.
. ../mycredentials/vars.sh


# terminate rds (with no final snapshot)
aws rds delete-db-instance --db-instance-identifier $v_dbinstancename --skip-final-snapshot

# wait for rds (or subsequent deletes will fail)
echo -n "waiting for database termination"
while v_state=$(aws rds describe-db-instances --output text --query 'DBInstances[*].DBInstanceStatus'); [[ $v_state == deleting ]]; do
 echo -n . ; sleep 5;
done; echo "v_state=$v_state"

# delete rds parameter group
aws rds delete-db-parameter-group --db-parameter-group-name $v_dbpgname

# delete rds subnet group
aws rds delete-db-subnet-group --db-subnet-group-name $v_dbsubnetgroupname

v_dbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=dbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_dbsg_id=$v_dbsg_id

aws ec2 delete-security-group --group-id $v_dbsg_id

echo end of delete_rds.sh
