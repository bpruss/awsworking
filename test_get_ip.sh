#!/bin/bash
source ./aws_library.sh
source ../mycredentials/vars123.sh

set_vars_p PRJ001

#display_vars_p ALL

# echo v_template_name=$v_template_name

#aws ec2 describe-addresses --filters Name=public-ip,Values=52.44.2.129 --output text --query 'Addresses[*].InstanceId'
#aws ec2 describe-addresses --filters Name=public-ip,Values=52.44.203.191 --output text --query 'Addresses[*].InstanceId'

echo before get external address
#aws ec2 describe-addresses
#get_external_ip_address_f
#aws ec2 describe-addresses
release_unused_ip_address_f
aws ec2 describe-addresses
