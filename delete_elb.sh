#!/bin/bash

source ../mycredentials/vars.sh
set_vars_p
display_vars_p ALL

# terminate elb
echo deleting elb $v_elbname
aws elb delete-load-balancer --load-balancer-name $v_elbname

sleep 5
# delete the ssl cert
aws iam delete-server-certificate --server-certificate-name $v_elbcertname

v_elbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=elbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_elbsg_id=$v_elbsg_id

# remove all rules from elbsg
aws ec2 revoke-security-group-ingress --group-id $v_elbsg_id --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 revoke-security-group-ingress --group-id $v_elbsg_id --protocol tcp --port 443 --cidr 0.0.0.0/0

# seems to need a pause
sleep 5
aws ec2 delete-security-group --group-id $v_elbsg_id
