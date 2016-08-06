#!/usr/bin/expect
# used when we set up boxes to change the password for ec2-user
spawn passwd ec2-user
expect "New password:"
send "qBOO4LPS0zWPiMkqXRvVfHmggQcezWypvuX5rgvPIesO\n";
expect "new password:"
send "qBOO4LPS0zWPiMkqXRvVfHmggQcezWypvuX5rgvPIesO\n";
interact
