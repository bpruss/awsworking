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
	# wait for the vpc 9/11/2016 convert to use the wait command.  :)
	echo "waiting for vpc..."
	v_wait_result=$(aws ec2 wait vpc-available --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$p_vpcname --output text --query 'Vpcs[*].State')
	if ! [ -z $v_wait_result ] ; then
	  echo v_wait_result=$v_wait_result
	fi
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
  if [ -z "$p_vpc_id" -o -z "$p_igw_id" ] ;	then
	  echo Missig either vpc_id=$p_vpc_id or igw_id=$p_igw_id exiting
	  exit
  else
	  aws ec2 attach-internet-gateway --internet-gateway-id $v_igw_id --vpc-id $v_vpc_id
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
  if ! [ -z "$v_igw_id" ] ; then
	  aws ec2 detach-internet-gateway --internet-gateway-id $v_igw_id --vpc-id $v_vpc_id
	  #echo between detach and delete
	  aws ec2 delete-internet-gateway --internet-gateway-id $v_igw_id
	else
		echo $p_igw_name does not exist.
  fi
}

get_subnet_id_f () {
	local p_procedure_name=$0
	local p_vpc_id=$1
	local p_tag_key_value=$2
	local p_tag_value=$3
	local p_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=$p_tag_key_value --filters Name=tag-value,Values=$p_tag_value --output text --query 'Subnets[*].SubnetId')
	echo $p_subnet_id
}

delete_vpc_subnets_p() {
local p_procedure_name=$0
local p_vpc_name=$1
local v_vpc_id=$(get_vpc_id_f $p_vpc_name)
# delete subnets
local v_subnet_ids=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'Subnets[*].[SubnetId]')
echo v_subnet_ids=$v_subnet_ids
if [ -z "$v_subnet_ids" ] ; then
  echo no subnets for $p_vpc_name/$v_vpc_id.
else
  for v_subnet_id in $v_subnet_ids; do
    aws ec2 delete-subnet --subnet-id $v_subnet_id
	done
fi
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

make_shared_template_p(){
	local p_procedure_name=$0
	local p_ami_id=$1
	local p_template_name=$2
	# return the ami_id of the hardened template

# check for password file and create it if it does not exit
if [ -e "../mycredentials/passwords.sh" ]
then
  echo passwords.sh file exits
else
	echo passwords.sh does not exist, executing makepasswords.sh
  make_passwords_p ../mycredentials passwords.sh  20
	echo "passwords.sh made"
fi

# source and set passwords
source ../mycredentials/passwords.sh
set_passwords_p

# a complex string needed to specify EBS volume size
#bdm=[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$sharedebsvolumesize}}]
# Bernie Pruss 4/16/2016 - Change sda1 to xvda
v_bdm=[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$v_sharedebsvolumesize}}]
echo v_bdm=$v_bdm

# get our ip from amazon
#v_myip=$(curl http://checkip.amazonaws.com/)
#echo v_myip=$v_myip

# make a new keypair
echo "creating keypair"
create_key_pair_p basic

# make a security group
v_vpc_id=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$v_vpc_name --output text --query 'Vpcs[*].VpcId')
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
local v_subnet1_tag=${v_vpc_name}_1
v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=$v_subnet1_tag --output text --query 'Subnets[*].SubnetId')
echo subnet_id=$v_subnet_id

# make the instance on 10.0.1.9
v_instance_id=$(aws ec2 run-instances --image $p_ami_id --key basic --security-group-ids $v_vpcbasicsg_id --placement AvailabilityZone=$v_deployzone --instance-type $v_sharedinstancetype --block-device-mapping $v_bdm --region $v_deployregion --subnet-id $v_subnet_id --private-ip-address 10.0.1.9 --associate-public-ip-address --output text --query 'Instances[*].InstanceId')
if [ -z "$v_instance_id" ]
then
  echo v_instance_id is null, exiting.
	exit
else
	echo v_instance_id=$v_instance_id
fi

