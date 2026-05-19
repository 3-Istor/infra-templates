# 🚀 Guide de démarrage rapide

Ce guide vous permet de déployer votre première application en 5 minutes.

## ⚡ Installation rapide

### Prérequis

```bash
# Vérifier que vous avez les outils nécessaires
helm version
kubectl version
kubectl cluster-info
```

### Étape 1 : Cloner le repository

```bash
git clone <repo-url>
cd infra-templates
```

### Étape 2 : Valider le chart

```bash
helm lint .
```

### Étape 3 : Déployer votre première application

```bash
# Créer un namespace
kubectl create namespace demo

# Déployer une application de test (nginx)
helm install demo-app . \
  --namespace demo \
  --set image.repository=nginx \
  --set image.tag=latest \
  --set service.enabled=true \
  --set service.type=ClusterIP \
  --set service.ports[0].name=http \
  --set service.ports[0].port=80 \
  --set service.ports[0].targetPort=80

# Vérifier le déploiement
kubectl get pods -n demo
kubectl get svc -n demo
```

### Étape 4 : Accéder à l'application

```bash
# Port-forward pour accéder localement
kubectl port-forward -n demo svc/demo-app-generic-app 8080:80

# Ouvrir dans le navigateur
open http://localhost:8080
```

### Étape 5 : Nettoyer

```bash
helm uninstall demo-app -n demo
kubectl delete namespace demo
```

## 📝 Exemples par cas d'usage

### 1. Déployer une API Node.js

```bash
# Créer un fichier values
cat > my-api-values.yaml <<EOF
replicaCount: 2

image:
  repository: mycompany/api
  tag: "1.0.0"
  pullPolicy: IfNotPresent

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

env:
  - name: NODE_ENV
    value: "production"
  - name: PORT
    value: "8080"

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
EOF

# Déployer
helm install my-api . -f my-api-values.yaml -n production --create-namespace

# Vérifier
kubectl get pods -n production
kubectl logs -n production -l app.kubernetes.io/instance=my-api
```

### 2. Déployer un Frontend React

```bash
cat > my-frontend-values.yaml <<EOF
replicaCount: 2

image:
  repository: mycompany/frontend
  tag: "2.0.0"

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 3000

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
          portName: http

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

configMap:
  enabled: true
  data:
    env.js: |
      window.ENV = {
        API_URL: 'https://api.example.com'
      };
EOF

helm install my-frontend . -f my-frontend-values.yaml -n production
```

### 3. Déployer un Worker Python

```bash
cat > my-worker-values.yaml <<EOF
replicaCount: 3

image:
  repository: mycompany/worker
  tag: "1.0.0"

# Pas de service pour un worker
service:
  enabled: false

ingress:
  enabled: false

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Probes pour worker (pas de HTTP)
livenessProbe:
  enabled: true
  exec:
    command:
      - python
      - /app/healthcheck.py
  initialDelaySeconds: 60
  periodSeconds: 30

env:
  - name: WORKER_TYPE
    value: "celery"
  - name: LOG_LEVEL
    value: "INFO"

secret:
  enabled: true
  type: Opaque
  data:
    broker-url: "redis://redis:6379/0"
EOF

helm install my-worker . -f my-worker-values.yaml -n production
```

## 🔧 Utilisation avec Terraform

### Configuration minimale

```hcl
# main.tf
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "myapp" {
  name       = "myapp"
  namespace  = "production"
  chart      = "./infra-templates"
  
  values = [
    yamlencode({
      replicaCount = 3
      
      image = {
        repository = "mycompany/myapp"
        tag        = "1.0.0"
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
      
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    })
  ]
}
```

### Déployer avec Terraform

```bash
# Initialiser
terraform init

# Voir le plan
terraform plan

# Appliquer
terraform apply

# Détruire
terraform destroy
```

## 🎯 Commandes utiles

### Helm

