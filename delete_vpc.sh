#!/bin/bash

# load master vars into variables.
. ../mycredentials/vars.sh
set_vars_p

v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].VpcId')
echo v_vpc_id=$v_vpc_id

# delete igw
# v_igw_id=$(aws ec2 describe-internet-gateways --output text --query 'InternetGateways[*].InternetGatewayId')
v_igw_id=$(aws ec2 describe-internet-gateways --filters Name=tag-key,Values=igwname --filters Name=tag-value,Values=myigw --output text --query 'InternetGateways[*].InternetGatewayId')
echo v_igw_id=$v_igw_id

aws ec2 detach-internet-gateway --internet-gateway-id $v_igw_id --vpc-id $v_vpc_id

# aws ec2 detach-internet-gateway --internet-gateway-id igw-748bb210 --vpc-id vpc-9d0869fa

aws ec2 delete-internet-gateway --internet-gateway-id $v_igw_id
# aws ec2 delete-internet-gateway --internet-gateway-id igw-748bb210


# delete subnets
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=1 --output text --query 'Subnets[*].SubnetId')
echo subnet_id=$v_subnet_id
aws ec2 delete-subnet --subnet-id $v_subnet_id
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=2 --output text --query 'Subnets[*].SubnetId')
echo subnet_id=$v_subnet_id
aws ec2 delete-subnet --subnet-id $v_subnet_id

# now we can finally delete the vpc
# all remaining assets are also deleted (eg route table, default security group)
aws ec2 delete-vpc --vpc-id $v_vpc_id

# aws ec2 delete-vpc --vpc-id vpc-af7e1fc8
