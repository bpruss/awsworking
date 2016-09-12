#!/bin/bash

source ../mycredentials/vars123.sh
set_vars_p $1
display_vars_p ALL

source aws_library.sh

v_vpc_id=$(create_vpc_f $v_vpc_name)
echo created v_vpc_id=$v_vpc_id

wait_for_vpc_p $v_vpc_name

v_igw_id=$(create_igw_f $v_igw_name )
echo v_igw_id=$v_igw_id

attach_igw_p $v_vpc_id $v_igw_id

# get the route table id for the vpc (we need it later)
v_rtb_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$v_vpc_id --output text --query 'RouteTables[*].RouteTableId')
echo v_rtb_id=$v_rtb_id

create_subnets_p $v_vpc_id $v_deployzone $v_deployzone2 $v_rtb_id $v_igw_id

#v_subnet_id1=$(get_subnet_id_f $v_vpc_id subnet 1)
#echo v_subnet_id1=$v_subnet_id1

#v_subnet_id2=$(get_subnet_id_f $v_vpc_id subnet 2)
#echo v_subnet_id2=$v_subnet_id2
