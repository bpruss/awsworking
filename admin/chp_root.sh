#!/usr/bin/expect
# used when we set up boxes to change the password for root
spawn passwd root
expect "New password:"
send "H0RWEf5L0fo81vU02c6VmS4n2LA5DHwSChu053hcHbZY\n";
expect "new password:"
send "H0RWEf5L0fo81vU02c6VmS4n2LA5DHwSChu053hcHbZY\n";
interact
