# =============================================================================
# EXEMPLE TERRAFORM: Déploiement multi-applications avec Helm
# =============================================================================

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    # Ou pour EKS:
    # host                   = data.aws_eks_cluster.cluster.endpoint
    # cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    # token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "chart_path" {
  description = "Path to the generic Helm chart"
  type        = string
  default     = "../"  # Chemin vers le chart générique
}

# -----------------------------------------------------------------------------
# Namespace Kubernetes
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# EXEMPLE 1: API Backend
# -----------------------------------------------------------------------------
resource "helm_release" "api_backend" {
  name       = "api-backend"
  namespace  = kubernetes_namespace.app_namespace.metadata[0].name
  chart      = var.chart_path
  
  # Timeout et retry
  timeout         = 600
  cleanup_on_fail = true
  wait            = true
  
  # Values dynamiques depuis Terraform
  values = [
    yamlencode({
      replicaCount = 3
      
      image = {
        repository = "mycompany/api-backend"
        tag        = "v1.2.3"
        pullPolicy = "IfNotPresent"
      }
      
      serviceAccount = {
        create = true
        annotations = {
          "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789:role/api-backend-role"
        }
      }
      
      service = {
        enabled = true
        type    = "ClusterIP"
        ports = [
          {
            name       = "http"
            port       = 80
            targetPort = 8080
            protocol   = "TCP"
          }
        ]
      }
      
      ingress = {
        enabled   = true
        className = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
        }
        hosts = [
          {
            host = "api-${var.environment}.example.com"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                portName = "http"
              }
            ]
          }
        ]
        tls = [
          {
            secretName = "api-tls"
            hosts      = ["api-${var.environment}.example.com"]
          }
        ]
      }
      
      resources = {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      
      autoscaling = {
        enabled                        = true
        minReplicas                    = 3
        maxReplicas                    = 20
        targetCPUUtilizationPercentage = 70
      }
      
      env = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name = "DATABASE_HOST"
          valueFrom = {
            secretKeyRef = {
              name = "api-backend-db-credentials"
              key  = "host"
            }
          }
        }
      ]
      
      configMap = {
        enabled = true
        data = {
          "config.json" = jsonencode({
            features = {
              newUI        = true
              betaFeatures = var.environment != "production"
            }
            cache = {
              ttl = 3600
            }
          })
        }
      }
      
      secret = {
        enabled = true
        type    = "Opaque"
        data = {
          database-password = "supersecret123"
          api-key          = "abc123xyz"
        }
      }
      
      commonLabels = {
        environment = var.environment
        team        = "backend"
        managed-by  = "terraform"
      }
    })
  ]
  
  # Dépendances
  depends_on = [kubernetes_namespace.app_namespace]
}

# -----------------------------------------------------------------------------
# EXEMPLE 2: Frontend Application
# -----------------------------------------------------------------------------
resource "helm_release" "frontend" {
  name       = "frontend"
  namespace  = kubernetes_namespace.app_namespace.metadata[0].name
  chart      = var.chart_path
  
  timeout         = 600
  cleanup_on_fail = true
  wait            = true
  
  values = [
    yamlencode({
      replicaCount = 2
      
      image = {
        repository = "mycompany/frontend"
        tag        = "2.5.1"
        pullPolicy = "IfNotPresent"
      }
      
      service = {
        enabled = true
        type    = "ClusterIP"
        ports = [
          {
            name       = "http"
            port       = 80
            targetPort = 3000
            protocol   = "TCP"
          }
        ]
      }
      
      ingress = {
        enabled   = true
        className = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        hosts = [
          {
            host = "app-${var.environment}.example.com"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                portName = "http"
              }
            ]
          }
        ]
        tls = [
          {
            secretName = "frontend-tls"
            hosts      = ["app-${var.environment}.example.com"]
          }
        ]
      }
      
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      
      autoscaling = {
        enabled                        = true
        minReplicas                    = 2
        maxReplicas                    = 10
        targetCPUUtilizationPercentage = 80
      }
      
      env = [
        {
          name  = "REACT_APP_API_URL"
          value = "https://api-${var.environment}.example.com"
        },
        {
          name  = "REACT_APP_ENV"
          value = var.environment
        }
      ]
      
      configMap = {
        enabled = true
        data = {
          "env.js" = <<-EOT
            window.ENV = {
              API_URL: 'https://api-${var.environment}.example.com',
              ENVIRONMENT: '${var.environment}'
            };
          EOT
        }
      }
      
      commonLabels = {
        environment = var.environment
        team        = "frontend"
        managed-by  = "terraform"
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.app_namespace]
}

# -----------------------------------------------------------------------------
# EXEMPLE 3: Worker/Background Jobs
# -----------------------------------------------------------------------------
resource "helm_release" "worker" {
  name       = "worker"
  namespace  = kubernetes_namespace.app_namespace.metadata[0].name
  chart      = var.chart_path
  
  timeout         = 600
  cleanup_on_fail = true
  wait            = true
  
  values = [
    yamlencode({
      replicaCount = 5
      
      image = {
        repository = "mycompany/worker"
        tag        = "1.0.0"
        pullPolicy = "IfNotPresent"
      }
      
      # Pas de service pour un worker
      service = {
        enabled = false
      }
      
      # Pas d'ingress pour un worker
      ingress = {
        enabled = false
      }
      
      resources = {
        limits = {
          cpu    = "2000m"
          memory = "4Gi"
        }
        requests = {
          cpu    = "1000m"
          memory = "2Gi"
        }
      }
      
      autoscaling = {
        enabled                        = true
        minReplicas                    = 5
        maxReplicas                    = 50
        targetCPUUtilizationPercentage = 75
      }
      
      # Probes pour worker (exec au lieu de HTTP)
      livenessProbe = {
        enabled = true
        exec = {
          command = ["python", "/app/healthcheck.py"]
        }
        initialDelaySeconds = 60
        periodSeconds       = 30
      }
      
      readinessProbe = {
        enabled = true
        exec = {
          command = ["python", "/app/readiness.py"]
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
      }
      
      env = [
        {
          name  = "WORKER_TYPE"
          value = "celery"
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        },
        {
          name = "CELERY_BROKER_URL"
          valueFrom = {
            secretKeyRef = {
              name = "worker-credentials"
              key  = "broker-url"
            }
          }
        }
      ]
      
      secret = {
        enabled = true
        type    = "Opaque"
        data = {
          broker-url      = "redis://redis.example.com:6379/0"
          result-backend  = "redis://redis.example.com:6379/1"
        }
      }
      
      nodeSelector = {
        workload-type = "compute-intensive"
      }
      
      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "workers"
          effect   = "NoSchedule"
        }
      ]
      
      commonLabels = {
        environment = var.environment
        team        = "data"
        component   = "worker"
        managed-by  = "terraform"
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.app_namespace]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "api_backend_status" {
  description = "Status of API Backend deployment"
  value       = helm_release.api_backend.status
}

output "frontend_status" {
  description = "Status of Frontend deployment"
  value       = helm_release.frontend.status
}

output "worker_status" {
  description = "Status of Worker deployment"
  value       = helm_release.worker.status
}

output "api_backend_version" {
  description = "Deployed version of API Backend"
  value       = helm_release.api_backend.version
}
