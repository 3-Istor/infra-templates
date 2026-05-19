# 🚀 Generic Helm Chart for Kubernetes

Un Helm Chart générique et réutilisable pour déployer plusieurs applications Kubernetes via Terraform.

## 📋 Table des matières

- [Caractéristiques](#caractéristiques)
- [Structure du projet](#structure-du-projet)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Configuration](#configuration)
- [Exemples](#exemples)
- [Terraform Integration](#terraform-integration)
- [Bonnes pratiques](#bonnes-pratiques)

## ✨ Caractéristiques

### Composants Kubernetes supportés
- ✅ **Deployment** - Déploiement d'applications avec rolling updates
- ✅ **Service** - Exposition des applications (ClusterIP, NodePort, LoadBalancer)
- ✅ **ConfigMap** - Configuration externalisée
- ✅ **Secret** - Gestion sécurisée des secrets
- ✅ **Ingress** - Exposition HTTP/HTTPS avec TLS
- ✅ **HorizontalPodAutoscaler** - Autoscaling basé sur CPU/Memory
- ✅ **ServiceAccount** - Identité pour les pods (IAM roles, etc.)

### Fonctionnalités avancées
- 🔄 **Checksum automatique** - Redémarrage des pods lors de changements ConfigMap/Secret
- 🎯 **Multi-ports** - Support de plusieurs ports par service
- 🏷️ **Labels & Annotations** - Personnalisables à tous les niveaux
- 🔍 **Health checks** - Liveness, Readiness et Startup probes
- 📊 **Resources** - Requests et limits configurables
- 🎛️ **Scheduling** - NodeSelector, Tolerations, Affinity
- 🔐 **Security** - SecurityContext, PodSecurityContext
- 📦 **Volumes** - Support complet des volumes et volumeMounts
- ♻️ **Lifecycle hooks** - PreStop, PostStart
- 🌍 **Multi-environnement** - Dev, Staging, Production

## 📁 Structure du projet

```
infra-templates/
├── Chart.yaml                      # Métadonnées du chart
├── values.yaml                     # Valeurs par défaut
├── templates/
│   ├── _helpers.tpl               # Fonctions helper réutilisables
│   ├── deployment.yaml            # Template Deployment
│   ├── service.yaml               # Template Service
│   ├── configmap.yaml             # Template ConfigMap
│   ├── secret.yaml                # Template Secret
│   ├── ingress.yaml               # Template Ingress
│   ├── hpa.yaml                   # Template HorizontalPodAutoscaler
│   ├── serviceaccount.yaml        # Template ServiceAccount
│   └── NOTES.txt                  # Instructions post-installation
├── examples/
│   ├── terraform-example.tf       # Exemple Terraform complet
│   ├── values-api-backend.yaml    # Exemple API Backend
│   ├── values-frontend.yaml       # Exemple Frontend
│   └── values-worker.yaml         # Exemple Worker
└── README.md                       # Ce fichier
```

## 🚀 Installation

### Prérequis
- Kubernetes cluster (1.19+)
- Helm 3.x
- Terraform 1.0+ (pour l'intégration Terraform)

### Installation locale

```bash
# Cloner le repository
git clone <repo-url>
cd infra-templates

# Valider le chart
helm lint .

# Tester le rendu des templates
helm template my-app . -f examples/values-api-backend.yaml

# Installer le chart
helm install my-app . -f examples/values-api-backend.yaml -n production
```

## 📖 Utilisation

### Déploiement simple

```bash
# Créer un fichier values personnalisé
cat > my-values.yaml <<EOF
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

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
EOF

# Déployer
helm install myapp . -f my-values.yaml
```

### Mise à jour

```bash
# Mettre à jour l'application
helm upgrade myapp . -f my-values.yaml

# Rollback si nécessaire
helm rollback myapp
```

### Désinstallation

```bash
helm uninstall myapp
```

## ⚙️ Configuration

### Variables principales

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `replicaCount` | Nombre de réplicas | `1` |
| `image.repository` | Repository de l'image | `nginx` |
| `image.tag` | Tag de l'image | `latest` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `service.enabled` | Activer le service | `true` |
| `service.type` | Type de service | `ClusterIP` |
| `ingress.enabled` | Activer l'ingress | `false` |
| `autoscaling.enabled` | Activer HPA | `false` |
| `resources.limits.cpu` | Limite CPU | - |
| `resources.limits.memory` | Limite mémoire | - |

### Configuration avancée

Voir le fichier [values.yaml](values.yaml) pour la liste complète des paramètres.

## 📚 Exemples

### 1. API Backend (Node.js)

```yaml
replicaCount: 3

image:
  repository: mycompany/api
  tag: "v1.2.3"

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
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
          portName: http

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70

env:
  - name: NODE_ENV
    value: "production"
  - name: DATABASE_HOST
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: host
```

Voir [examples/values-api-backend.yaml](examples/values-api-backend.yaml) pour un exemple complet.

### 2. Frontend (React/Vue)

```yaml
replicaCount: 2

image:
  repository: mycompany/frontend
  tag: "2.5.1"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 3000

ingress:
  enabled: true
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix

configMap:
  enabled: true
  data:
    env.js: |
      window.ENV = {
        API_URL: 'https://api.example.com'
      };
```

Voir [examples/values-frontend.yaml](examples/values-frontend.yaml) pour un exemple complet.

### 3. Worker/Background Job

```yaml
replicaCount: 5

image:
  repository: mycompany/worker
  tag: "1.0.0"

# Pas de service pour un worker
service:
  enabled: false

# Probes adaptées
livenessProbe:
  enabled: true
  exec:
    command:
      - python
      - /app/healthcheck.py

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 50

nodeSelector:
  workload-type: compute-intensive
```

Voir [examples/values-worker.yaml](examples/values-worker.yaml) pour un exemple complet.

## 🔧 Terraform Integration

### Configuration du provider

```hcl
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
```

### Déploiement d'une application

```hcl
resource "helm_release" "api_backend" {
  name       = "api-backend"
  namespace  = "production"
  chart      = "./infra-templates"
  
  values = [
    yamlencode({
      replicaCount = 3
      
      image = {
        repository = "mycompany/api"
        tag        = "v1.2.3"
      }
      
      service = {
        enabled = true
        type    = "ClusterIP"
        ports = [
          {
            name       = "http"
            port       = 80
            targetPort = 8080
          }
        ]
      }
      
      ingress = {
        enabled   = true
        className = "nginx"
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
      }
      
      autoscaling = {
        enabled                        = true
        minReplicas                    = 3
        maxReplicas                    = 20
        targetCPUUtilizationPercentage = 70
      }
    })
  ]
}
```

Voir [examples/terraform-example.tf](examples/terraform-example.tf) pour des exemples complets.

## 🎯 Bonnes pratiques

### 1. Gestion des secrets

**❌ Mauvais** - Secrets en clair dans values.yaml
```yaml
secret:
  enabled: true
  data:
    password: "supersecret"
```

**✅ Bon** - Utiliser des outils de gestion de secrets
```hcl
# Terraform avec AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

resource "helm_release" "app" {
  # ...
  values = [
    yamlencode({
      secret = {
        enabled = true
        data = {
          password = data.aws_secretsmanager_secret_version.db_password.secret_string
        }
      }
    })
  ]
}
```

### 2. Resources requests/limits

Toujours définir les resources pour éviter les problèmes de performance :

```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

### 3. Health checks

Configurer les probes pour assurer la disponibilité :

```yaml
livenessProbe:
  enabled: true
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  enabled: true
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
```

### 4. Autoscaling

Utiliser HPA pour gérer la charge :

```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

### 5. Labels et annotations

Utiliser des labels cohérents pour le monitoring et la gestion :

```yaml
commonLabels:
  environment: production
  team: backend
  cost-center: engineering
  managed-by: terraform

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
```

### 6. Multi-environnement

Utiliser des fichiers values séparés par environnement :

```bash
# Dev
helm install myapp . -f values-dev.yaml

# Staging
helm install myapp . -f values-staging.yaml

# Production
helm install myapp . -f values-prod.yaml
```

### 7. Checksum automatique

Le chart inclut automatiquement des checksums pour redémarrer les pods lors de changements :

```yaml
# Dans deployment.yaml (automatique)
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
```

## 🔍 Debugging

### Vérifier le rendu des templates

```bash
helm template myapp . -f my-values.yaml
```

### Valider le chart

```bash
helm lint .
```

### Dry-run avant installation

```bash
helm install myapp . -f my-values.yaml --dry-run --debug
```

### Voir les valeurs effectives

```bash
helm get values myapp
```

### Voir les manifests déployés

```bash
helm get manifest myapp
```

## 📝 Maintenance

### Mise à jour du chart

1. Modifier les templates ou values.yaml
2. Incrémenter la version dans Chart.yaml
3. Tester avec `helm lint` et `helm template`
4. Déployer avec `helm upgrade`

### Versioning

Le chart suit le [Semantic Versioning](https://semver.org/) :
- **MAJOR** : Changements incompatibles
- **MINOR** : Nouvelles fonctionnalités compatibles
- **PATCH** : Corrections de bugs

## 🤝 Contribution

Les contributions sont les bienvenues ! Merci de :
1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📄 License

Ce projet est sous licence MIT.

## 📞 Support

Pour toute question ou problème :
- Ouvrir une issue sur GitHub
- Contacter l'équipe DevOps : devops@example.com

## 🔗 Ressources

- [Documentation Helm](https://helm.sh/docs/)
- [Documentation Kubernetes](https://kubernetes.io/docs/)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Best Practices Helm](https://helm.sh/docs/chart_best_practices/)