# wait for it 9/11/2016 convert to use the wait command.  :)
echo "waiting for instance"
local v_wait_result=$(aws ec2 wait instance-running --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].State.Name')
if ! [ -z $v_wait_result ] ; then
  echo v_wait_result=$v_wait_result
fi


# get the new instance's public ip address
v_ip_address=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
echo v_ip_address=$v_ip_address

# wait for ssh to work
echo -n "waiting for ssh"
while ! ssh -i ../mycredentials/basic.pem -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address > /dev/null 2>&1 true; do
 echo -n . ; sleep 3;
done; echo " ssh ok"

# send required files
echo "transferring files"
scp -i ../mycredentials/basic.pem ./shared/secure.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/basic.pem ./shared/check.sh ec2-user@$v_ip_address:
scp -i ../mycredentials/basic.pem ./shared/sshd_config ec2-user@$v_ip_address:
scp -i ../mycredentials/basic.pem ./shared/yumupdate.sh ec2-user@$v_ip_address:
echo "transferred files"

# run the secure script
echo "running secure.sh"
ssh -i ../mycredentials/basic.pem -t ec2-user@$v_ip_address sudo ./secure.sh
echo "finished secure.sh"

# now ssh is on 38142
echo "adding port 38142 to sg"
aws ec2 authorize-security-group-ingress --group-id $v_vpcbasicsg_id --protocol tcp --port 38142 --cidr $v_myip/32
echo "sg updated"

# instance is rebooting, wait for ssh again
echo -n "waiting for ssh"
while ! ssh -i ../mycredentials/basic.pem -p 38142 -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address > /dev/null 2>&1 true; do
 echo -n . ; sleep 3;
done; echo " ssh ok"

# run a check script, you should check this output
echo "running check.sh"
ssh -i ../mycredentials/basic.pem -p 38142 -t -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$v_ip_address sudo ./check.sh
echo "finished check.sh"

# make the image
echo "creating image"
v_image_id=$(aws ec2 create-image --instance-id $v_instance_id --name "$p_template_name" --description "${p_template_name} AMI" --output text --query 'ImageId')
echo v_image_id=$v_image_id

# wait for the image

echo "waiting for image"
local v_wait_result=$(aws ec2 wait image-available --image-id $v_image_id --output text)
if ! [ -z $v_wait_result ] ; then
  echo v_wait_result=$v_wait_result
fi

# terminate the instance
aws ec2 terminate-instances --instance-ids $v_instance_id

# wait for termination
echo "waiting for instance termination"
v_wait_result=$(aws ec2 wait instance-terminated --instance-ids $v_instance_id --output text)
if ! [ -z $v_wait_result ] ; then
  echo v_wait_result=$v_wait_result
fi


# delete the key
drop_key_pair_p basic

# delete the security group
echo deleting security group
aws ec2 delete-security-group --group-id $v_vpcbasicsg_id

echo "done - Image made; Key, Security Group and Instance deleted"
}

if_exist_delete_template_p (){
	local p_procedure_name=$0
	local p_ami_name=$1

	# deregister image
	local v_ami_id=$(aws ec2 describe-images --filters "Name=name,Values=${p_ami_name}" --output text --query 'Images[*].ImageId')
	if [ -z "$v_ami_id" ]; then
	  echo $p_ami_name does not exist.
  else
		echo deregistering $p_ami_name
	  aws ec2 deregister-image --image-id $v_ami_id
  fi

}


validate_key_pair_f () {
	local p_procedure_name=$0
	local p_key_name=$1

	local v_file_fingerprint=$(openssl pkcs8 -in ../mycredentials/${p_key_name}.pem -inform PEM -outform DER -topk8 -nocrypt | openssl sha1 -c)
	local v_aws_fingerprint=$(aws ec2 describe-key-pairs --key-names test1 --output text --query 'KeyPairs[*].KeyFingerprint')

	if [ "$v_file_fingerprint" = "$v_aws_fingerprint" ]
	then
	  echo 1
  else
	  echo 0
		echo
  fi
}

