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
	local p_igw_name=$1

	# check to see if it already exists else create it.
	local v_igw_id=$(get_igw_id_f $p_igw_name)

	if [ -z "$v_igw_id" ]
	then
	# create an internet gateway (to allow access out to the internet)
	local v_igw_id=$(aws ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')

	# Tag the internet gateway
	aws ec2 create-tags --resources $v_igw_id --tags Key=igwname,Value=$p_igw_name
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
	# Bernie Pruss
	# called by:
	#
	local p_procedure_name=$0
	local p_vpc_id=$1
	local p_deployzone=$2
	local p_deployzone2=$3
	local p_rtb_id=$4
	local p_igw_id=$5

  if [ -z "$5" ]
	then
	  echo not enough paramenters in procedure $p_procedure_name
		echo expectng vpc_id, deployzone deployzone2, rtb_id, igw_id
		echo exiting
		exit
  fi
  # should we tag our subnet's more meaninfully? Pub/priv?
	# let's try it.
	local v_subnet1_tag=${v_vpc_name}_1
	local v_subnet2_tag=${v_vpc_name}_2
	# create our main subnets
	# we use 10.0.0.0/24 as our main subnet and 10.0.10.0/24 as a backup for multi-az rds
	local v_subnet_id=$(aws ec2 create-subnet --vpc-id $p_vpc_id --cidr-block 10.0.1.0/24 --availability-zone $p_deployzone --output text --query 'Subnet.SubnetId')
	echo first v_subnet_id=$v_subnet_id
	# tag this subnet
	aws ec2 create-tags --resources $v_subnet_id --tags Key=subnet,Value=$v_subnet1_tag
	# associate this subnet with our route table
	aws ec2 associate-route-table --subnet-id $v_subnet_id --route-table-id $p_rtb_id
	# now the 10.0.10.0/24 subnet in our secondary deployment zone
	local v_subnet_id=$(aws ec2 create-subnet --vpc-id $v_vpc_id --cidr-block 10.0.2.0/24 --availability-zone $v_deployzone2 --output text --query 'Subnet.SubnetId')
	echo 2nd v_subnet_id=$v_subnet_id
	# tag this subnet
	aws ec2 create-tags --resources $v_subnet_id --tags Key=subnet,Value=$v_subnet2_tag
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
	local p_igw_name=$1
#  local p_igw_id=''
	local p_igw_id=$(aws ec2 describe-internet-gateways --filters Name=tag-key,Values=igwname --filters Name=tag-value,Values=$p_igw_name --output text --query 'InternetGateways[*].InternetGatewayId')
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
  local p_vpc_name=$1
	local p_igw_name=$2
	local v_vpc_id=$(get_vpc_id_f $p_vpc_name)
	local v_igw_id=$(get_igw_id_f $p_igw_name)

  echo vpc_id=$v_vpc_id
	echo igw_id=$v_igw_id

	aws ec2 detach-internet-gateway --internet-gateway-id $v_igw_id --vpc-id $v_vpc_id
	echo between detach and delete
	aws ec2 delete-internet-gateway --internet-gateway-id $v_igw_id
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

delete_vpc_subnets_p() {
local p_procedure_name=$0
local p_vpc_name=$1
local v_vpc_id=$(get_vpc_id_f $p_vpc_name)
#
local v_subnet1_tag=${p_vpc_name}_1
local v_subnet2_tag=${p_vpc_name}_2
# delete subnets
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=$v_subnet1_tag --output text --query 'Subnets[*].SubnetId')
echo deleting subnet_id=$v_subnet_id
aws ec2 delete-subnet --subnet-id $v_subnet_id
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=$v_subnet2_tag --output text --query 'Subnets[*].SubnetId')
echo deleting subnet_id=$v_subnet_id
aws ec2 delete-subnet --subnet-id $v_subnet_id
}

delete_rtb_p () {
	local p_procedure_name=$0
	local p_vpc_name=$1
	local v_vpc_id=$(get_vpc_id_f $p_vpc_name)
	local v_rtb_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'RouteTables[*].RouteTableId')
	echo v_rtb_id=$v_rtb_id
	aws ec2 delete-route-table --route-table-id $v_rtb_id
}

