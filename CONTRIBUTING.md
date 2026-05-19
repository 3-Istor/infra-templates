# Guide de contribution

Merci de votre intérêt pour contribuer à ce projet ! 🎉

## 🚀 Comment contribuer

### 1. Fork et Clone

```bash
# Fork le projet sur GitHub
# Puis clone ton fork
git clone https://github.com/ton-username/infra-templates.git
cd infra-templates
```

### 2. Créer une branche

```bash
git checkout -b feature/ma-nouvelle-fonctionnalite
```

### 3. Faire les modifications

- Modifier les templates dans `templates/`
- Mettre à jour `values.yaml` si nécessaire
- Ajouter des exemples dans `examples/` si pertinent
- Mettre à jour la documentation

### 4. Tester les modifications

```bash
# Valider le chart
make lint

# Tester le rendu des templates
make template

# Tester avec les exemples
make test-all
```

### 5. Commit et Push

```bash
git add .
git commit -m "feat: ajouter support pour X"
git push origin feature/ma-nouvelle-fonctionnalite
```

### 6. Créer une Pull Request

Ouvre une Pull Request sur GitHub avec :
- Une description claire des changements
- Les raisons de ces changements
- Les tests effectués

## 📝 Conventions

### Commits

Utiliser [Conventional Commits](https://www.conventionalcommits.org/) :

- `feat:` - Nouvelle fonctionnalité
- `fix:` - Correction de bug
- `docs:` - Documentation uniquement
- `style:` - Formatage, pas de changement de code
- `refactor:` - Refactoring du code
- `test:` - Ajout ou modification de tests
- `chore:` - Maintenance

Exemples :
```
feat: ajouter support pour PersistentVolumeClaim
fix: corriger le checksum des secrets
docs: améliorer la documentation du README
```

### Code

- Utiliser des noms de variables explicites
- Commenter les parties complexes
- Suivre les [Best Practices Helm](https://helm.sh/docs/chart_best_practices/)
- Tester avec plusieurs scénarios

### Templates Helm

```yaml
# ✅ Bon - Utiliser les helpers
name: {{ include "generic-app.fullname" . }}

# ❌ Mauvais - Hardcoder les valeurs
name: myapp

# ✅ Bon - Conditions claires
{{- if .Values.service.enabled }}
...
{{- end }}

# ✅ Bon - Indentation correcte
labels:
  {{- include "generic-app.labels" . | nindent 4 }}
```

## 🧪 Tests

Avant de soumettre une PR, assure-toi que :

1. **Le chart est valide**
   ```bash
   make lint
   ```

2. **Les templates se rendent correctement**
   ```bash
   make template-api
   make template-frontend
   make template-worker
   ```

3. **Les exemples fonctionnent**
   ```bash
   make test-all
   ```

4. **Le chart s'installe sans erreur**
   ```bash
   make dry-run
   ```

## 📚 Documentation

Si tu ajoutes une nouvelle fonctionnalité :

1. Mettre à jour `README.md`
2. Ajouter un exemple dans `examples/`
3. Documenter les nouvelles valeurs dans `values.yaml`
4. Ajouter des commentaires dans les templates

## 🐛 Signaler un bug

Pour signaler un bug, ouvre une issue avec :

- **Description** : Que se passe-t-il ?
- **Reproduction** : Comment reproduire le bug ?
- **Attendu** : Quel était le comportement attendu ?
- **Environnement** : Version de Helm, Kubernetes, etc.
- **Logs** : Logs pertinents si disponibles

## 💡 Proposer une fonctionnalité

Pour proposer une nouvelle fonctionnalité :

1. Ouvre une issue pour discuter de l'idée
2. Explique le cas d'usage
3. Propose une implémentation si possible
4. Attends les retours avant de commencer le développement

## ✅ Checklist PR

Avant de soumettre ta PR, vérifie que :

- [ ] Le code suit les conventions du projet
- [ ] Les tests passent (`make test-all`)
- [ ] La documentation est à jour
- [ ] Les commits suivent Conventional Commits
- [ ] La PR a une description claire
- [ ] Les exemples fonctionnent

## 🤝 Code de conduite

- Sois respectueux et constructif
- Accepte les critiques constructives
- Aide les autres contributeurs
- Concentre-toi sur ce qui est le mieux pour le projet

## 📞 Questions ?

Si tu as des questions :
- Ouvre une issue
- Contacte l'équipe DevOps
- Consulte la documentation Helm

Merci pour ta contribution ! 🙏
