# spire_oidc_aws
This is a demo of using SPIRE and OIDC to authenticate workloads on Kubernetes to AWS S3
This usecase creates EKS cluster, S3 bucket, OIDC-Provider, IAM roles & policies in AWS using terraform.

# Diagram
![OIDC AWS Authentication Arch Diagram](/spire-oidc-terraform/images/spire-oidc-aws-arch.png "OIDC AWS Authentication Architecture diagram").

## Introduction
This Terraform configuration deploys a Kubernetes cluster into AWS's managed Kubernetes service, EKS.

It uses the aws & kubernetes providers to create an entire Kubernetes cluster in EKS including required VMs, networks, and other constructs. Note that this creates an EKS service which only includes the agent node VMs onto which customers deploy their containerized applications.

This tutorial demonstrate how a SPIRE identified workload can authenticate to Amazon AWS APIs, assume an AWS IAM role, and retrieve data from an AWS S3 bucket

To illustrate data retrieval from AWS S3 bucket, we created a simple scenario with client application pod. We will create SPIFFE registration entry for client application workload, then fetch jwt token. And then We will try to access file in s3 bucket using jwt token.

As shown in the Arch diagram, AWS CLI try to access AWS S3 bucket from client application pod using SPIRE authentication without configuring AWS IAM credentials.

## Deployment flow

1. Creates EKS cluster
2. Creates spire namespace
3. Deploy's Spire-Server along side OIDC provider application & Spire-Agent in spire namespace
4. Spire-node registration entry creation
5. Spire-agent registration entry creation
7. Create the required DNS A record to point to the OIDC Discovery document endpoint
8. Create a sample AWS identity provider, policy, role, and S3 bucket
9. Test access to the S3 bucket

## Deployment Prerequisites

1. Get & Set AWS Security Keys to access AWS Services API endpoints, like below.

        export AWS_ACCESS_KEY_ID="<AccessKey>"
        export AWS_SECRET_ACCESS_KEY="<SecretKey>"

## Deployment Steps
Execute the following commands to deploy your Kubernetes cluster to EKS & deploy applications.

1. Clone this repository to your machine by running `git clone https://github.com/scytaleio/zerotrust-use-cases.git`.
1. Change work directory to zerotrust-use-cases/spire-oidc-terraform
1. Make sure you have set AWS Security Keys
1. (Optional) Set kubeconfig_path variable in main.tf under aws-eks module, defaults to ~/.kube
1. (Optional) Set waittime_for_cluster variable in main.tf under aws-eks module, defaults to 900secs. Wait time for kubernetes nodes to be in Ready state.
1. (Optional) Set kubeconfig variable in main.tf under spire-agent, workloads-tcp, workloads-http modules, defaults to ~/.kube/config.
1. (Optional) Set trust_domain variable in main.tf under spire-server, spire-agent, workloads-tcp, workloads-http modules, defaults to envoy.spire-test.com.
1. (Required) Set acm_certificate_arn variable in main.tf under spire-server-oidc, trust-domain modules. ARN of acm certificate. By default automatically read from acm-certificate module.
1. (Required) Set elb variable in main.tf under trust-domain module. An spire oidc-discovery service Loadbalancer FQDN. By default automatically read from spire-server-oidc module.
1. (Required) Set elbName variable in main.tf under trust-domain module. An spire oidc-discovery service Loadbalancer name. By default automatically read from spire-server-oidc module.
1. Run **terraform init**
1. Run **terraform plan**
1. Run **terraform apply**
1. If deployment is not successful please do troubleshoot the issues before proceeding further. Refer to Trubleshooting steps

## Verification
You must following message after you have executed **terraform apply** in deployment steps

        Successfully accessed test.txt file from s3 bucket

## Component Version Information
This usecase is tested successfully using below mentioned releases of individual components.

| Name | Version |
|------|-------------|
| Terraform | 1.0.0 |
| Docker Container Engine | 19.3.13 |
| Kubernetes | 1.20.4 |
| Spire-Server | 0.12.1 |
| Spire-Agent | 0.12.1 |

## Troubleshoot
1. If you experience below mentioned error, please set **KUBECONFIG** environment variable and rerun **terrform apply**

        module.aws-eks.null_resource.aws_eks_kubeconfig (local-exec): Added new context arn:aws:eks:us-east-2:529024819027:cluster/spire-eks-48lqlDPV to /tmp/spire-eks-48lqlDPV
        module.aws-eks.null_resource.aws_eks_kubeconfig: Creation complete after 0s [id=2004234058031813821]
        ╷
        │ Error: Post "http://localhost/api/v1/namespaces/kube-system/configmaps": dial tcp 127.0.0.1:80: connect: connection refused
        │ 
        │   with module.aws-eks.module.eks.kubernetes_config_map.aws_auth[0],
        │   on ../spire-eks/aws-eks/aws_auth.tf line 63, in resource "kubernetes_config_map" "aws_auth":
        │   63: resource "kubernetes_config_map" "aws_auth" {
        │ 
        ╵

## Cleanup
Execute the following steps from your workspace to delete your Kubernetes cluster and associated resources from EKS.

1. Change work directory to zerotrust-use-cases/spire-envoy-terraform
1. Run **terraform state list** to see the state status
1. Run **terraform destroy** to destroy the resources created

