#!/bin/bash

# makes an rds database
# database is populated in admin server setup

# load master vars into variables.
source ../mycredentials/vars.sh
set_vars_p
display_vars_p ALL


if [ -e "../mycredentials/passwords.sh" ]
then
  echo passwords.sh file exits
else
	echo passwords.sh does not exist, executing makepasswords.sh
  ../mycredentials/makepasswords.sh
	echo "passwords.sh made"
fi
# load passwords into vars
. ../mycredentials/passwords.sh

# create an rds db subnet group which spans both our subnets (10.0.0.0/24 and 10.0.10.0/24)
v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].VpcId')
echo v_vpc_id=$v_vpc_id
v_subnet_ids=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'Subnets[*].SubnetId')
echo v_subnet_ids=$v_subnet_ids
aws rds create-db-subnet-group --db-subnet-group-name $v_dbsubnetgroupname --db-subnet-group-description $v_dbsubnetgroupdesc --subnet-ids $v_subnet_ids

# create a vpc security group
# db sg will control access to the database
v_sg_id=$(aws ec2 create-security-group --group-name dbsg --description "rds database security group" --vpc-id $v_vpc_id --output text --query 'GroupId')
echo v_sg_id=$v_sg_id
# tag it
aws ec2 create-tags --resources $v_sg_id --tags Key=sgname,Value=dbsg
# get its id
v_vpcdbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=dbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcdbsg_id=$v_vpcdbsg_id

# we want to log slow queries and set the trigger time to be 1 second
# any query taking more than 1 second will be logged
echo making db parameter group
aws rds create-db-parameter-group --db-parameter-group-name $v_dbpgname --db-parameter-group-family MySQL5.6 --description $v_dbpgdesc
aws rds modify-db-parameter-group --db-parameter-group-name $v_dbpgname --parameters ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate
aws rds modify-db-parameter-group --db-parameter-group-name $v_dbpgname --parameters ParameterName=long_query_time,ParameterValue=1,ApplyMethod=immediate

# create the rds instance
# you can't specify the private ip address for an rds instance, but they tend to be in the 200s...

# the mysql version can change (if AWS force an upgrade for security reasons)
# enter the required mysql version here
# (attempt to launch an instance in the console to see minimum version)
# Bernie Pruss - 4/20/2016 updated version number
v_mysqlversion=5.6.27

if (($v_rdsusemultiaz > 0)); then

 # multi-az : can't use --availability-zone with --multi-az
 aws rds create-db-instance --db-instance-identifier $v_dbinstancename --db-instance-class $v_rdsinstancetype --db-name $v_dbname --engine MySQL --engine-version $v_mysqlversion --port 3306 --allocated-storage $v_rdsvolumesize --no-auto-minor-version-upgrade --db-parameter-group-name $v_dbpgname --master-username mainuser --master-user-password $v_password1 --backup-retention-period 14 --no-publicly-accessible --region $v_deployregion --multi-az --vpc-security-group-ids $v_vpcdbsg_id --db-subnet-group-name $v_dbsubnetgroupname
else
 # no multi-az
 aws rds create-db-instance --db-instance-identifier $v_dbinstancename --db-instance-class $v_rdsinstancetype --db-name $v_dbname --engine MySQL --engine-version $v_mysqlversion --port 3306 --allocated-storage $v_rdsvolumesize --no-auto-minor-version-upgrade --db-parameter-group-name $v_dbpgname --master-username mainuser --master-user-password $v_password1 --backup-retention-period 14 --no-publicly-accessible --region $v_deployregion --availability-zone $v_deployzone --vpc-security-group-ids $v_vpcdbsg_id --db-subnet-group-name $v_dbsubnetgroupname
fi

echo database started, use make2.sh to check for completion
