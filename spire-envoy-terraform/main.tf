module "aws-eks" {
  source = "./modules/aws-eksi/basic"
}

module "spire-server" {
  source = "./modules/spire-server"
  depends_on = [module.aws-eks]
}

module "spire-agent" {
  source = "./modules/spire-agent"
  depends_on = [module.aws-eks, module.spire-server]
}

module "workloads-tcp" {
  source = "./modules/workloads-tcp"
  depends_on = [module.aws-eks, module.spire-server, module.spire-agent]
}

module "workloads-http" {
  source = "./modules/workloads-http"
  depends_on = [module.aws-eks, module.spire-server, module.spire-agent]
}

