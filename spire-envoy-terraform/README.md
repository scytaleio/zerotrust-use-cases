# spire_envoy_proxy
This is a demo of using SPIRE and Envoy to authenticate both sides of a MongoDB connection & simple web application.

This usecase includes envoy with tcp & http, it's creates EKS cluster & deploys tcp and http workloads using terraform.

# Diagram
![TCP Arch Diagram](/spire-envoy-terraform/images/spire-envoy-tcp-arch.png "TCP Workloads Architecture diagram").
![HTTP Arch Diagram](/spire-envoy-terraform/images/spire-envoy-http-arch.png "HTTP Workloads Architecture diagram").

## Introduction
This Terraform configuration deploys a Kubernetes cluster into AWS's managed Kubernetes service, EKS.

It uses the aws & kubernetes providers to create an entire Kubernetes cluster in EKS including required VMs, networks, and other constructs. Note that this creates an EKS service which only includes the agent node VMs onto which customers deploy their containerized applications.

This tutorial demonstrate how to configure SPIRE to provide service identity dynamically in the form of X.509 certificates that will be consumed by Envoy secret discovery service (SDS).

To illustrate X.509 authentication, we create a simple scenario with two services. One service will be the backend that is a simple nginx instance serving static data. On the other side, we run one instance of the `Symbank` demo banking application acting as the frontend service. The `Symbank` frontend service send HTTP requests to the nginx backend to get the user account details.

As shown in the HTTP Arch diagram, the frontend service connect to the backend service via an mTLS connection established by the Envoy instances that perform X.509 SVID authentication on each workload's behalf.

## Deployment flow

1. Creates EKS cluster
2. Creates spire namespace
3. Deploy's Spire-Server & Spire-Agent in spire namespace
4. Spire-node registration entry creation
5. Spire-agent registration entry creation
6. Deploy's envoy based tcp & http workloads in spire namespace
7. TCP Workloads registration entry creation
8. HTTP Workloads registration entry creation

## Deployment Prerequisites

1. Get AWS Security Keys.

## Deployment Steps
Execute the following commands to deploy your Kubernetes cluster to EKS & deploy applications.

1. Clone this repository to your machine by running `git clone https://github.com/scytaleio/zerotrust-use-cases.git`.
1. Change work directory to zerotrust-use-cases/spire-envoy-terraform
1. Set AWS Security Keys
1. (Optional) Set kubeconfig_path variable in main.tf under aws-eks module, defaults to ~/.kube
1. (Optional) Set waittime_for_cluster variable in main.tf under aws-eks module, defaults to 900secs. Waits time for kubernetes nodes to be in Ready state.
1. (Optional) Set kubeconfig variable in main.tf under spire-agent, workloads-tcp, workloads-http modules, defaults to ~/.kube/config.
1. (Optional) Set trust_domain variable in main.tf under spire-server, spire-agent, workloads-tcp, workloads-http modules, defaults to envoy.spire-test.com.
1. Run **terraform init**
1. Run **terraform plan**
1. Run **terraform apply**
1. If deployment is not successful please do troubleshoot the issues before proceeding further.

## Validation
Execute the following commands to validate the deployment.

1. Now that services are deployed and also registered in SPIRE, let's test the authorization that we've configured.
1. Run **export KUBECONFIG=/path/to/kubeconfig** replace /path/to/kubeconfig with actual path of kubeconfig which you can find in the results of **terraform apply** after **aws-eks module** execution is completed. By default kubeconfig will be stored under ~/.kube with eks cluster name as kubeconfig file name.
1. Run **kubectl get all -n spire** you should see successful deployment of spire server & agent along with workloads deployments.
1. Let's see how valid X.509 SVIDs allow for the display of associated data. To do this, we show that frontend service can talk to the backend service by getting the correct IP address and port for each one. To run these tests, we need to find the IP address and ports that make up the URLs to use for accessing the data. Run **kubectl get svc -n spire** extract **frontend** service LoadBalancer address EXTERNAL-IP column.
1. The frontend service will be available at the EXTERNAL-IP value and port 3000, which was configured for our container. Open your browser and navigate to the IP address shown for frontend in your environment, adding the port :3000. Once the page is loaded, you'll see the account details for user Jacob Marley.

## Component Version Information
This usecase is tested successfully using below mentioned releases of individual components.

| Name | Version |
|------|-------------|
| Terraform | 1.0.0 |
| Docker Container Engine | 19.3.13 |
| Kubernetes | 1.20.4 |
| Spire-Server | 0.12.1 |
| Spire-Agent | 0.12.1 |
| Envoy | envoy-alpine:v1.18.2 |
| Mongo Server | latest |
| Mongo Client | latest |
| Frontend (nginx) | latest |

## Cleanup
Execute the following steps from your workspace to delete your Kubernetes cluster and associated resources from EKS.

1. Change work directory to zerotrust-use-cases/spire-envoy-terraform
1. Run **terraform state list** to see the state status
1. Run **terraform destroy** to destroy the resources created

