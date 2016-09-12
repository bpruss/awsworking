#!/bin/bash
source ./aws_library.sh
source ../mycredentials/vars123.sh

set_vars_p PRJ001

#display_vars_p ALL

#echo v_template_name=$v_template_name

#drop_server_p

#drop_server_p myadmin

#drop_server_p myadmin4
#drop_server_p myadmin3
#drop_server_p myadmin2
#drop_server_p myadmin

drop_all_servers_p

make_server_from_ami_p  "$v_template_name" myadmin 50 10.0.1.10
make_server_from_ami_p  "$v_template_name" myadmin2 50 10.0.1.11
make_server_from_ami_p  "$v_template_name" myadmin3 50 10.0.1.12
make_server_from_ami_p  "$v_template_name" myadmin4 50 10.0.1.13

drop_all_servers_p

# aws ec2 describe-instances --filters Name=key:Name,Values=myadmin --output text --query 'Reservations[*].Instances[*].InstanceId'
