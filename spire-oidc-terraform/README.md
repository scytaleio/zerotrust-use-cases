
# Introduction

This Terraform script will set up SPIRE with OIDC federation to AWS. 

It will set up a SPIRE server, then the SPIRE OIDC provider with its own ELB and identity mapping into AWS credentials.

Then a workload should be able to retrieve its JWT-SVID using the following commands, and use them to authenticate to the S3 API. 

Right now, you have to manually copy the certificate thumbprint from ACM into the OIDC identity mapping. You also have to copy the OIDC ARN into the AWS\_ROLE\_ARN variable manually.

# Commands

Healthcheck:

spire-server healthcheck -registrationUDSPath /var/run/spire/sockets/server.sock 
spire-agent healthcheck -socketPath /var/run/spire/sockets/agent.sock 

Workload registration:

spire-server entry create -spiffeID spiffe://oidc.spire-test.com/myworkload -parentID spiffe://oidc.spire-test.com/myagent -selector unix:uid:0 -registrationUDSPath /var/run/spire/sockets/server.sock

Fetch token:
```
spire-agent api fetch jwt -audience mys3 -socketPath     /run/spire/sockets/agent.sock | sed '2!d' | sed 's/[[:space:]]//g' > token
```

Download file from s3:
```
AWS_ROLE_ARN=arn:<OIDC-ROLE-ARN> AWS_WEB_IDENTITY_TOKEN_FILE=token aws s3 cp s3://scytale-oidc/scytale_object test.txt
```
