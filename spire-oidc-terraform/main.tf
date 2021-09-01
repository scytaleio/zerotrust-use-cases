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
  trust_domain = "scytale-oidc-aws-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.aws-eks]
}

module "spire-server-oidc" {
  source = "../spire-eks/spire-server-oidc"
  acm_certificate_arn = "${module.acm-certificate.acm_certificate_arn}"
  trust_domain = "scytale-oidc-aws-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.aws-eks]
}

module "spire-agent" {
  source = "../spire-eks/spire-agent"
  trust_domain = "scytale-oidc-aws-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-server-oidc]
}

module "trust-domain" {
  source = "../spire-eks/trust-domain"
  acm_certificate_arn = "${module.acm-certificate.acm_certificate_arn}"
  region = "${module.aws-eks.region}"
  elb = "${module.spire-server-oidc.spire_oidc_lb}"
  elbname = "${module.spire-server-oidc.spire_oidc_lbname}"
  trust_domain = "scytale-oidc-aws-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.spire-server-oidc]
}

module "oidc-and-s3" {
  source = "./modules/oidc-and-s3"
  region = "${module.aws-eks.region}"
  trust_domain = "scytale-oidc-aws-tf.spire-test.com"
  depends_on = [module.trust-domain]
}

module "test-s3-access" {
  source = "./modules/test-s3-access"
  oidc_provider_arn = "${module.oidc-and-s3.oidc_provider_arn}"
  oidc_role_arn = "${module.oidc-and-s3.oidc_role_arn}"
  s3_bucket_name = "${module.oidc-and-s3.s3_bucket_name}"
  trust_domain = "scytale-oidc-aws-tf.spire-test.com"
  kubeconfig = "${module.aws-eks.kubeconfig_path}/${module.aws-eks.eks_cluster_name}"
  depends_on = [module.oidc-and-s3]
}

