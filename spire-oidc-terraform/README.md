# Architecture Diagram

  

# Execution Steps:

## 1. Clone the repository

        git clone https://github.com/Kathiresan1201/spire-oidc.git

## 2. Setup the Environment variables

        Setup the below environment variables to access AWS Services API endpoints
    
        * export AWS_ACCESS_KEY_ID="accesskey"
        * export AWS_SECRET_ACCESS_KEY="secretkey"


## 3. Download a key-pair from AWS console and store it locally
        * Goto AWS console 
        * Search to EC2 
        * Click on Key Pairs under Network and Security
        * Click on Create Key Pair from top right corner
        * Give a name for the key pair and download it
        * Move the .pem or .ppk file to spire-oidc directory(This example uses scytale-oidc.pem file)

## 4. Update variables.json file 

           Variable                |  Default value         | Notes
    -------------------------------|------------------------|------------------------------------------
    Region                         | us-west-1              |
    Availability Zone              | us-west-1a             |
    instanceType                   | t2.small               |
    subnet                         | subnet-0a64c86d        | default subnet available in VPC
    SecurityGroup                  | sg-dfd58db9            | default SG available in VPC(ports 443 should be accessible from public since ELB associated with it)
    domainName                     | oidc.spire-test.com    |
    dnsZone                        | spire-test.com         | point to DNSzone available in AWS account
    keyName                        | scytale-oidc           | update with name of the pem file downloaded in step 3
    keyPath                        | scytale-oidc.pem       | update the path in whcih pem file is kept(default is set to spire-oidc directory)
    amis                           | ami-0121ef35996ede438  | update the AMI available based on the region selected,default value is for ubuntu 16.04
    
    
## 5. Execute the script
      
      run the below command to validate the changes
         
         terraform plan
         
       output will look something like this
         
        # time_sleep.wait_90_seconds will be created
        + resource "time_sleep" "wait_90_seconds" {
          + create_duration = "90s"
          + id              = (known after apply)
          }

    Plan: 13 to add, 0 to change, 0 to destroy.
      
      Once plan is verified run the below command to create aws resoures
      
          terraform apply --auto-approve
       
      wait for about 15-20 mins for the execution to complete
      
      Output will look something like this
      
          Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

          Outputs:

          instance_ip = "13.57.57.23"
      
   
 ## 6. SSH into the server
 
     ssh -i scytale-oidc.pem ubuntu@<IP address of the instance>


## 7.Healthcheck

    sudo -i
    spire-server healthcheck -registrationUDSPath /var/run/spire/sockets/server.sock 
    spire-agent healthcheck -socketPath /var/run/spire/sockets/agent.sock 

## 8.Workload registration

     spire-server entry create -spiffeID spiffe://oidc.spire-test.com/myworkload -parentID spiffe://oidc.spire-test.com/myagent -selector unix:uid:0 \
     -registrationUDSPath /var/run/spire/sockets/server.sock

## 9.Fetch token

    spire-agent api fetch jwt -audience mys3 -socketPath     /run/spire/sockets/agent.sock | sed '2!d' | sed 's/[[:space:]]//g' > token

## 10.Download file from s3

    Fetch the OIDC ROLE ARN from AWS console
     * Go to IAM
     * Click on Roles
     * Search for scytale-oidc (name of the role)
     * Copy the Role ARN

    AWS_ROLE_ARN=<OIDC-ROLE-ARN> AWS_WEB_IDENTITY_TOKEN_FILE=token aws s3 cp s3://scytale-oidc/scytale_object test.txt
    
    
    
    
