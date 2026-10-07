---
name: mise-a-jour-jojont54
description: Vérifie si la base française de Jojont54 (dépôt upstream) a de nouveaux commits, résume ce qui change, mesure l'effet sur nos profils et nos tweaks (scores, nouveaux rejets, motifs, tweaks devenus sans effet, paliers de langue), puis fusionne et pousse après accord. À utiliser quand l'utilisateur demande s'il y a des mises à jour de Jojont54, d'intégrer ou de fusionner upstream, ou ce qu'apporte une nouvelle version de la base.
---

# Intégrer une mise à jour de Jojont54

But : dire à l'utilisateur **ce que la mise à jour change pour nos six
profils** et **ce qu'il faut adapter dans `tweaks/`**, puis fusionner. La
fusion git elle-même ne pose jamais de conflit (nos changements sont tous
dans `tweaks/`, `outils/`, `CLAUDE.md` et `.claude/`) : le risque est sur
le fond, un tweak qui ne s'applique plus ou une règle qui change de sens.

Rien n'est fusionné, modifié ni poussé sans l'accord de l'utilisateur. Ne
jamais modifier un fichier de Jojont54 (`ops/`, `docs/`, `README.md`,
`pcd.json`…) : une adaptation va dans `tweaks/`.

## 1. Y a-t-il du nouveau ?

```
git status
git pull
git fetch upstream
git log --oneline stable..upstream/stable
```

Copie de travail sale : demander avant de continuer. Rien de nouveau sur
`upstream/stable` : le dire, et indiquer en une ligne ce qu'annoncent
`upstream/testing` et `upstream/develop` (`git log --oneline
stable..upstream/develop`), qui arrivent ensuite dans `stable`.

## 2. Lire les commits

```
git log --reverse --format='%h %s%n%b' stable..upstream/stable
git diff --stat stable...upstream/stable
git diff stable...upstream/stable -- ops pcd.json
```

Les commits de fusion portent le titre des demandes de fusion de
Jojont54 (« Merge pull request #67… » suivi du titre) : partir de là, puis
lire les diffs d'`ops/`. Repérer :

- les profils touchés : seuls comptent pour nous `2160p Balanced FR`,
  `2160p Quality FR`, `1080p Compact FR`, `Anime 1080p FR` (bases de nos
  profils, voir `tweaks/10.profils.sql`) et `2160p Compact FR`
  (`tweaks/50.interface.sql`) ; les formats et motifs partagés comptent
  partout ;
- un changement de version du schéma dans `pcd.json` (`compiler.py`
  clone la nouvelle version tout seul ; lire ce qu'elle change).

## 3. Mesurer l'effet sur nos profils

```
python outils/comparer.py
```

Compile la base actuelle et la base après fusion (sans toucher à la copie
de travail) et donne, profil par profil, ce qui change. Une erreur de
compilation après fusion arrête le script en nommant le fichier : un
tweak qui insère un nom désormais pris par Jojont54 (contrainte UNIQUE),
ou qui vise un format disparu (clé étrangère).

Lire chaque section :

- **Scores changés** : effet sur l'ordre des releases à l'intérieur d'un
  palier de langue, normalement voulu par Jojont54. Les seuils de mise à
  niveau (`tweaks/40.mises-a-niveau.sql`) supposent les paliers de qualité
  visés à 920 000 (2160p WEB-DL HEVC), 940 000 (2160p Bluray HEVC),
  930 000 (1080p HDLight WEBRip) et 860 000 (1080p WEB-DL) : si l'un de
  ces scores bouge, ajuster le seuil correspondant.
- **Nouveau repli** : Jojont54 a ajouté un rejet (-999 999), devenu chez
  nous un repli (-1 000 000, accepté en dernier). Le classer avec
  l'utilisateur : repli, ou rejet s'il est rédhibitoire (illisible, pas le
  film, fausse qualité, trop gros ; règle en tête de
  `tweaks/30.rejets.sql`).
- **Réglages et qualités** : nos tweaks imposent score minimum, seuil et
  gain ; les qualités, elles, sont héritées. Une qualité ajoutée ou
  retirée par Jojont54 se retrouve dans nos profils : le signaler.
- **Formats dont les conditions changent, motifs modifiés** : comprendre
  ce qui est désormais reconnu ou non ; essayer sur des noms concrets
  (ci-dessous). Les motifs `French MULTi`, `French VOSTFR`,
  `French MultiSub (INTL)`, `French VFQ`, `French Original Marker`,
  `HDLight`, `x265` et les motifs de groupes d'anime servent aussi à nos
  formats de `tweaks/20.langue.sql`.
- **Tweaks sans effet** : l'instruction citée ne touche plus aucune ligne
  (format ou profil renommé ou retiré). Retrouver le nouveau nom dans le
  diff et corriger le tweak.
- **Vérification des paliers** : doit afficher « 0 écart(s) ». Sinon, une
  qualité sort de sa bande et ferait passer une langue devant une autre :
  voir l'en-tête de `tweaks/20.langue.sql`.

Essais sur des noms de release, quand un format ou un motif change :

```
python outils/scores.py "<nom>"                          # Radarr
python outils/scores.py --arr sonarr "<nom>"
python outils/scores.py --langues French,English "<nom>" # MULTi vue sur un indexeur FR
```

Variables `RADARR_URL`, `RADARR_API_KEY`, `SONARR_URL`, `SONARR_API_KEY`
nécessaires. Absentes : demander à l'utilisateur de les définir (variables
d'environnement utilisateur), **jamais** lire les clés dans les
`config.xml` des serveurs. Faute de clés, se contenter de `comparer.py`.

`python outils/comparer.py upstream/develop` montre de la même façon ce
qui arrivera ensuite.

## 4. Rendre compte

En français, sans recopier les diffs :

1. les commits de Jojont54, résumés (un point par demande de fusion) ;
2. ce qui change pour nos profils, profil par profil, et ce qui ne les
   touche pas (en une ligne) ;
3. les tweaks à adapter, avec la modification proposée ;
4. les décisions à prendre (nouveaux replis à classer, seuils…).

Attendre l'accord de l'utilisateur.

## 5. Fusionner et pousser

```
git merge --no-ff upstream/stable -m "base : fusion de Jojont54 (<résumé court>)"
```

Puis, s'il y a lieu, adapter `tweaks/` dans un commit à part
(`tweaks : <ce qui change>`, avec la ligne `Co-Authored-By` habituelle).
Avant de pousser :

```
python outils/compiler.py
python outils/scores.py --verifier
```

Compilation sans erreur ni « instruction sans effet », « 0 écart(s) ».
Pousser fusion et adaptations ensemble (`git push origin stable`) :
Profilarr récupère le dépôt toutes les heures et synchronise Sonarr et
Radarr ; un état intermédiaire poussé seul s'y appliquerait.

`upstream` n'accepte pas de push (adresse volontairement invalide). Dépôt
public : ni adresse, ni nom de machine, ni secret dans les commits ;
identité GitHub *noreply* déjà configurée dans ce clone.
