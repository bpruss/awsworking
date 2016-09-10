#!/bin/bash

# Project PRJ001
# Build Network
# build Oracle RDS database instance
# Build template
# Build admin server


source ./aws_library.sh
source ../mycredentials/vars123.sh

set_vars_p PRJ001

display_vars_p ALL

delete_vpc_subnets_p $v_vpc_name

delete_igw_p $v_vpc_name $v_igw_name

# learned that I don't need to delete the router. Just the igw and subnets?
# delete_rtb_p $v_vpc_name

delete_vpc_p $v_vpc_name $v_igw_name