drop_key_pair_p (){
	local p_procedure_name=$0
	local p_key_name=$1
	if [ -e "../mycredentials/$p_key_name.pem" ]
	then
	  echo removing $p_key_name.pem
		rm ../mycredentials/$p_key_name.pem
	else
		echo pem file does NOT exist
	fi

	local v_exists=$(aws ec2 describe-key-pairs --key-names $p_key_name --output text --query 'KeyPairs[*].KeyName' 2>/dev/null)
	if [ "$v_exists" = "$p_key_name" ]
	then
	echo aws key $p_key_name exists, deleting it.
	aws ec2 delete-key-pair --key-name $p_key_name
  else
	echo aws key $p_key_name does not exist
	fi
}

drop_all_key_pairs_p (){
	local p_procedure_name=$0

  v_key_pair_list=$(aws ec2 describe-key-pairs --output text --query KeyPairs[].[KeyName])
  if [ -z "$v_key_pair_list" ]; then
		for v_key_name in $v_key_pair_list ; do
		   aws ec2 delete-key-pair --key-name $v_key_name
			 if [ -e ../mycreditials/$v_key_name.pem ]; then
	        echo removing ../mycreditials/$v_key_name.pem
					rm ../mycreditials/$v_key_name.pem
				else
					echo ../mycreditials/$v_key_name.pem did not exist.
			 fi
    done
  fi
}

create_key_pair_p (){
local p_procedure_name=$0
local p_key_name=$1
# Bernie Pruss - This procedure checks that a key pair with p_key_name exits.
#both on AWS and in the file system.
# test cases:  neither exists, both exist, pem not server, server not pem.
local v_exists=$(aws ec2 describe-key-pairs --key-names $p_key_name --output text --query 'KeyPairs[*].KeyName' 2>/dev/null)
if [ "$v_exists" = "$p_key_name" ]
then
#echo v_exists=$v_exists
local v_aws_key=1
# echo "key $p_key_name already exists on server, checking file "
else
 #echo "key admin not found - proceeding"
 local v_aws_key=0
fi

if [ -e "../mycredentials/$p_key_name.pem" ]
then
  #echo pem file exists
	local v_pem_file=1
else
	#echo pem file does NOT exist
	local v_pem_file=0
fi

if [ $v_aws_key = 1 -a $v_pem_file = 1 ]
then
  echo both aws and file $p_key_name exist.
else
  #echo p_key_name=$p_key_name
  #echo v_aws_key:$v_aws_key
  #echo v_pem_file:$v_pem_file
  #echo one or both missing creating/recreating keypair $p_key_name
	if [ $v_aws_key = 1 ]
	then
	 #echo aws key $p_key_name exists \(but not the file\) deleting aws key.
	 aws ec2 delete-key-pair --key-name $p_key_name
  fi
	#aws ec2 delete-key-pair --key-name $p_key_name
  aws ec2 create-key-pair --key-name $p_key_name --query 'KeyMaterial' --output text > ../mycredentials/$p_key_name.pem
  chmod 600 ../mycredentials/$p_key_name.pem
fi

}

get_external_ip_address_f(){
local p_procedure_name=$0
# find an unused eip or make one eip? External IP?
v_eips=$(aws ec2 describe-addresses --output text --query 'Addresses[*].PublicIp')
for v_eip in $v_eips
do
 local v_eip_instance_id=$(aws ec2 describe-addresses --filters Name=public-ip,Values=$v_eip --output text --query 'Addresses[*].InstanceId')
 if test -z "$v_eip_instance_id"; then
  local v_use_eip=$v_eip
  #	found free eip $v_use_eip
	break
 fi
done
# check if eip found, otherwise make one
if test -z "$v_use_eip" ; then
    local v_use_eip=$(aws ec2 allocate-address --domain vpc --output text --query 'PublicIp')
fi

local v_eip_alloc_id=$(aws ec2 describe-addresses --filters Name=public-ip,Values=$v_use_eip --output text --query 'Addresses[*].AllocationId')
#echo v_eip_alloc_id=$v_eip_alloc_id
echo $v_eip_alloc_id
}

