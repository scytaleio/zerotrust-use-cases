variable "region" {
  default = "us-east-2"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = [
    "777777777777",
    "888888888888",
  ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      rolearn  = "arn:aws:iam::xxxxxxxxxx:user/prasad"
      username = "prasad"
      groups   = ["system:masters"]
    },
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      userarn  = "arn:aws:iam::xxxxxxxxxx:user/prasad"
      username = "prasad"
      groups   = ["system:masters"]
    }
  ]
}

variable "kubeconfig_path" {
  description = "Kubeconfig path"
  type = string
  default = "~/.kube/"
}

variable "waittime_for_cluster" {
  description = "Wait time for cluster to be up & running. Default 900s"
  type = string
  default = "900s"
}


