terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../deploy-cluster/terraform.tfstate"
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_deployment" "wc" {
  metadata {
    name = "scalable-word-count"
    labels = {
      App = "ScalableWordCount"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "ScalableWordCount"
      }
    }
    template {
      metadata {
        labels = {
          App = "ScalableWordCount"
        }
      }
      spec {
        container {
          image = "zsinx6/word-count:v1"
          name  = "word-count"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wc" {
  metadata {
    name = "wc"
  }
  spec {
    selector = {
      App = kubernetes_deployment.wc.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

output "lb_ip" {
  value = kubernetes_service.wc.status.0.load_balancer.0.ingress.0.hostname
}
