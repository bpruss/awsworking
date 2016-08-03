#!/bin/bash

# load master vars into variables.
. ../mycredentials/vars.sh

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


echo v_password1=$v_password1
echo v_password2=$v_password2
echo

# a complex string needed to specify EBS volume size
#bdm=[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$sharedebsvolumesize}}]
# Bernie Pruss 4/16/2016 - Change sda1 to xvda
v_bdm=[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$v_sharedebsvolumesize}}]
echo v_bdm=$v_bdm

# get our ip from amazon
v_myip=$(curl http://checkip.amazonaws.com/)
echo v_myip=$v_myip

# make a new keypair
echo "checking keypair"
if [ -e "../mycredentials/basic.pem" ]
then
  echo pem file exits
else
	echo file does not exist, creating keypair
	#aws ec2 delete-key-pair --key-name basic
	aws ec2 create-key-pair --key-name basic --query 'KeyMaterial' --output text > ../mycredentials/basic.pem
	chmod 600 ../mycredentials/basic.pem
	echo "keypair made"
fi

# make a security group
v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].VpcId')
echo v_vpc_id=$v_vpc_id

v_sg_id=$(aws ec2 create-security-group --group-name basicsg --description "basic security group" --vpc-id $v_vpc_id --output text --query 'GroupId')
if [ -z "$v_sg_id" ]
then
  echo v_sg_id is null, exiting.
	exit
else
	echo v_sg_id=$v_sg_id
fi

# tag it
aws ec2 create-tags --resources $v_sg_id --tags Key=sgname,Value=basicsg
v_vpcbasicsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=basicsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcbasicsg_id=$v_vpcbasicsg_id

# allow SSH in on port 22 from our ip only
aws ec2 authorize-security-group-ingress --group-id $v_vpcbasicsg_id --protocol tcp --port 22 --cidr $v_myip/32

# get our main subnet id
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=1 --output text --query 'Subnets[*].SubnetId')
echo subnet_id=$v_subnet_id

# make the instance on 10.0.0.9
v_instance_id=$(aws ec2 run-instances --image $v_baseami --key basic --security-group-ids $v_vpcbasicsg_id --placement AvailabilityZone=$v_deployzone --instance-type $v_sharedinstancetype --block-device-mapping $v_bdm --region $v_deployregion --subnet-id $v_subnet_id --private-ip-address 10.0.0.9 --associate-public-ip-address --output text --query 'Instances[*].InstanceId')
echo v_instance_id=$v_instance_id

# wait for it
echo -n "waiting for instance"
while v_state=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$v_state" = "pending"; do
 echo -n . ; sleep 3;
done; echo " v_state=$v_state"

# get the new instance's public ip address
v_ip_address=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
echo v_ip_address=$v_ip_address

# wait for ssh to work
echo -n "waiting for ssh"
while ! ssh -i credentials/basic.pem -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address > /dev/null 2>&1 true; do
 echo -n . ; sleep 3;
done; echo " ssh ok"
