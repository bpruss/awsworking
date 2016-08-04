#!/bin/bash

echo starting make_vpc.sh
./make_vpc.sh

echo starting make_shared.sh
./make_shared.sh

echo starting make_rds.sh
./make_rds.sh

echo make_admin.sh 
./make_admin.sh
