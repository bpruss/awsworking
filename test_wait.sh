#!/bin/bash
source ./aws_library.sh
source ../mycredentials/vars123.sh

set_vars_p PRJ001

#display_vars_p ALL

clean_project_p

make_vpc_f $v_vpc_name $v_igw_name
make_shared_template_p $v_baseami "$v_template_name"
