#!/bin/bash

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

# Load passwords into variables
# include passwords
source ../mycredentials/passwords.sh
v_rootpass=$v_password2
v_ec2pass=$v_password3


# EBS volume size specifier
#bdm=[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$adminebsvolumesize}}]
# Bernie Pruss 4/17/2016 - change sda1 to xvda
v_bdm=[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$v_adminebsvolumesize}}]
echo bdm=$v_bdm

echo "building admin"

echo "check admin not exist"
v_exists=$(aws ec2 describe-key-pairs --key-names admin --output text --query 'KeyPairs[*].KeyName' 2>/dev/null)

if test "$v_exists" = "admin"; then
 echo "key admin already exists continueing"

else
 echo "key admin not found - proceeding"
 # make keypair
 #rm credentials/admin.pem
 #aws ec2 delete-key-pair --key-name admin
 aws ec2 create-key-pair --key-name admin --query 'KeyMaterial' --output text > ../mycredentials/admin.pem
 chmod 600 ../mycredentials/admin.pem
 echo "keypair admin made"
fi

# get our ip from amazon
v_myip=$(curl http://checkip.amazonaws.com/)
echo v_myip=$v_myip


# make security group
v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].VpcId')
echo v_vpc_id=$v_vpc_id
v_sg_id=$(aws ec2 create-security-group --group-name adminsg --description "admin security group" --vpc-id $v_vpc_id --output text --query 'GroupId')
echo v_sg_id=$v_sg_id
# tag it
aws ec2 create-tags --resources $v_sg_id --tags Key=sgname,Value=adminsg
# get its id
v_vpcadminsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=adminsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcadminsg_id=$v_vpcadminsg_id

# allow ssh
aws ec2 authorize-security-group-ingress --group-id $v_vpcadminsg_id --protocol tcp --port 38142 --cidr $v_myip/32
echo "adminsg made"

# get the main subnet
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=1 --output text --query 'Subnets[*].SubnetId')
echo v_subnet_id=$v_subnet_id

# get the shared image id
v_bslami_id=$(aws ec2 describe-images --filters 'Name=name,Values=Basic Secure Linux' --output text --query 'Images[*].ImageId')
echo v_bslami_id=$v_bslami_id

# make the instance
v_instance_id=$(aws ec2 run-instances --image $v_bslami_id --placement AvailabilityZone=$v_deployzone --key admin --security-group-ids $v_vpcadminsg_id --instance-type $v_admininstancetype --block-device-mapping $v_bdm --region $v_deployregion --subnet-id $v_subnet_id --private-ip-address 10.0.0.10 --output text --query 'Instances[*].InstanceId')
echo v_instance_id=$v_instance_id

# wait for it
echo -n "waiting for instance"
while v_state=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$v_state" = "pending"; do
 echo -n . ; sleep 3;
done; echo "v_state=$v_state"

# find an unused eip or make one eip? External IP?
v_eip=$(aws ec2 describe-addresses --output text --query 'Addresses[*].PublicIp')
echo eip=$v_eip

v_useeip=
v_eiparr=$(echo $v_eip | tr " " "\n")
for i in $v_eiparr
do
 echo found eip $i
 v_eipinsid=$(aws ec2 describe-addresses --filters Name=public-ip,Values=$i --output text --query 'Addresses[*].InstanceId')
 echo eip $i instanceid $v_eipinsid
 if test -z "$v_eipinsid"; then
  v_useeip=$i
 fi
done

# check if eip found, otherwise make one
if test -z "$v_useeip"; then
	echo "no eip, allocate one"
	# Bernie Pruss 4/18 convert to --domain vpc
        v_useeip=$(aws ec2 allocate-address --domain vpc --output text --query 'PublicIp')
fi
echo v_useeip=$v_useeip

echo get v_ip_alloc_id
# 4/17/2016 Bernie Pruss get the allocation id of the ip address:
v_ip_alloc_id=$(aws ec2 describe-addresses --filters Name=public-ip,Values=$v_useeip --output text --query 'Addresses[*].AllocationId')
echo v_ip_alloc_id=$v_ip_alloc_id

