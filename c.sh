#!/bin/bash

v_now=$(date +"%m_%d_%Y_%H_%M_%S")

# echo v_now=$v_now
./make.sh 2>&1 |tee logs/deploy_$v_now.log 

