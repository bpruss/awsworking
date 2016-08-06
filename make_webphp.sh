#!/bin/bash

# makes a webphp linux box, from linux hardened image
# ssh on 38142
# webphpebsvolumesize GB EBS root volume

# parameters <N> where this is the Nth web box (1-5)

source ../mycredentials/vars.sh
set_vars_p
display_vars_p ALL

# Bernie Pruss - sda1 to xvda
#bdm=[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$webphpebsvolumesize}}]
v_bdm=[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$v_webphpebsvolumesize}}]
echo v_bdm=$v_bdm

v_webid=$1
if test -z "$v_webid"; then
 v_webid=1
fi

echo "building web$v_webid"

echo "check web$v_webid does not exist"
v_exists=$(aws ec2 describe-key-pairs --key-names web$v_webid --output text --query 'KeyPairs[*].KeyName' 2>/dev/null)

if test "$v_exists" = "web$v_webid"; then
 echo "key web$v_webid already exists = exiting"
 #exit
else
 echo "key web$v_webid not found - proceeding"
fi

source ../mycredentials/passwords.sh

if test "$v_webid" = "1"; then
 v_rootpass=$v_password8
 v_ec2pass=$v_password9
elif test "$v_webid" = "2"; then
 v_rootpass=$v_password10
 v_ec2pass=$v_password11
elif test "$v_webid" = "3"; then
 v_rootpass=$v_password12
 v_ec2pass=$v_password13
elif test "$v_webid" = "4"; then
 v_rootpass=$v_password14
 v_ec2pass=$v_password15
elif test "$v_webid" = "5"; then
 v_rootpass=$v_password16
 v_ec2pass=$v_password17
elif test "$v_webid" = "6"; then
 v_rootpass=$v_password18
 v_ec2pass=$v_password19
else
 echo "v_password for web$v_webid not found - exiting"
 exit
fi

v_myip=$(curl http://checkip.amazonaws.com/)
echo v_myip=$v_myip

echo "making keypair"
# put test for file exist here.
rm ../mycredentials/web$v_webid.pem
# aws ec2 delete-key-pair --key-name web$v_webid
aws ec2 create-key-pair --key-name web$v_webid --query 'KeyMaterial' --output text > ../mycredentials/web$v_webid.pem
chmod 600 ../mycredentials/web$v_webid.pem
echo "keypair web$v_webid made"

echo "making sg"
v_websg=web$v_webid
v_websg+=sg
echo v_websg=$v_websg

v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].VpcId')
echo v_vpc_id=$v_vpc_id

# aws ec2 delete-security-group --group-name $v_websg

v_sg_id=$(aws ec2 create-security-group --group-name $v_websg --description "web$v_webid security group" --vpc-id $v_vpc_id --output text --query 'GroupId')
echo v_sg_id=$v_sg_id
aws ec2 create-tags --resources $v_sg_id --tags Key=sgname,Value=$v_websg

v_vpcwebsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=$v_websg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcwebsg_id=$v_vpcwebsg_id
aws ec2 authorize-security-group-ingress --group-id $v_vpcwebsg_id --protocol tcp --port 38142 --cidr $v_myip/32
echo "$v_websg made"

echo "getting subnet id"
cdv_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=1 --output text --query 'Subnets[*].SubnetId')
echo v_subnet_id=$v_subnet_id

echo "getting basic secure linux ami id"
v_bslami_id=$(aws ec2 describe-images --filters 'Name=name,Values=Basic Secure Linux' --output text --query 'Images[*].ImageId')
echo v_bslami_id=$v_bslami_id