release_unused_ip_address_f(){
local p_procedure_name=$0
# find an unused eip or make one eip? External IP?
v_eips=$(aws ec2 describe-addresses --output text --query 'Addresses[*].PublicIp')
for v_eip in $v_eips
do
 local v_eip_instance_id=$(aws ec2 describe-addresses --filters Name=public-ip,Values=$v_eip --output text --query 'Addresses[*].InstanceId')
 if test -z "$v_eip_instance_id"; then
  # unused if instance id is null so we get the alloc id and release
	local v_eip_alloc_id=$(aws ec2 describe-addresses --filters Name=public-ip,Values=$v_eip --output text --query 'Addresses[*].AllocationId')
  echo releasing unused $v_eip / $v_eip_alloc_id
  aws ec2 release-address --allocation-id $v_eip_alloc_id
 fi
done
}

make_server_from_ami_p (){
local p_procedure_name=$0
local p_ami_name=$1
local p_tgt_name=$2
local p_tgt_size=$3
local p_private_ip=$4

echo ami template name=$p_ami_name
echo target name=$p_tgt_name
echo target instance size=$p_tgt_size
echo p_private_ip=$p_private_ip

#check first to see if a server with this name is already running then return if it is.
local v_instance_id=$(aws ec2 describe-instances --output text --filters Name=tag:Name,Values=$p_tgt_name Name=instance-state-name,Values=running --query 'Reservations[*].Instances[*].InstanceId')
if ! [ -z "$v_instance_id" ] ; then
  echo $p_tgt_name aready running with v_instance_id=$v_instance_id
  return
fi

# make keypair
 create_key_pair_p $p_tgt_name

 # make security group
 local v_vpc_id=$(get_vpc_id_f $v_vpc_name)
 echo v_vpc_id=$v_vpc_id
 # Make it's own security group.  What do I think of that?
 local v_sg_id=$(aws ec2 create-security-group --group-name ${p_tgt_name}sg --description "${p_tgt_name} security group" --vpc-id $v_vpc_id --output text --query 'GroupId')
 echo v_sg_id=$v_sg_id
 # tag it
 aws ec2 create-tags --resources $v_sg_id --tags Key=sgname,Value=${p_tgt_name}sg
 # get its id
 local v_vpcadminsg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=${p_tgt_name}sg --output text --query 'SecurityGroups[*].GroupId')
 echo v_vpcadminsg_id=$v_vpcadminsg_id
 # allow ssh
 aws ec2 authorize-security-group-ingress --group-id $v_vpcadminsg_id --protocol tcp --port 38142 --cidr $v_myip/32
 #echo "${p_tgt_name}sg made"

 # get the main subnet
 local v_subnet1_tag=${v_vpc_name}_1
 local v_subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$v_vpc_id --filters Name=tag-key,Values=subnet --filters Name=tag-value,Values=$v_subnet1_tag --output text --query 'Subnets[*].SubnetId')
 # echo v_subnet_id=$v_subnet_id

 # get the shared image id
 local v_ami_id=$(aws ec2 describe-images --filters "Name=name,Values=${p_ami_name}" --output text --query 'Images[*].ImageId')
 # echo v_ami_id=$v_ami_id

 # make the instance
 local v_instance_id=$(aws ec2 run-instances --image $v_ami_id --placement AvailabilityZone=$v_deployzone --key $p_tgt_name --security-group-ids $v_vpcadminsg_id --instance-type $v_admininstancetype --block-device-mapping $v_bdm --region $v_deployregion --subnet-id $v_subnet_id --private-ip-address $p_private_ip --output text --query 'Instances[*].InstanceId')
 # echo v_instance_id=$v_instance_id
 echo waiting for $v_instance_id
 local v_wait_return=$(aws ec2 wait instance-running --instance-ids $v_instance_id --output text)
 if ! [ -z $v_wait_result ] ; then
   echo v_wait_result=$v_wait_result
 fi

 # name the instane
 aws ec2 create-tags --resources $v_instance_id --tags Key=Name,Value=$p_tgt_name

 local v_ip_alloc_id=$(get_external_ip_address_f)
 aws ec2 associate-address --instance-id $v_instance_id --allocation-id $v_ip_alloc_id --output text

 # get adminhost private ip
 local v_host_private_ip=$(aws ec2 describe-instances --filters Name=key-name,Values=$p_tgt_name --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')
 #echo v_host_private_ip=$v_host_private_ip

 local v_ip_address=$(aws ec2 describe-instances --instance-ids $v_instance_id --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
 #echo v_ip_address=$v_ip_address

}

drop_server_p(){
local p_procedure_name=$0
local p_server_name=$1
if [ -z "$p_server_name" ]; then
  echo $p_procedure_name requires 1 parameter \"server_name\"
  return
fi

local v_instance_id=$(aws ec2 describe-instances --output text --filters Name=tag:Name,Values=$p_server_name Name=instance-state-name,Values=running --query 'Reservations[*].Instances[*].InstanceId')
if ! [ -z "$v_instance_id" ] ; then
  echo v_instance_id=$v_instance_id
  aws ec2 terminate-instances --instance-ids $v_instance_id
  echo Waiting for instance-terminated  $v_instance_id
  local v_wait_result=$(aws ec2 wait instance-terminated --filters Name=instance-id,Values=$v_instance_id --query 'Reservations[*].Instances[*].InstanceId')
  if ! [ -z $v_wait_result ] ; then
    echo v_wait_result=$v_wait_result
  fi
else
	echo $p_server_name is not runnning
fi
drop_key_pair_p $p_server_name

drop_security_group_p ${p_server_name}sg

release_unused_ip_address_f

}

drop_security_group_p(){
	local p_procedure_name=$0
 	local p_sg_name=$1
  # May not delete VPC security group by name must use ID.
  local v_sg_id=$(aws ec2 describe-security-groups --filters Name=tag-key,Values=sgname --filters Name=tag-value,Values=$p_sg_name --output text --query 'SecurityGroups[*].GroupId')

	if ! [ -z "$v_sg_id" ] ; then
	  echo delete security group $p_sg_name with v_sg_id=$v_sg_id
	  aws ec2 delete-security-group --group-id $p_sg_id
	else
		echo security group $p_sg_name does not exist.
	fi
}

drop_all_security_groups_p(){
local p_procedure_name=$0
	local v_security_group_ids=$(aws ec2 describe-security-groups --output text  --query 'SecurityGroups[?GroupName!=`default`].[GroupId]')
  if ! [ -z v_security_group_ids ] ; then
    for v_security_group_id in $v_security_group_ids ; do
		  echo delete security group v_security_group_id=$v_security_group_id
	    aws ec2 delete-security-group --group-id $v_security_group_id
	  done
  fi
}

drop_all_servers_p (){
	local p_procedure_name=$0
	local p_preface=$1

  local v_instance_ids=$(aws ec2 describe-instances --output text --filters Name=instance-state-name,Values=running --query 'Reservations[*].Instances[*].InstanceId')
  if ! [ -z $v_instance_ids ]; then
	  echo terminating instances: $v_instance_ids
	  aws ec2 terminate-instances --instance-ids $v_instance_ids
		echo waiting for all instances to be terminated
	  local v_wait_result=$(aws ec2 wait instance-terminated --query 'Reservations[*].Instances[*].InstanceId')
    if ! [ -z $v_wait_result ] ; then
      echo v_wait_result=$v_wait_result
    fi
  fi

  drop_all_security_groups_p

	drop_all_key_pairs_p

	release_unused_ip_address_f
}

clean_project_p(){
	local p_procedure_name=$0
  echo starting $p_procedure_name
  drop_all_servers_p
	if_exist_delete_template_p "$v_template_name"
	delete_vpc_subnets_p $v_vpc_name
	delete_igw_p $v_vpc_name $v_igw_name
	# learned that I don't need to delete the router. Just the igw and subnets?
	# delete_rtb_p $v_vpc_name
	delete_vpc_p $v_vpc_name $v_igw_name

	release_unused_ip_address_f

	echo finished $p_procedure_name
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
