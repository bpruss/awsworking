#!/bin/bash

source ../mycredentials/vars.sh
set_vars_p
display_vars_p ALL

aws ec2 delete-key-pair --key-name web$1
rm ../mycredentials/web$1.pem

v_websg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=web$1sg --output text --query 'SecurityGroups[*].GroupId')
echo v_websg_id=$v_websg_id

v_adminsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=adminsg --output text --query 'SecurityGroups[*].GroupId')
echo v_adminsg_id=$v_adminsg_id

v_elbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=elbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_elbsg_id=$v_elbsg_id

aws ec2 revoke-security-group-ingress --group-id $v_adminsg_id --protocol tcp --port 514 --source-group $v_websg_id
aws ec2 revoke-security-group-ingress --group-id $v_adminsg_id --protocol tcp --port 8000 --source-group $v_websg_id

aws ec2 revoke-security-group-ingress --group-id $v_dbsg_id --protocol tcp --port 3306 --source-group $v_websg_id

# remove all rules from web?sg
aws ec2 revoke-security-group-ingress --group-id $v_websg_id --protocol tcp --port 80 --source-group $v_elbsg_id
aws ec2 revoke-security-group-ingress --group-id $v_websg_id --protocol tcp --port 443 --source-group $v_elbsg_id
aws ec2 revoke-security-group-ingress --group-id $v_websg_id --protocol tcp --port 2812 --source-group $v_adminsg_id

aws ec2 delete-security-group --group-id $v_websg_id