echo "getting adminhost private ip"
v_adminhost=$(aws ec2 describe-instances --filters Name=key-name,Values=admin --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')
echo v_adminhost=$v_adminhost

echo "getting adminhost security group id"
v_vpcadminsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=adminsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcadminsg_id=$v_vpcadminsg_id

echo "allowing access to admin server :514 for rsyslog"
aws ec2 authorize-security-group-ingress --group-id $v_vpcadminsg_id --protocol tcp --port 514 --source-group $v_vpcwebsg_id

echo "allowing access to admin server :8080 for mmonit"
aws ec2 authorize-security-group-ingress --group-id $v_vpcadminsg_id --protocol tcp --port 8080 --source-group $v_vpcwebsg_id

echo "allowing access to webphp from admin server :2812 for mmonit callback"
aws ec2 authorize-security-group-ingress --group-id $v_vpcwebsg_id --protocol tcp --port 2812 --source-group $v_vpcadminsg_id

echo "allowing access to rds database"
v_vpcdbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=dbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcdbsg_id=$v_vpcdbsg_id
aws ec2 authorize-security-group-ingress --group-id $v_vpcdbsg_id --source-group $v_vpcwebsg_id --protocol tcp --port 3306

v_dbendpoint=$(aws rds describe-db-instances --db-instance-identifier $v_dbinstancename --output text --query 'DBInstances[*].Endpoint.Address')
echo v_dbendpoint=$v_dbendpoint

echo "making instance web$v_webid"
instance_id=$(aws ec2 run-instances --image $v_bslami_id --placement AvailabilityZone=$v_deployzone --key web$v_webid --security-group-ids $v_vpcwebsg_id --instance-type $v_webphpinstancetype --block-device-mapping $v_bdm --region $v_deployregion --subnet-id $v_subnet_id --private-ip-address 10.0.0.1$v_webid --associate-public-ip-address --output text --query 'Instances[*].InstanceId')
echo v_instance_id=$v_instance_id

# build data

cd webphp

rm -f monit.conf
rm -f rsyslog.conf
rm -f httpd.conf
rm -f chp_ec2-user.sh
rm -f chp_root.sh

sed "s/SEDadminhostSED/$v_adminhost/g" monit_template.conf > monit.conf

sed "s/SEDadminhostSED/$v_adminhost/g" rsyslog_template.conf > rsyslog.conf

cd ..

# make the AES key for PHP sessions
# its a hex encoded version of $v_password20
v_aes1=$v_password20
# convert to hex
v_aes2=$(hexdump -e '"%X"' <<< "$v_aes1")
# lowercase
v_aes3=$(echo $v_aes2 | tr '[:upper:]' '[:lower:]')
# only the first 64 characters
v_aes4=${v_aes3:0:64}

# sed httpd.conf
source ../mycredentials/account.sh
source ../mycredentials/recaptcha.sh
sed -e "s/SEDdbhostSED/$v_dbendpoint/g" -e "s/SEDdbnameSED/$v_dbname/g" -e "s/SEDdbpass_webphprwSED/$v_password5/g" -e "s/SEDaeskeySED/$v_aes4/g" -e "s/SEDserveridSED/$v_webid/g" -e "s/SEDaws_deployregionSED/$v_deployregion/g" -e "s/SEDaws_accountSED/$v_aws_account/g" -e "s/SEDrecaptcha_privatekeySED/$v_recaptcha_privatekey/g" -e "s/SEDrecaptcha_publickeySED/$v_recaptcha_publickey/g" webphp/httpd_template.conf > webphp/httpd.conf

sed "s/SED-EC2-USER-PASS-SED/$v_ec2pass/g" shared/chp_ec2-user.sh > webphp/chp_ec2-user.sh
chmod +x webphp/chp_ec2-user.sh

sed "s/SED-ROOT-PASS-SED/$v_rootpass/g" shared/chp_root.sh > webphp/chp_root.sh
chmod +x webphp/chp_root.sh

echo -n "waiting for instance"
while v_state=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$v_state" = "pending"; do
 echo -n . ; sleep 3;
done; echo "v_state=$v_state"

v_priv_ip_address=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')
echo v_priv_ip_address=$v_priv_ip_address

v_ip_address=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
echo v_ip_address=$v_ip_address

echo -n "waiting for ssh"
while ! ssh -i ../mycredentials/web$v_webid.pem -p 38142 -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address > /dev/null 2>&1 true; do
 echo -n . ; sleep 3;
done; echo " ssh ok"

echo "transferring files"
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/rsyslog.conf ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/monit.conf ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/httpd.conf ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/modsecurity_overrides ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/php.ini ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/install_webphp.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/chp_ec2-user.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/chp_root.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/web$v_webid.pem -P 38142 webphp/mod_rpaf-0.6-0.7.x86_64.rpm ec2-user@$v_ip_address:
echo "transferred files"

rm -f webphp/monit.conf
rm -f webphp/rsyslog.conf
rm -f webphp/httpd.conf
rm -f webphp/chp_ec2-user.sh
rm -f webphp/chp_root.sh

echo "running install_webphp.sh"
ssh -i ../mycredentials/web$v_webid.pem -p 38142 -t -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address sudo ./install_webphp.sh
echo "finished install_webphp.sh"

# register with elb
echo "registering with elb"
aws elb register-instances-with-load-balancer --load-balancer-name $v_elbname --instances $v_instance_id

echo "add elb sg to instance sg"
v_vpcelbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=elbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcelbsg_id=$v_vpcelbsg_id
aws ec2 authorize-security-group-ingress --group-id $v_vpcwebsg_id --source-group $v_vpcelbsg_id --protocol tcp --port 80
aws ec2 authorize-security-group-ingress --group-id $v_vpcwebsg_id --source-group $v_vpcelbsg_id --protocol tcp --port 443

echo "removing ssh access from sg"
aws ec2 revoke-security-group-ingress --group-id $v_vpcwebsg_id --protocol tcp --port 38142 --cidr $v_myip/32

echo "web php done - needs upload"
