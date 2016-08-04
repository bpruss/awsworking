#!/bin/bash

echo starting delete_admin.sh
./delete_admin.sh

echo starting delete_rds.sh
./delete_rds.sh

echo starting delete_shared.sh
./delete_shared.sh

echo starting delete_vpc.sh
./delete_vpc.sh
