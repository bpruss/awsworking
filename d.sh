#!/bin/bash

v_now=$(date +"%m_%d_%Y_%H_%M_%S")

# echo v_now=$v_now
./delete.sh 2>&1 |tee logs/delete$v_now.log 

