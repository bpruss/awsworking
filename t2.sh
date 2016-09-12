#!/bin/bash

source ../mycredentials/vars123.sh
set_vars_p $1
display_vars_p ALL

source aws_library.sh

vpc_cascade_delete_p (){

v_vpc_id=$(get_vpc_id_f $v_vpc_name )
if [ -z "$v_vpc_id" ]
then
  echo vpc $v_vpc_name does not exist exiting
  exit
else
	echo Continueing to delete vpc $v_vpc_name with v_vpc_id=$v_vpc_id
fi

v_igw_id=$(get_igw_id_f $v_igw_name )
if [ -z "$v_igw_id" ]
then
  echo igw $v_igw_name not found
else
echo detatching v_igw_id=$v_igw_id from $v_vpc_id and deleting
  detach_igw_p $v_vpc_id $v_igw_id
	delete_igw_p $v_igw_id
fi

delete_vpc_subnets_p $v_vpc_id

delete_vpc_p $v_vpc_name
}

vpc_cascade_delete_p
