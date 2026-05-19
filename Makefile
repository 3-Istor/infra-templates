# =============================================================================
# Makefile pour faciliter l'utilisation du Helm Chart
# =============================================================================

.PHONY: help lint template install upgrade uninstall test dry-run package

# Variables
CHART_NAME ?= generic-app
RELEASE_NAME ?= myapp
NAMESPACE ?= default
VALUES_FILE ?= values.yaml

help: ## Afficher l'aide
	@echo "Commandes disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: ## Valider le chart Helm
	@echo "🔍 Validation du chart..."
	helm lint .

template: ## Afficher le rendu des templates
	@echo "📄 Rendu des templates..."
	helm template $(RELEASE_NAME) . -f $(VALUES_FILE)

template-api: ## Afficher le rendu pour l'API backend
	@echo "📄 Rendu des templates pour API Backend..."
	helm template api-backend . -f examples/values-api-backend.yaml

template-frontend: ## Afficher le rendu pour le frontend
	@echo "📄 Rendu des templates pour Frontend..."
	helm template frontend . -f examples/values-frontend.yaml

template-worker: ## Afficher le rendu pour le worker
	@echo "📄 Rendu des templates pour Worker..."
	helm template worker . -f examples/values-worker.yaml

dry-run: ## Dry-run de l'installation
	@echo "🧪 Dry-run de l'installation..."
	helm install $(RELEASE_NAME) . -f $(VALUES_FILE) --dry-run --debug --namespace $(NAMESPACE)

install: ## Installer le chart
	@echo "🚀 Installation du chart..."
	helm install $(RELEASE_NAME) . -f $(VALUES_FILE) --namespace $(NAMESPACE) --create-namespace

upgrade: ## Mettre à jour le chart
	@echo "⬆️  Mise à jour du chart..."
	helm upgrade $(RELEASE_NAME) . -f $(VALUES_FILE) --namespace $(NAMESPACE)

uninstall: ## Désinstaller le chart
	@echo "🗑️  Désinstallation du chart..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

status: ## Afficher le statut du release
	@echo "📊 Statut du release..."
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)

values: ## Afficher les valeurs du release
	@echo "📋 Valeurs du release..."
	helm get values $(RELEASE_NAME) --namespace $(NAMESPACE)

manifest: ## Afficher les manifests déployés
	@echo "📜 Manifests déployés..."
	helm get manifest $(RELEASE_NAME) --namespace $(NAMESPACE)

history: ## Afficher l'historique des releases
	@echo "📚 Historique des releases..."
	helm history $(RELEASE_NAME) --namespace $(NAMESPACE)

rollback: ## Rollback à la version précédente
	@echo "⏪ Rollback..."
	helm rollback $(RELEASE_NAME) --namespace $(NAMESPACE)

package: ## Packager le chart
	@echo "📦 Packaging du chart..."
	helm package .

test-all: lint template-api template-frontend template-worker ## Tester tous les exemples
	@echo "✅ Tous les tests sont passés!"

# Exemples d'installation pour différents environnements
install-dev: ## Installer en dev
	@echo "🚀 Installation en DEV..."
	helm install myapp-dev . -f examples/values-dev.yaml --namespace dev --create-namespace

install-staging: ## Installer en staging
	@echo "🚀 Installation en STAGING..."
	helm install myapp-staging . -f examples/values-staging.yaml --namespace staging --create-namespace

install-prod: ## Installer en production
	@echo "🚀 Installation en PRODUCTION..."
	helm install myapp-prod . -f examples/values-production.yaml --namespace production --create-namespace

# Exemples d'installation pour différentes applications
install-api: ## Installer l'API backend
	@echo "🚀 Installation de l'API Backend..."
	helm install api-backend . -f examples/values-api-backend.yaml --namespace production --create-namespace

install-frontend: ## Installer le frontend
	@echo "🚀 Installation du Frontend..."
	helm install frontend . -f examples/values-frontend.yaml --namespace production --create-namespace

install-worker: ## Installer le worker
	@echo "🚀 Installation du Worker..."
	helm install worker . -f examples/values-worker.yaml --namespace production --create-namespace

# Nettoyage
clean: ## Nettoyer les fichiers générés
	@echo "🧹 Nettoyage..."
	rm -f *.tgz

# Terraform
tf-init: ## Initialiser Terraform
	@echo "🔧 Initialisation de Terraform..."
	cd examples && terraform init

tf-plan: ## Plan Terraform
	@echo "📋 Plan Terraform..."
	cd examples && terraform plan

tf-apply: ## Appliquer Terraform
	@echo "🚀 Application de Terraform..."
	cd examples && terraform apply

tf-destroy: ## Détruire les ressources Terraform
	@echo "🗑️  Destruction des ressources Terraform..."
	cd examples && terraform destroy
