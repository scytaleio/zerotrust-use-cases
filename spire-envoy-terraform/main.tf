module "aws-eks" {
  kubeconfig_path = "~/.kube"
  source = "../spire-eks/aws-eks/basic"
}

provider "aws" {
  region = "${module.aws-eks.region}"
}

data "aws_eks_cluster" "example" {
  name = "${module.aws-eks.eks_cluster_name}"
}

data "aws_eks_cluster_auth" "example" {
  name = "${module.aws-eks.eks_cluster_name}"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.example.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.example.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--region", "${module.aws-eks.region}", "--cluster-name", "${module.aws-eks.eks_cluster_name}"]
    command     = "aws"
  }
}

module "spire-server" {
  source = "../spire-eks/spire-server"
  depends_on = [module.aws-eks]
}

module "spire-agent" {
  source = "../spire-eks/spire-agent"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-server]
}

module "workloads-tcp" {
  source = "./modules/workloads-tcp"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-agent]
}

module "workloads-http" {
  source = "./modules/workloads-http"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-agent]
}


