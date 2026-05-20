# Helm Chart Générique

Chart Helm générique et réutilisable pour déployer plusieurs applications via Terraform.

## Structure

```
infra-templates/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── serviceaccount.yaml
```

## Utilisation avec Helm

```bash
# Valider
helm lint .

# Tester
helm template myapp . -f examples/values-api-backend.yaml

# Déployer
helm install myapp . -f my-values.yaml -n production
```

## Utilisation avec Terraform

```hcl
resource "helm_release" "myapp" {
  name      = "myapp"
  namespace = "production"
  chart     = "./infra-templates"
  
  values = [
    yamlencode({
      replicaCount = 3
      image = {
        repository = "mycompany/myapp"
        tag        = "v1.0.0"
      }
      service = {
        enabled = true
        ports = [{
          name       = "http"
          port       = 80
          targetPort = 8080
        }]
      }
    })
  ]
}
```

Voir `examples/terraform-example.tf` pour un exemple complet.
