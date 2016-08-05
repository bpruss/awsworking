#!/bin/bash

# load master vars into variables.
. ../mycredentials/vars.sh
set_vars_p

# deregister image
v_bslami_id=$(aws ec2 describe-images --filters 'Name=name,Values=Basic Secure Linux' --output text --query 'Images[*].ImageId')
echo v_bslami_id=$v_bslami_id
aws ec2 deregister-image --image-id $v_bslami_id
