#!/bin/bash

create_vpc_f (){
# Bernie Pruss - 8/6/2016
# Add check for existinance with same name before createing.
  local p_procedure_name=$0
	local p_vpcname=$1
#	local p_vpc_id=''
	local v_master_subnet=10.0.0.0/16
	# make a new vpc with a master 10.0.0.0/16 subnet
	#local v_vpc_id=$(aws ec2 create-vpc --cidr-block $p_master_subnet --output text --query 'Vpc.VpcId')
  local v_vpc_id=$(get_vpc_id_f $p_vpcname)
  # If a VPC exists with this name return the id. Else create a new VPC and return the id.
	if [ -z "$v_vpc_id" ]
	then
	  local	v_vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --query 'Vpc.VpcId')
		# enable dns support or modsecurity wont let apache start...
		aws ec2 modify-vpc-attribute --vpc-id $v_vpc_id --enable-dns-support
		aws ec2 modify-vpc-attribute --vpc-id $v_vpc_id --enable-dns-hostnames
		# tag the vpc
		aws ec2 create-tags --resources $v_vpc_id --tags Key=vpcname,Value=$p_vpcname
  fi
	#echo after create-vpc
	#echo p_vpc_id=$p_vpc_id

  echo $v_vpc_id
}

wait_for_vpc_p(){
	local p_procedure_name=$0
	local p_vpcname=$1
	local v_state=''
	# wait for the vpc
	echo -n "waiting for vpc..."
	while v_state=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$p_vpcname --output text --query 'Vpcs[*].State'); test "$v_state" = "pending"; do
	 echo -n . ; sleep 3;
	done; echo "v_state=$v_state"
}

create_igw_f(){
	local p_procedure_name=$0
	local p_igwname=$1

	# check to see if it already exists else create it.
	local v_igw_id=$(get_igw_id_f $p_igwname)

	if [ -z "$v_igw_id" ]
	then
	# create an internet gateway (to allow access out to the internet)
	v_igw_id=$(aws ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')
	# Tag the internet gateway
	aws ec2 create-tags --resources $v_igw_id --tags Key=igwname,Value=$p_igwname
  fi

	echo $v_igw_id
}

attach_igw_p(){
	local p_procedure_name=$0
  local p_vpc_id=$1
	local p_igw_id=$2
  if [ -z "$p_vpc_id" -o -z "$p_igw_id" ]
	then
	  echo Missig either vpc_id=$p_vpc_id or igw_id=$p_igw_id exiting
	  exit
  else
		#echo before attaching $v_igw_id to $v_vpc_id
	  aws ec2 attach-internet-gateway --internet-gateway-id $v_igw_id --vpc-id $v_vpc_id
		#echo before attaching $v_igw_id to $v_vpc_id
  fi
}

get_rtb_id_f(){
	# get the route table id for the vpc (we need it later)
	local p_procedure_name=$0
  local p_vpc_id=$1
	local v_rtb_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$p_vpc_id --output text --query 'RouteTables[*].RouteTableId')
	echo $v_rtb_id
}

create_subnets_p(){
	local p_procedure_name=$0
	local p_vpc_id=$1
	local p_deployzone=$2
	local p_deployzone2=$3
	local p_rtb_id=$4
	local p_igw_id=$5

  if [ -z "$5" ]
	then
	  echo not enough paramenters exiting
		exit
  fi

	# create our main subnets
	# we use 10.0.0.0/24 as our main subnet and 10.0.10.0/24 as a backup for multi-az rds
	local v_subnet_id=$(aws ec2 create-subnet --vpc-id $p_vpc_id --cidr-block 10.0.0.0/24 --availability-zone $p_deployzone --output text --query 'Subnet.SubnetId')
	#echo v_subnet_id=$v_subnet_id
	# tag this subnet
	aws ec2 create-tags --resources $v_subnet_id --tags Key=subnet,Value=1
	# associate this subnet with our route table
	aws ec2 associate-route-table --subnet-id $v_subnet_id --route-table-id $p_rtb_id
	# now the 10.0.10.0/24 subnet in our secondary deployment zone
	local v_subnet_id=$(aws ec2 create-subnet --vpc-id $v_vpc_id --cidr-block 10.0.10.0/24 --availability-zone $v_deployzone2 --output text --query 'Subnet.SubnetId')
	#echo v_subnet_id=$v_subnet_id
	# tag this subnet
	aws ec2 create-tags --resources $v_subnet_id --tags Key=subnet,Value=2
	# associate this subnet with our route table
	aws ec2 associate-route-table --subnet-id $v_subnet_id --route-table-id $p_rtb_id

	# create a route out from our route table to the igw
	echo creating route from igw
	aws ec2 create-route --route-table-id $p_rtb_id --gateway-id $p_igw_id --destination-cidr-block 0.0.0.0/0

}

get_vpc_id_f () {
	local p_procedure_name=$0
	local p_vpcname=$1
  local p_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$p_vpcname --output text --query 'Vpcs[*].VpcId')
  # return only works for numeric arguments.
	echo $p_vpc_id
}

get_igw_id_f () {
	local p_procedure_name=$0
	local p_igwname=$1
#  local p_igw_id=''
	local p_igw_id=$(aws ec2 describe-internet-gateways --filters Name=tag-key,Values=igwname --filters Name=tag-value,Values=$p_igwname --output text --query 'InternetGateways[*].InternetGatewayId')
	echo $p_igw_id
}

detach_igw_p (){
	local p_procedure_name=$0
	local p_vpc_id=$1
	local p_igw_id=$2
	aws ec2 detach-internet-gateway --internet-gateway-id $p_igw_id --vpc-id $p_vpc_id
}

delete_igw_p (){
	local p_procedure_name=$0
	local p_igw_id=$1
	aws ec2 delete-internet-gateway --internet-gateway-id $p_igw_id
}

get_subnet_id_f () {
	local p_procedure_name=$0
	local p_vpc_id=$1
	local p_tag_key_value=$2
	local p_tag_value=$3
	#v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=1 --output text --query 'Subnets[*].SubnetId')
	local p_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=$p_tag_key_value --filters Name=tag-value,Values=$p_tag_value --output text --query 'Subnets[*].SubnetId')
	echo $p_subnet_id
}

delete_subnet_p() {
echo do nothing yet
}

delete_vpc_p (){
	local p_procedure_name=$0
	local p_vpcname=$1
	local v_vpc_id=$(get_vpc_id_f $p_vpcname)
	aws ec2 delete-vpc --vpc-id $v_vpc_id
	echo deleted vpc_name=$p_vpcname vpc_id=$v_vpc_id
}
