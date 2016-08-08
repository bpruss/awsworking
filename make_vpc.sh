#!/bin/bash

# Bernie Pruss
# Need to add missing lags for a couple items like the router table.

# load master vars into variables.
source ../mycredentials/vars.sh
set_vars_p
display_vars_p AWS
display_vars_p NET

# make a new vpc with a master 10.0.0.0/16 subnet
v_vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --query 'Vpc.VpcId')
echo after create-vpc
echo v_vpc_id=$v_vpc_id

# enable dns support or modsecurity wont let apache start...
aws ec2 modify-vpc-attribute --vpc-id $v_vpc_id --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id $v_vpc_id --enable-dns-hostnames

# tag the vpc
aws ec2 create-tags --resources $v_vpc_id --tags Key=vpcname,Value=$v_vpcname

# wait for the vpc
echo -n "waiting for vpc..."
while v_state=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpcname --output text --query 'Vpcs[*].State'); test "$v_state" = "pending"; do
 echo -n . ; sleep 3;
done; echo "v_state=$v_state"

# create an internet gateway (to allow access out to the internet)
v_igw_id=$(aws ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')
echo v_igw_id=$v_igw_id

# Tag the internet gateway
v_igwname=myigw
aws ec2 create-tags --resources $v_igw_id --tags Key=igwname,Value=$v_igwname


# attach the igw to the vpc
echo attaching igw aka internet gateway
aws ec2 attach-internet-gateway --internet-gateway-id $v_igw --vpc-id $v_vpc_id

# get the route table id for the vpc (we need it later)
v_rtb_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'RouteTables[*].RouteTableId')
echo v_rtb_id=$v_rtb_id

# create our main subnets
# we use 10.0.0.0/24 as our main subnet and 10.0.10.0/24 as a backup for multi-az rds
v_subnet_id=$(aws ec2 create-subnet --vpc-id $v_vpc_id --cidr-block 10.0.0.0/24 --availability-zone $v_deployzone --output text --query 'Subnet.SubnetId')
echo v_subnet_id=$v_subnet_id
# tag this subnet
aws ec2 create-tags --resources $v_subnet_id --tags Key=subnet,Value=1
# associate this subnet with our route table
aws ec2 associate-route-table --subnet-id $v_subnet_id --route-table-id $v_rtb_id
# now the 10.0.10.0/24 subnet in our secondary deployment zone
v_subnet_id=$(aws ec2 create-subnet --vpc-id $v_vpc_id --cidr-block 10.0.10.0/24 --availability-zone $v_deployzone2 --output text --query 'Subnet.SubnetId')
echo v_subnet_id=$v_subnet_id
# tag this subnet
aws ec2 create-tags --resources $v_subnet_id --tags Key=subnet,Value=2
# associate this subnet with our route table
aws ec2 associate-route-table --subnet-id $v_subnet_id --route-table-id $v_rtb_id

# create a route out from our route table to the igw
echo creating route from igw
aws ec2 create-route --route-table-id $v_rtb_id --gateway-id $v_igw --destination-cidr-block 0.0.0.0/0

# done
echo vpc setup done
