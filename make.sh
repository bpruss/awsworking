#!/bin/bash

echo starting make_vpc.sh
./make_vpc.sh

echo starting make_rds.sh
./make_rds.sh

echo starting make_shared.sh
./make_shared.sh

echo starting make_rds.sh - Just waites for rds to finish and sets endpoint.
./make_rds2.sh

echo make_admin.sh
./make_admin.sh

echo make_elb.sh
./make_elb.sh

for (( i=1; i<=$v_numwebs; i++ )) do
 echo $'\n\n*********************\n MAKING WEB\n*********************\n\n'
 . ./make_webphp.sh $i
 echo $'\n\n*********************\n MADE WEB\n*********************\n\n'
done