delete_vpc_p (){
	local p_procedure_name=$0
	local p_vpcname=$1
	local v_vpc_id=$(get_vpc_id_f $p_vpcname)
	aws ec2 delete-vpc --vpc-id $v_vpc_id
	echo deleted vpc_name=$p_vpcname vpc_id=$v_vpc_id
}

make_vpc_f(){
	# Bernie Pruss
	# Create VPC if it does not already exist.  create internet gateway and attach it to VPC.
	# call create subnets to create two subnets.
	local p_procedure_name=$0
  local p_vpc_name=$1
	local p_igw_name=$2

  # See if this vpc already is in use, exit if it is...
	local v_vpc_id=$(get_vpc_id_f $p_vpc_name)
	if [ -z "$v_vpc_id" ]
	then
	  echo VPC $p_vpc_name does not exist, creating...
  else
		echo VPC $p_vpc_name already exists, exiting...
		exit
	fi

	v_vpc_id=$(create_vpc_f $p_vpc_name)
	echo created v_vpc_id=$v_vpc_id

	wait_for_vpc_p $p_vpc_name

	local v_igw_id=$(create_igw_f $p_igw_name )
	echo v_igw_id=$v_igw_id

	attach_igw_p $v_vpc_id $v_igw_id

	# get the route table id for the vpc (we need it later)
	local v_rtb_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'RouteTables[*].RouteTableId')
	echo v_rtb_id=$v_rtb_id
  aws ec2 create-tags --resources $v_rtb_id --tags Key=subnet,Value=$v_rtb_name

	create_subnets_p $v_vpc_id $v_deployzone $v_deployzone2 $v_rtb_id $v_igw_id

}

make_passwords_p () {
	local p_procedure_name=$0
	local p_path=$1
	local p_filename=$2
	local p_num_passwords=$3

if [ -z "$p_num_passwords" ]
	then
	p_num_passwords=20
fi
if [ -z "$p_filename" ]
	then
	p_filename=passwords.sh
fi
if [ -z "$p_path" ]
	then
	p_path=../mycredentials
fi


 local v_pw_filename=${p_path}/${p_filename}

	echo p_num_passwords=$p_num_passwords

	echo v_pw_filename=$v_pw_filename

	# start the passwords script
	echo "#!/bin/bash" > $v_pw_filename
  echo set_passwords_p \(\) \{ > $v_pw_filename
	echo "rds mainuser password (max 16)"
	local v_newpassword=$(openssl rand -base64 10)
	v_newpassword=$(echo $v_newpassword | tr '/' '0')
	echo "v_password1=$v_newpassword" >> $v_pw_filename

	for (( i=2; i<=$p_num_passwords; i++ ))
	do
		# randomly discard some passwords
		local v_randdiscard=$[1+$[RANDOM%10]]
	#	echo "next password $randdiscard"
		for (( j=1; j<=$v_randdiscard; j++ ))
		do
			v_newpassword=$(openssl rand -base64 33)
	#		echo "discarded 1"
		done
		v_newpassword=$(openssl rand -base64 33)
		v_newpassword=$(echo $v_newpassword | tr '/' '0')
		echo "v_password$i=$v_newpassword" >> $v_pw_filename
	done
  echo \} >> $v_pw_filename
	echo >> $v_pw_filename

	echo display_passwords_p \(\) \{ >> $v_pw_filename
	echo echo displaying password variables >> $v_pw_filename
	for (( i=1; i<=$p_num_passwords; i++ ))
	do
		echo "echo v_password$i=\$v_password$i" >> $v_pw_filename
  done

  echo echo after display variables  >> $v_pw_filename
	echo \} >> $v_pw_filename
	echo >> $v_pw_filename

	# make the generated script executable
	chmod +x $v_pw_filename
}

# make_passwords_p ../mycredentials testpassswords.sh  20
#source ${v_pw_filename}
#echo after source before set
#set_passwords_p
#echo after set before display
#display_passwords_p


#source ../mycredentials/vars123.sh
#set_vars_p PRJ001
#display_vars_p ALL
#make_vpc_f $v_vpc_name $v_igw_name
