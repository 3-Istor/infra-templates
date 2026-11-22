# infra-templates

## Rôle

Chart Helm `cnp-generic-app` commun aux applications CNP. Il transforme les valeurs d’un dépôt applicatif en ressources Kubernetes et peut être rendu par Argo CD ou utilisé manuellement avec Helm.

## Technologies

Helm 3, templates Go et YAML Kubernetes ; ressource `VaultSecret` de l’opérateur `ricoberger.de` lorsque les secrets sont activés.

## Entrées

| Origine / destinataire | Contenu et transmission |
| --- | --- |
| Dépôts applicatifs | Valeurs `deploy/*.yaml` : image/tag, ports, ressources, configuration et chemin Vault éventuel. |
| K3s / Argo CD ou opérateurs | Nom de release, namespace et paramètres du rendu Helm ; opérateur de secrets disponible si `secrets.enabled=true`. |

## Sorties et consommateurs

| Origine / destinataire | Contenu et transmission |
| --- | --- |
| K3s / Argo CD | Chart récupéré depuis Git pour rendre Deployment, Service, ConfigMap et VaultSecret selon les valeurs. |
| Clusters / opérateurs | Manifests appliqués par Argo CD ou Helm ; aucune image applicative construite dans ce dépôt. |

## Documentation CNP

