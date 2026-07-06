# Incident — CNPG initdb échoue sur k3s-worker-node (exec format error)

**Date** : 2026-07-06  
**Sévérité** : Moyenne — les nouvelles apps déployées sur le worker node ne pouvaient pas démarrer leur base de données  
**Statut** : Résolu  

---

## Symptômes

Après le déploiement d'une app via la CNP Platform, le backend affichait :

```
DB enabled: yes
DB type: postgres
DB connected: no
```

Les pods `initdb` du cluster CloudNativePG échouaient en boucle :

```
error while creating the PostgreSQL instance:
fork/exec /usr/lib/postgresql/18/bin/initdb: exec format error
```

---

## Cause racine

Le nouveau nœud `k3s-worker-node` (ajouté ~46h avant l'incident) avait l'image `ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie` en cache au format **ARM64**, alors que le nœud est **AMD64** (x86_64).

L'image multi-arch avait été tirée une première fois avec la mauvaise plateforme (probablement lors d'un test ou d'une manipulation précédente sur ce nœud). Containerd ayant mis en cache le digest ARM64, tous les pods CNPG schedulés sur `k3s-worker-node` échouaient au démarrage avec `exec format error`.

Le nœud control-plane `my-k3s-cluster-node` n'était pas affecté car il avait le bon digest en cache.

---

## Timeline

| Heure (UTC) | Événement |
|---|---|
| ~15:16 | Déploiement de l'app `test-hugo-demo` via CMP |
| ~15:16 | Premier pod `initdb` schedulé sur `k3s-worker-node` → `Error` |
| ~15:30 | 7 tentatives d'initdb toutes en erreur |
| ~15:32 | Diagnostic : `exec format error` identifié dans les logs |
| ~15:33 | Confirmation : image ARM64 en cache sur le worker |
| ~15:34 | Suppression de l'image via pod privilégié |
| ~15:34 | Suppression du cluster CNPG → re-pull AMD64 → `initdb` Completed |
| ~15:35 | Cluster CNPG Ready, backend redémarré → `DB connected: true` |

---

## Résolution

### 1. Supprimer l'image en cache sur le worker node

```bash
kubectl run fix-image --restart=Never \
  --overrides='{
    "spec": {
      "nodeSelector": {"kubernetes.io/hostname": "k3s-worker-node"},
      "hostPID": true,
      "containers": [{
        "name": "fix",
        "image": "ubuntu",
        "command": ["nsenter","--mount=/proc/1/ns/mnt","--","bash","-c",
          "crictl rmi ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie 2>&1 || true; echo done"],
        "securityContext": {"privileged": true}
      }]
    }
  }' --image=ubuntu
kubectl logs fix-image
kubectl delete pod fix-image
```

### 2. Supprimer le cluster CNPG bloqué

```bash
kubectl delete cluster <app-fullname>-db -n <namespace>
# ArgoCD recrée le cluster automatiquement avec la bonne image
```

### 3. Redémarrer le pod backend

```bash
kubectl rollout restart deployment/<app-fullname> -n <namespace>
```

---

## Vérification

```bash
kubectl exec -n <namespace> deployment/<app-fullname> -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/api/db/status').read().decode())"
# Attendu : {"enabled":true,"type":"postgres","connected":true}
```

---

## Prévention

### Option A — Forcer le pull AMD64 sur le worker (recommandé)

Lors de l'ajout d'un nouveau nœud AMD64, forcer le pull explicite de l'image CNPG :

```bash
# Sur le nœud via un pod privilégié ou via SSH
crictl pull --platform linux/amd64 ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie
```

### Option B — Ajouter un `nodeSelector` dans le chart Helm

Contraindre les clusters CNPG à tourner uniquement sur le control-plane (contournement, pas idéal) :

```yaml
# Dans infra-templates/templates/cnpg-cluster.yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
```

### Option C — Spécifier explicitement la plateforme dans le cluster CNPG

```yaml
# Dans infra-templates/templates/cnpg-cluster.yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie
  # Forcer le digest AMD64 (à mettre à jour à chaque upgrade CNPG)
```

---

## Contexte système

| Élément | Valeur |
|---|---|
| CNPG Operator | `ghcr.io/cloudnative-pg/cloudnative-pg:1.29.1` |
| Image PostgreSQL | `ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie` |
| Architecture des nœuds | AMD64 (x86_64) |
| Nœud affecté | `k3s-worker-node` (Ubuntu 24.04, k3s v1.34.6) |
| Namespace | `demo-test-hugo` |
