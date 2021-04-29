# variables.tf
variable "access_key" {
   default = ""
}
variable "secret_key" {
   default = ""
}
variable "region" {
   default = "us-west-1"
}
variable "availabilityZone" {
   default = "us-west-1a"
}
variable "instanceType" {
   default = "t2.small"
}
variable "keyName" {
   default = "scytale-oidc"
}
variable "keyPath" {
   default = "scytale-oidc.pem"
}
variable "subnet" {
   default = "subnet-0a64c86d"
}
variable "securityGroups" {
   type = list
   default = [ "sg-dfd58db9" ]
}
variable "instanceName" {
   default = "scytale-oidc"
}
# ami-0121ef35996ede438 is ubuntu 16.04 available in us-west-1 region
# for the us-east-1b region. 
variable "amis" {
   default = {
     "us-west-1" = "ami-0121ef35996ede438"
   }
}

variable "domainName" {
   default = "oidc.spire-test.com"
}

variable "dnsZone" {
    default = "spire-test.com"
}

variable "elbName" {
    default = "oidc-elb"
}