[Fiche `infra-templates` et workflows inter-repo](https://github.com/3-Istor/cnp-docs/blob/main/docs/04-templates/00-github-repositories-landscape.md#infra-templates).

## Structure

```text
infra-templates/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    └── vaultsecret.yaml
```

## Apps importées (`service`, `backing`)

Leurs valeurs viennent de cnp-projects (`apps/<projet>/<app>/values.yaml`, écrites par le CMP), pas d’un dépôt applicatif. Le chart ajoute pour elles :

- `workload` : commande, sondes, contextes de sécurité, StatefulSet avec PVC conservé à la suppression du StatefulSet (D17, pas à celle du namespace). Un StatefulSet refuse `release.strategy: canary` et `autoscaling.enabled`. `values.schema.json` borne ce bloc (D16) : pas de privileged, d’escalade, de capacités ajoutées, de `runAsNonRoot: false` ni de `host` dans les sondes.
- `image.digest` : épingle l’image, prioritaire sur `tag`.
- `links` : un Service ExternalName par lien vers une autre app du même projet (`templates/links.yaml`), rendu par l’ApplicationSet depuis `dependsOn`.
- `registrySecret.scope: project` : le secret de pull GHCR du projet (`project-<projet>/system/registry`, rôle `project-<projet>-system-role`), sans rôle Vault par app.

`cnp.project`, `cnp.app` et `cnp.environment` sont posés par l’ApplicationSet `cnp-apps` en paramètres Helm, qui priment sur tous les fichiers de valeurs : le dépôt de l’app ne peut pas les changer. Le rôle Vault (`<projet>-<app>[-staging]-role`), le chemin Vault (`project-<projet>/<app>[/staging]`, ou un sous-chemin), le secret de registre et les `links` en dérivent uniquement. Le rendu échoue si le namespace n’est pas exactement `<projet>-<app>[-stg]`, si `project_name` désigne un autre projet, si `secrets.vaultRole` n’est pas le rôle de l’app ou si `secrets.vaultPath` sort du chemin de l’app.

`tests/backing/` montre les valeurs attendues de MongoDB, Redis, Neo4j et Elasticsearch ; `tests/imported-service.yaml` celles d’un service importé.

## IA : agents, serveurs MCP, accès aux modèles

Les droits (modèles, budgets, outils, isolation minimale, appelants) sont dans `spec.ai` du ProjectRecord,
écrit par le CMP et appliqué par la passerelle IA. Les valeurs ci-dessous demandent au plus ces droits ;
la passerelle refuse le reste. Les points d'accès de la plateforme sont des constantes du chart
(`cnp-generic-app.aiPlatform`), jamais des valeurs.

- **`cnp.type=agent`** (`templates/agent.yaml`) : le bloc `agent:` devient un `Agent` kagent déclaratif,
  son `ModelConfig` et son `RemoteMCPServer` (`/mcp/<projet>`) qui pointent sur le sidecar `gw-auth-proxy`
  (`127.0.0.1:15001`, jeton court du client `agent-<projet>-<agent>`, secret `<agent>-ai-oidc` depuis Vault
  `project-<projet>/<agent>/ai-oidc`), une clé factice, un ServiceAccount sans jeton, une
  CiliumNetworkPolicy (entrée : passerelle et kagent ; sortie : passerelle, Keycloak, kagent, DNS, OTLP ;
  Internet et le reste du projet refusés) et, pour `trigger.type: schedule`, un CronJob qui appelle l'agent
  en A2A par la passerelle. Pas de Deployment ni de Service applicatif. `agent.isolation` ne peut que
  relever l'isolation minimale portée par le namespace.
- **`cnp.type=mcp`** (`templates/mcp.yaml`) : kmcp lance l'image de l'app (`MCPServer`, HTTP, `/mcp`).
  Toute autre app qui sert MCP sur `/mcp` le déclare avec `mcp.enabled`. Dans les deux cas, la passerelle
  la joint par le Service `<app>-mcp` (port 80) et elle seule peut entrer.
- **`ai.enabled`** : l'app reçoit `CNP_AI_GATEWAY_URL`, `CNP_AI_TOKEN_URL`, `CNP_AI_CLIENT_ID` et
  `CNP_AI_CLIENT_SECRET` (secret `<app>-ai-oidc` depuis Vault `project-<projet>/<app>/ai-oidc`).

Les presets d'agents sont dans app-templates (`agents/<id>.yaml`) ; le guide `cnp-ai` de cnp-agent-kit
explique la déclaration complète.

## Observabilité (CNP-185, D11)

Tout est désactivé par défaut : une app qui n'active rien garde exactement le même rendu.

- `livenessProbe`, `readinessProbe`, `startupProbe` : rendues quand `enabled: true` (constat C7, elles ne l'étaient jamais). Sous canary, la readiness reste le chemin de smoke du release. `workload.probes` prime pour les apps importées.
- `podAnnotations` : posées sur les pods, valeurs en chaînes uniquement.
- `metrics.enabled` : annotations `prometheus.io/scrape`, `port` (par défaut le `targetPort` du premier port du Service) et `path` (`/metrics`), lues par le collecteur.
- `tracing.enabled` : variables `OTEL_*` standard (nom de service = nom de l'app, `APP_VERSION` = tag ou digest de l'image, passerelle `otelcol-gateway.observability.svc:4317`, échantillonnage parent-based). Jamais `OTEL_RESOURCE_ATTRIBUTES` : le collecteur pose projet, namespace et pod d'après la connexion, et le rendu échoue si `env` la définit.

`tests/observability-values.yaml` montre un backend qui active tout.

## Valeurs fermées et contrôle en CI (CNP-304)

Le dépôt de l'app et le CMP écrivent le même fichier `deploy/values*.yaml`, avec les mêmes règles :

- `values.schema.json` est fermé (`additionalProperties: false`) : une clé inconnue, une faute de frappe ou une valeur hors bornes (service autre que `ClusterIP`, `replicaCount` au-delà de 10, quantité CPU/mémoire illisible, cron invalide, rétention de logs hors 7d/14d/30d…) fait échouer le rendu, donc la CI de l'app et la synchronisation Argo CD. `auth` et `routes`, écrits par app-templates, restent acceptés et ne sont pas lus.
- `secrets.keys` déclare les noms des secrets attendus dans Vault, jamais leurs valeurs ; le CMP affiche les manquants avec un lien vers Vault.
- Image d'une autre app : avec `cnp.project`/`cnp.app`, une image `ghcr.io/3-istor/...` doit être celle de l'app (`ghcr.io/3-istor/<app>[/...]`) ou un import du projet (`ghcr.io/3-istor/imports/<projet>/...`), même règle que la politique Kyverno `restrict-tenant-images`.
- Nom d'hôte : avec `cnp.*`, `ingress.hostname` doit être exactement celui de l'app, `<app>-<projet>.3istor.com` en prod et `<app>-<projet>-staging.3istor.com` en staging, comme le CMP les dérive. Un suffixe `-<projet>` ne suffirait pas : les noms de projet contiennent des tirets (`iot` pourrait prendre `shop-b-iot.3istor.com` du projet `b-iot`) et il couvrirait `auth-`, `status-` et `offhours-<projet>`.
- Quota : chaque namespace d'app a le même ResourceQuota (cnp-project-base, `requests.cpu: 1`, `requests.memory: 2Gi`, `pods: 10`), recopié en constantes dans `cnp-generic-app.quota`. Le rendu calcule le pic de la release (réplicas, surge du rolling update ou second jeu de pods d'un canary, Job de migration, base, pooler, tunnel) et échoue au-delà. Une app fullstack a deux releases dans le même namespace : `ci/check-app-values.sh` additionne leurs pics (`cnp.quotaReport=true`, `templates/quota-report.yaml`).

`ci/check-app-values.sh <checkout de l'app> <nom de l'app>` rend chaque composant et chaque environnement comme l'ApplicationSet `cnp-apps` ; les templates d'app l'appellent dans leur workflow `deploy-values`.

## Utilisation avec Helm

```bash
helm lint .
helm template myapp . -f my-values.yaml -n production
helm install myapp . -f my-values.yaml -n production
```

Créer `my-values.yaml` à partir des valeurs adaptées à l’application. Les valeurs par défaut ne remplacent pas celles du dépôt applicatif ; vérifier notamment l’image, les ports et les sondes de santé. Le rendu ne déploie rien ; `helm install` nécessite un accès au cluster.

## Utilisation avec Terraform

Un opérateur peut aussi consommer le chart depuis un clone local :

```hcl
resource "helm_release" "myapp" {
  name      = "myapp"
  namespace = "production"
  chart     = "./infra-templates"

  values = [yamlencode({
    replicaCount = 3
    image = {
      repository = "mycompany/myapp"
      tag        = "v1.0.0"
    }
    service = {
      enabled = true
      ports = [{ name = "http", port = 80, targetPort = 8080 }]
    }
  })]
}
```

Dans le flux CNP décrit dans la cartographie, Argo CD consomme directement ce dépôt Git et les valeurs du dépôt applicatif.
