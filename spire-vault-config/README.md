
# Execution Steps:

## 1. Clone the repository

        git clone <vault-integration with spire repo>


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
         
        time_sleep.wait_90_seconds: Creating...
        time_sleep.wait_90_seconds: Still creating... [10s elapsed]
        time_sleep.wait_90_seconds: Still creating... [20s elapsed]
        time_sleep.wait_90_seconds: Still creating... [30s elapsed]
        time_sleep.wait_90_seconds: Still creating... [40s elapsed]
        time_sleep.wait_90_seconds: Still creating... [50s elapsed]
        time_sleep.wait_90_seconds: Still creating... [1m0s elapsed]
        time_sleep.wait_90_seconds: Still creating... [1m10s elapsed]
        time_sleep.wait_90_seconds: Still creating... [1m20s elapsed]
        time_sleep.wait_90_seconds: Creation complete after 1m30s [id=2021-05-21T09:30:15Z]

        Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

        Outputs:

        instance_ip = "54.183.173.1"
   
 ## 6. SSH into the server
 
     ssh -i scytale-oidc.pem ubuntu@<IP address of the instance>


## 7.Healthcheck

    sudo -i
    spire-server healthcheck -registrationUDSPath /var/run/spire/sockets/server.sock 
    spire-agent healthcheck -socketPath /var/run/spire/sockets/agent.sock 

## 8.Validate Vault server status

   systemctl status vault

## 9.Run setup-vault.sh script

    Setup vault script registers vault with spire server and enables JWT on vault
    Read/Write operations are authenticated via oidc server

    /tmp# ./setup-vault.sh 
    This script must be run with trust domain as input

    Usage: ./setup-vault.sh <trust-domain> 

    Note: setup-vault.sh is copied to /tmp of vault server via terraform
     

