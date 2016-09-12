# awsworking
This repository is for code I am setting up to take what I am learning about scripting AWS and put it to use for myself and for Two Rivers Consulting.  

I have been studying the scripts and book called AWS Scripted by Christian Cerri and intend to take what I am learning and rewrite it to do the following:
1. Set up a basic secure network on AWS.
2. Set up a secure server on AWS.
3. Save an Amazon Machine Image (ami) of that secure server.
4. Set up an Amazon git source code repository.
5. Move some code to the repo.
6. Set up each of the following database types and load some data.  
   a. Oracle
   b. Microsoft SQL server
   c. My SQL

As part of this exercise I intend to:
1. Continue to learn how to use git hub in a safe and secure way.
2. Find and familiarize myself with the appropriate references for the AWS CLI.
3. Document the above for myself.  
4. Consider if I want to write some articles for my blog or other venues.


Some todo's
1. Create a procedure to check for existence of both the key file and the key on AWS.
Existing scripts sometimes check for file exits and sometimes check for key exists on AWS.
Should be consistent and check for both. Done.

2. Change drop subnets to drop all subnets associated with a vpc. Done.

3. Change wait for to use the wait command syntax. Done.
	a. Change the wait command syntax to test for time out and report it and exit. 
