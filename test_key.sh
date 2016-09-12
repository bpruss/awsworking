#!/bin/bash
source ./aws_library.sh
source ../mycredentials/vars123.sh

set_vars_p PRJ001

#display_vars_p ALL


drop_key_pair_p test1

validate_key_pair_f test1

create_key_pair_p test1

validate_key_pair_f test1

drop_key_pair_p test1

#check_key_exists_f test2

#check_key_exists_f test3

#check_key_exists_f test4
