#!/bin/bash

source aws_library.sh

#v_vpc_id=$(create_vpc_f TESTVPC)
#echo created v_vpc_id=$v_vpc_id

#wait_for_vpc_p TESTVPC

v_vpc_id=$(get_vpc_id_f TESTVPC )
echo v_vpc_id=$v_vpc_id

v_igw_id=$(get_igw_id_f testigw )
echo v_igw_id=$v_igw_id

detach_igw_p $v_vpc_id $v_igw_id

delete_vpc_p TESTVPC
