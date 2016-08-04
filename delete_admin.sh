#!/bin/bash

. ../mycredentials/vars.sh

v_myip=$(curl http://checkip.amazonaws.com/)
echo v_myip=$v_myip

# terminate instances - BFP note this terminates all instances.  We want to be more specific soon.
v_instances=$(aws ec2 describe-instances --output text --query 'Reservations[*].Instances[*].InstanceId')
echo v_instances=$v_instances
aws ec2 terminate-instances --instance-ids $v_instances


echo removing admin key pair
aws ec2 delete-key-pair --key-name admin
rm ../mycredentials/admin.pem
echo done removing key pair

echo getting admin security group id
v_adminsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=adminsg --output text --query 'SecurityGroups[*].GroupId')
echo v_adminsg_id=$v_adminsg_id

echo getting db security group id
v_dbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=dbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_dbsg_id=$v_dbsg_id

# wait for instances (or subsequent deletes will fail)
echo -n "waiting for instances termination"
while v_state=$(aws ec2 describe-instances --output text --query 'Reservations[*].Instances[*].State.Name'); [[ $v_state == *shutting* ]]; do
 echo -n . ; sleep 5;
done; echo "v_state=$v_state"

# remove all rules from dbsg
echo remove links between db and admin security groups
aws ec2 revoke-security-group-ingress --group-id $v_dbsg_id --protocol tcp --port 3306 --source-group $v_adminsg_id

#echo revoke ingress
#aws ec2 revoke-security-group-ingress --group-id $v_adminsg_id --protocol tcp --port 38142 --cidr $v_myip/32

echo delete security group
aws ec2 delete-security-group --group-id $v_adminsg_id