```bash
# Lister les releases
helm list -A

# Voir le statut
helm status myapp -n production

# Voir les valeurs
helm get values myapp -n production

# Voir les manifests
helm get manifest myapp -n production

# Historique
helm history myapp -n production

# Rollback
helm rollback myapp -n production

# Upgrade
helm upgrade myapp . -f values.yaml -n production

# Désinstaller
helm uninstall myapp -n production
```

### Kubernetes

```bash
# Voir les pods
kubectl get pods -n production

# Voir les logs
kubectl logs -n production -l app.kubernetes.io/instance=myapp --tail=100 -f

# Décrire un pod
kubectl describe pod <pod-name> -n production

# Exec dans un pod
kubectl exec -it <pod-name> -n production -- /bin/sh

# Port-forward
kubectl port-forward -n production svc/myapp 8080:80

# Voir les events
kubectl get events -n production --sort-by='.lastTimestamp'
```

## 🐛 Troubleshooting

### Le pod ne démarre pas

```bash
# Voir les events
kubectl describe pod <pod-name> -n production

# Voir les logs
kubectl logs <pod-name> -n production

# Vérifier l'image
kubectl get pod <pod-name> -n production -o jsonpath='{.spec.containers[0].image}'
```

### Erreur ImagePullBackOff

```bash
# Vérifier les imagePullSecrets
kubectl get pod <pod-name> -n production -o jsonpath='{.spec.imagePullSecrets}'

# Créer un secret pour le registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n production

# Ajouter dans values.yaml
imagePullSecrets:
  - name: regcred
```

### Le service n'est pas accessible

```bash
# Vérifier le service
kubectl get svc -n production

# Vérifier les endpoints
kubectl get endpoints -n production

# Tester depuis un pod
kubectl run -it --rm debug --image=busybox --restart=Never -n production -- wget -O- http://myapp:80
```

### ConfigMap/Secret non pris en compte

Les checksums sont automatiquement ajoutés pour forcer le redémarrage des pods lors de changements.

```bash
# Forcer un redémarrage manuel si nécessaire
kubectl rollout restart deployment/myapp-generic-app -n production
```

## 📚 Prochaines étapes

1. **Personnaliser les values** - Adapter à vos besoins
2. **Configurer l'ingress** - Exposer votre application
3. **Ajouter l'autoscaling** - Gérer la charge
4. **Configurer le monitoring** - Prometheus, Grafana
5. **Mettre en place la CI/CD** - Automatiser les déploiements

## 🔗 Ressources

- [README complet](README.md)
- [Exemples détaillés](examples/README.md)
- [Guide de contribution](CONTRIBUTING.md)
- [Documentation Helm](https://helm.sh/docs/)

## 💡 Astuces

### Utiliser le Makefile

```bash
# Voir toutes les commandes
make help

# Valider le chart
make lint

# Tester le rendu
make template

# Installer en dev
make install-dev

# Installer en production
make install-prod
```

### Utiliser des variables d'environnement

```bash
# Définir des variables
export RELEASE_NAME=myapp
export NAMESPACE=production
export VALUES_FILE=my-values.yaml

# Utiliser avec make
make install
```

### Combiner plusieurs fichiers values

```bash
# Base + overrides
helm install myapp . \
  -f values.yaml \
  -f values-production.yaml \
  -f values-custom.yaml \
  -n production
```

### Utiliser --set pour des overrides rapides

```bash
helm install myapp . \
  -f values.yaml \
  --set image.tag=v2.0.0 \
  --set replicaCount=5 \
  -n production
```

## ✅ Checklist de déploiement

Avant de déployer en production :

- [ ] Le chart est validé (`helm lint`)
- [ ] Les templates se rendent correctement (`helm template`)
- [ ] Les resources sont définies (requests/limits)
- [ ] Les probes sont configurées (liveness/readiness)
- [ ] Les secrets sont sécurisés (pas en clair)
- [ ] L'autoscaling est configuré si nécessaire
- [ ] Le monitoring est activé (annotations Prometheus)
- [ ] Les labels sont cohérents
- [ ] L'ingress est configuré avec TLS
- [ ] Le namespace existe
- [ ] Les imagePullSecrets sont configurés si nécessaire

Bon déploiement ! 🚀
