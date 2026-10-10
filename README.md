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
