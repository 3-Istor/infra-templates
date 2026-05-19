# 📚 Exemples d'utilisation

Ce dossier contient des exemples de configuration pour différents types d'applications et environnements.

## 📁 Fichiers disponibles

### Par type d'application

| Fichier | Description | Use Case |
|---------|-------------|----------|
| `values-api-backend.yaml` | API Backend (Node.js) | API REST, GraphQL, microservices |
| `values-frontend.yaml` | Frontend (React/Vue/Angular) | SPA, applications web |
| `values-worker.yaml` | Worker/Background Jobs | Celery, Sidekiq, traitement asynchrone |

### Par environnement

| Fichier | Description | Caractéristiques |
|---------|-------------|------------------|
| `values-dev.yaml` | Développement | 1 replica, debug activé, resources minimales |
| `values-staging.yaml` | Staging | 2 replicas, configuration proche de prod |
| `values-production.yaml` | Production | HA, autoscaling, security hardening |

### Terraform

| Fichier | Description |
|---------|-------------|
| `terraform-example.tf` | Exemple complet d'intégration Terraform avec 3 applications |

## 🚀 Utilisation rapide

### 1. API Backend

```bash
# Tester le rendu
helm template api-backend ../ -f values-api-backend.yaml

# Installer
helm install api-backend ../ -f values-api-backend.yaml -n production --create-namespace

# Vérifier
kubectl get pods -n production -l app.kubernetes.io/instance=api-backend
```

### 2. Frontend

```bash
# Tester le rendu
helm template frontend ../ -f values-frontend.yaml

# Installer
helm install frontend ../ -f values-frontend.yaml -n production --create-namespace

# Vérifier
kubectl get ingress -n production
```

### 3. Worker

```bash
# Tester le rendu
helm template worker ../ -f values-worker.yaml

# Installer
helm install worker ../ -f values-worker.yaml -n production --create-namespace

# Vérifier les logs
kubectl logs -n production -l app.kubernetes.io/instance=worker --tail=50 -f
```

## 🌍 Déploiement multi-environnement

### Développement

```bash
helm install myapp-dev ../ -f values-dev.yaml -n dev --create-namespace
```

**Caractéristiques :**
- 1 replica
- Resources minimales
- Debug activé
- Pull policy: Always
- Pas d'autoscaling

### Staging

```bash
helm install myapp-staging ../ -f values-staging.yaml -n staging --create-namespace
```

**Caractéristiques :**
- 2 replicas
- Resources moyennes
- Configuration proche de prod
- Autoscaling limité (2-5 replicas)

### Production

```bash
helm install myapp-prod ../ -f values-production.yaml -n production --create-namespace
```

**Caractéristiques :**
- 5+ replicas
- HA (High Availability)
- Autoscaling agressif (5-50 replicas)
- Security hardening
- Monitoring activé
- Pod anti-affinity

## 🔧 Terraform

### Initialisation

```bash
cd examples
terraform init
```

### Variables

Créer un fichier `terraform.tfvars` :

```hcl
environment = "production"
namespace   = "apps"
chart_path  = "../"
```

### Déploiement

```bash
# Plan
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy
```

### Exemple de déploiement multi-apps

Le fichier `terraform-example.tf` déploie 3 applications :
1. **API Backend** - API REST avec autoscaling
2. **Frontend** - Application React
3. **Worker** - Jobs Celery

```bash
terraform apply
```

Cela créera :
- 3 Helm releases
- 1 namespace Kubernetes
- Tous les services, ingress, configmaps, secrets

## 📝 Personnalisation

### Créer votre propre values.yaml

```yaml
# my-custom-values.yaml
replicaCount: 3

image:
  repository: mycompany/myapp
  tag: "1.0.0"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 8080

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
          portName: http

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

env:
  - name: APP_ENV
    value: "production"
  - name: LOG_LEVEL
    value: "info"

configMap:
  enabled: true
  data:
    config.json: |
      {
        "feature": "enabled"
      }

secret:
  enabled: true
  type: Opaque
  data:
    api-key: "your-secret-key"

commonLabels:
  environment: production
  team: platform
```

### Utiliser avec Terraform

```hcl
resource "helm_release" "myapp" {
  name      = "myapp"
  namespace = "production"
  chart     = "../"
  
  values = [
    file("my-custom-values.yaml")
  ]
  
  # Ou avec yamlencode pour des valeurs dynamiques
  values = [
    yamlencode({
      image = {
        repository = "mycompany/myapp"
        tag        = var.app_version
      }
      env = [
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.endpoint
        }
      ]
    })
  ]
}
```

## 🔍 Debugging

### Voir le rendu des templates

```bash
helm template myapp ../ -f values-api-backend.yaml > rendered.yaml
cat rendered.yaml
```

### Dry-run

```bash
helm install myapp ../ -f values-api-backend.yaml --dry-run --debug
```

### Valider le chart

```bash
cd ..
helm lint . -f examples/values-api-backend.yaml
```

## 📊 Comparaison des configurations

| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| Replicas | 1 | 2 | 5 |
| Autoscaling | ❌ | ✅ (2-5) | ✅ (5-50) |
| Resources | Minimal | Medium | High |
| Ingress TLS | Staging cert | Prod cert | Prod cert |
| Security Context | ❌ | ⚠️ | ✅ |
| Pod Anti-Affinity | ❌ | ❌ | ✅ |
| Monitoring | ❌ | ⚠️ | ✅ |
| Startup Probe | ❌ | ❌ | ✅ |

## 🎯 Cas d'usage spécifiques

### Application avec base de données

```yaml
env:
  - name: DATABASE_HOST
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: host
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: password

secret:
  enabled: true
  type: Opaque
  data:
    host: "postgres.example.com"
    password: "supersecret"
```

### Application avec Redis

```yaml
env:
  - name: REDIS_URL
    valueFrom:
      secretKeyRef:
        name: redis-credentials
        key: url

secret:
  enabled: true
  type: Opaque
  data:
    url: "redis://redis.example.com:6379/0"
```

### Application avec volumes persistants

```yaml
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: myapp-data

volumeMounts:
  - name: data
    mountPath: /data
```

### Application avec IAM role (AWS EKS)

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/myapp-role
```

## 📞 Support

Pour toute question sur les exemples :
- Consulter le [README principal](../README.md)
- Ouvrir une issue sur GitHub
- Contacter l'équipe DevOps

## 🔗 Ressources

- [Documentation Helm](https://helm.sh/docs/)
- [Best Practices Kubernetes](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