# associate eip with admin instance
#aws ec2 associate-address --instance-id $instance_id --public-ip $useeip
#Bernie Pruss 4/17/2016 - Modify to use allocation_id
echo about to associate-adddress
aws ec2 associate-address --instance-id $v_instance_id --allocation-id $v_ip_alloc_id
echo "associated eip with admin instance"

# get adminhost private ip
v_adminhost=$(aws ec2 describe-instances --filters Name=key-name,Values=admin --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')
echo v_adminhost=$v_adminhost

# ipaddress is new eib address
v_ip_address=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
echo v_ip_address=$v_ip_address

# allow access to rds database
echo "allowing access to rds database"
v_vpcdbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=dbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcdbsg_id=$v_vpcdbsg_id
aws ec2 authorize-security-group-ingress --group-id $v_vpcdbsg_id --source-group $v_vpcadminsg_id --protocol tcp --port 3306

# get the database address
v_dbendpoint=$(aws rds describe-db-instances --db-instance-identifier $v_dbinstancename --output text --query 'DBInstances[*].Endpoint.Address')

# sed data files

sed "s/SEDadminpublicipSED/$v_ip_address/g" ./admin/install_admin_template.sh > ./admin/install_admin.sh
chmod +x ./admin/install_admin.sh

sed -e "s/SEDdbhostSED/$v_dbendpoint/g" -e "s/SEDdbnameSED/$v_dbname/g" -e "s/SEDdbpass_adminrwSED/$v_password4/g" ./admin/httpd_template.conf > ./admin/httpd.conf

sed -e "s/SEDdbhostSED/$v_dbendpoint/g" -e "s/SEDdbmainuserpassSED/$v_password1/g" ./admin/config_inc_template.php > ./admin/config.inc.php

sed "s/SED-EC2-USER-PASS-SED/$v_ec2pass/g" ./shared/chp_ec2-user.sh > ./admin/chp_ec2-user.sh
chmod +x ./admin/chp_ec2-user.sh

sed "s/SED-ROOT-PASS-SED/$v_rootpass/g" ./shared/chp_root.sh > ./admin/chp_root.sh
chmod +x ./admin/chp_root.sh

sed -e "s/SEDadminpublicipSED/$v_ip_address/g" -e "s/SEDadminprivateipSED/$v_adminhost/g" ./admin/server_template.xml > ./admin/server.xml

# wait for ssh
echo -n "waiting for ssh"
while ! ssh -i ../mycredentials/admin.pem -p 38142 -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address > /dev/null 2>&1 true; do
 echo -n . ; sleep 3;
done; echo " ssh ok"

# send files
echo "transferring files"
scp -i ../mycredentials/admin.pem -P 38142 admin/httpd.conf ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/monit.conf ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/rsyslog.conf ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/config.php ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/config.inc.php ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/server.xml ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/install_admin.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/chp_ec2-user.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/chp_root.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/logrotatehttp ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/mmonit-3.2.1-linux-x64.tar.gz ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/loganalyzer-3.6.5.tar.gz ec2-user@$v_ip_address:
scp -i ../mycredentials/admin.pem -P 38142 admin/launch_javaMail.sh ec2-user@$v_ip_address:
echo "transferred files"

echo removing generated files
rm -f admin/install_admin.sh
rm -f admin/httpd.conf
rm -f admin/config.inc.php
rm -f admin/chp_ec2-user.sh
rm -f admin/chp_root.sh
rm -f admin/server.xml

# run the install script
echo "running install_admin.sh"
ssh -i ../mycredentials/admin.pem -p 38142 -t -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address sudo ./install_admin.sh
# ssh -i ../mycredentials/admin.pem -p 38142 -t -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$52.204.179.229 sudo ./install_admin.sh
echo "finished install_admin.sh"

# close the ssh port
echo "removing ssh access from sg"
aws ec2 revoke-security-group-ingress --group-id $v_vpcadminsg_id --protocol tcp --port 38142 --cidr $v_myip/32

#cd $basedir

# done
echo "admin done - needs upload"
