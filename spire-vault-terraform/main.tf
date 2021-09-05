module "aws-eks" {
  kubeconfig_path = "/tmp"
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

module "acm-certificate" {
  source = "../spire-eks/acm-certificate"
  region = "${module.aws-eks.region}"
  trust_domain = "scytale-oidc-vault-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.aws-eks]
}

module "spire-server-oidc" {
  source = "../spire-eks/spire-server-oidc"
  acm_certificate_arn = "${module.acm-certificate.acm_certificate_arn}"
  trust_domain = "scytale-oidc-vault-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.acm-certificate]
}

module "spire-agent" {
  source = "../spire-eks/spire-agent"
  trust_domain = "scytale-oidc-vault-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-server-oidc]
}

module "trust-domain" {
  source = "../spire-eks/trust-domain"
  acm_certificate_arn = "${module.acm-certificate.acm_certificate_arn}"
  region = "${module.aws-eks.region}"
  elb = "${module.spire-server-oidc.spire_oidc_lb}"
  elbname = "${module.spire-server-oidc.spire_oidc_lbname}"
  trust_domain = "scytale-oidc-vault-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-server-oidc]
}

module "vault-setup" {
  source = "./modules/vault-setup"
  trust_domain = "scytale-oidc-vault-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-agent]
}

module "vault-configure" {
  source = "./modules/vault-configure"
  trust_domain = "scytale-oidc-vault-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.trust-domain,module.vault-setup]
}

