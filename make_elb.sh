#!/bin/bash

# makes an elb
# elbselfsigned (in aws/master/vars.sh) decides if self-signed or valid cert is used

source ../mycredentials/vars.sh
set_vars_p
display_vars_p ALL

echo "launching ELB"

echo "check ELB does not exist"
v_exists=$(aws elb describe-load-balancers --load-balancer-names $v_elbname --output text --query 'LoadBalancerDescriptions[*].LoadBalancerName' 2>/dev/null)

if test "$v_exists" = $v_elbname; then
 echo "ELB already exists = exiting"
 exit
else
 echo "ELB not found - proceeding"
fi

if (($v_elbselfsigned == 1)); then

echo "making self-signed ssl"

# sleeps are needed or it won't work
cd elb/ssl
rm -f cert.pem
rm -f key.pem
rm -f server.crt
rm -f server.csr
rm -f server.key
rm -f server.key.org
echo deleted old files
./ssl1.sh
./ssl2.sh
cp server.key server.key.org
./ssl3.sh
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
sleep 15
cp server.key key.pem
openssl x509 -inform PEM -in server.crt > cert.pem
sleep 15
# aws iam delete-server-certificate --server-certificate-name $v_elbcertname
sleep 15
v_sslarn=$(aws iam upload-server-certificate --server-certificate-name $v_elbcertname --certificate-body file://cert.pem --private-key file://key.pem --output text --query 'ServerCertificateMetadata.Arn')
echo v_sslarn=$v_sslarn

else

echo "using valid ssl"

# read the valid SSL cert and upload to iam
echo "using valid ssl"
cd elb/validssl
v_cert=$(cat $v_elbvalidcertcertfile)
echo loaded v_cert
v_key=$(cat $v_elbvalidcertkeyfile)
echo loaded v_key
v_inter=$(cat $v_elbvalidcertinterfile)
echo loaded v_inter

echo deleting previous certificate
aws iam delete-server-certificate --server-certificate-name $v_elbcertname

echo uploading certificate
v_sslarn=$(aws iam upload-server-certificate --server-certificate-name $v_elbcertname --certificate-body "$v_cert" --private-key "$v_key" --certificate-chain "$v_inter" --output text --query 'ServerCertificateMetadata.Arn')
echo v_sslarn=$v_sslarn

fi

# let the cert cook
sleep 5

# make a security group to control access to the elb
echo "making sg"
v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].VpcId')
echo v_vpc_id=$v_vpc_id
v_sg_id=$(aws ec2 create-security-group --group-name elbsg --description "elb security group" --vpc-id $v_vpc_id --output text --query 'GroupId')
echo v_sg_id=$v_sg_id
# tag it
# Bernie note: Value=elbsg is too generic for multiple sets need to make it specific if we want to be able to run two separate profiles.
aws ec2 create-tags --resources $v_sg_id --tags Key=sgname,Value=elbsg
# get its id
v_vpcelbsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=elbsg --output text --query 'SecurityGroups[*].GroupId')
echo v_vpcelbsg_id=$v_vpcelbsg_id
# allow 80, 443 from anywhere into the elb
aws ec2 authorize-security-group-ingress --group-id $v_vpcelbsg_id --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $v_vpcelbsg_id --protocol tcp --port 443 --cidr 0.0.0.0/0
echo "elbsg made"

# get our vpc subnets
v_subnet_ids=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'Subnets[*].SubnetId')
echo v_subnet_ids=$v_subnet_ids

# create an elb
# it listens for http on 80 and https on 443 and forwards both to 80 http (no SSL)
# you can tell if the request came in on SLL with $_SERVER['HTTP_X_FORWARDED_PROTO'] (should be "https") in PHP
aws elb create-load-balancer --load-balancer-name $v_elbname --listener LoadBalancerPort=80,InstancePort=80,Protocol=http,InstanceProtocol=http LoadBalancerPort=443,InstancePort=80,Protocol=https,InstanceProtocol=http,SSLCertificateId=$v_sslarn --security-groups $v_vpcelbsg_id --subnets $v_subnet_ids --region $v_deployregion

# set the elb health check
aws elb configure-health-check --load-balancer-name $v_elbname --health-check Target=HTTP:80/elb.htm,Interval=10,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=2

# show the elb address
v_elbdns=$(aws elb describe-load-balancers --load-balancer-names $v_elbname --output text --query 'LoadBalancerDescriptions[*].DNSName')
echo v_elbdns=$v_elbdns

cd ../..

echo "elb created"
