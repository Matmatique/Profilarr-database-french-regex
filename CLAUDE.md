# Fork personnel de la base Profilarr française (Jojont54)

Base Profilarr 2 personnelle (fiche `profilarr` du dépôt `stacks`),
synchronisée vers Sonarr et Radarr.
Infrastructure et façon de travailler : `INFRA.md` du dépôt `stacks`
(chargé dans chaque session). **Dépôt public** : ni adresse, ni nom de
machine, ni secret ici ; les détails de l'installation restent dans
`stacks`.

## Pourquoi un fork, et la règle d'or

Profilarr compile une base en couches : `deps/schema/ops` (schéma), `ops/`
(la base de Jojont54), **`tweaks/` (SQL propre au dépôt)**, puis les
modifications faites dans l'interface (non versionnées, à éviter).

**Nos changements vont uniquement dans `tweaks/`** (et `outils/`,
`CLAUDE.md`, `.claude/`). Ne jamais modifier un fichier de Jojont54
(`ops/`, `docs/`, `README.md`, `pcd.json`…) : la fusion de ses mises à jour
reste ainsi sans conflit git. Le risque restant est sur le fond : Jojont54
réécrit ses fichiers d'`ops/` sur place, un format peut être renommé ou un
score changé, et un tweak ne plus s'appliquer. D'où les tests ci-dessous.

Profilarr ne lit que les fichiers `.sql` de `tweaks/`, triés par numéro en
tête de nom (`10.langue.sql`), et n'accepte que des dépôts GitHub : la
référence de ce dépôt est GitHub, pas Forgejo (exception notée dans
`INFRA.md`).

## Dépôts distants

- `origin` : ce fork (branche `stable`, la seule, suivie par Profilarr).
- `upstream` : la base de Jojont54 (push désactivé). Ses branches
  `develop` et `testing` annoncent ce qui arrive dans `stable`.

Commits en français, sous l'identité GitHub *noreply* (configurée dans ce
clone) : le dépôt est public.

## Intégrer les mises à jour de Jojont54

1. `git fetch upstream` ; nouveaux commits : `git log stable..upstream/stable`.
2. Analyse : résumer les commits, compiler la base avant et après fusion
   (`outils/compiler.py`), comparer les scores de nos profils, repérer les
   tweaks qui échouent ou ne changent plus rien.
3. Après accord de l'utilisateur : `git merge upstream/stable`, push.
   Profilarr récupère le dépôt toutes les heures et synchronise.

À transformer en skill (`.claude/skills/`) une fois le premier passage fait
à la main.

## Objectifs

**Profils visés** (noms à confirmer) :

| Profil | Base Jojont54 | Langue |
|---|---|---|
| 4K · VF | 2160p Balanced FR | MULTi > VF > VO |
| 4K · VO | 2160p Balanced FR | MULTi > VO > VF |
| 4K Cinéma | 2160p Quality FR | MULTi > VO > VF |
| Compact · VF | 1080p Compact FR (HDLight) | MULTi > VF > VO |
| Compact · VO | 1080p Compact FR (HDLight) | MULTi > VO > VF |
| Anime | Anime 1080p FR | MULTi > VOSTFR > VF |

Écran cible : OLED 4K, Dolby Vision et HDR10, **pas de HDR10+** (bonus
inutile). Pas de remux. La piste audio est choisie à la lecture, série par
série : une version MULTi convient toujours, la variante VF/VO ne joue que
sans MULTi.

**A. La langue avant la qualité.** Les profils de la base classent la
qualité par score de format (20 000 à 960 000) et ne font que pénaliser la
langue (VF −50 000, VOSTFR −200 000, VO seule interdite par
« French Missing ») : une VF 1080p bat une MULTi 720p. Passer la langue en
paliers dominants (MULTi +2 000 000, langue préférée +1 000 000, l'autre
0), qualité et bonus restant sous 1 000 000. Autoriser la VO seule.
Garder toutes les qualités dans un seul groupe (sinon l'ordre des qualités
passe avant les scores).

**B. Langues fiables à l'import.** Constaté dans Sonarr/Radarr (code de
`AggregateLanguage` et de `CustomFormatCalculationService`) :
- à l'import, les langues viennent du nom du fichier, du dossier, du
  torrent, puis **des pistes audio** (MediaInfo), la dernière source non
  vide l'emportant ; une piste `und` est ignorée ;
- le nom testé par les formats est celui de la release si Sonarr l'a
  gardé, sinon celui du fichier (cas des packs de saison) ;
- « French Missing » ne regarde en pratique que le nom : sans marqueur
  français dans le nom du fichier, −999 999 même avec une piste française.

Cas typique : un pack de saison `…S03.MULTI…`, vu FR + VO à la recherche,
n'a plus que la VO à l'import (piste française en `und`, fichiers sans
`MULTI` dans le nom) ; vu comme une mise à niveau, il reste bloqué en
« Not a Custom Format upgrade » et doit être ignoré à la main. Fonder les
formats de langue sur la condition de langue (réglage « Multi Languages »
des indexeurs FR à la recherche, pistes audio à l'import), le nom ne
servant que de complément ; la VFQ reste détectée par le nom.

**C. Mises à niveau raisonnables.** Seuil d'arrêt aujourd'hui à 1 000 000
(jamais atteint) et gain minimum de 1 : chaque petit gain relance un
téléchargement. Viser un seuil réaliste (MULTi + palier de qualité cible)
et un gain minimum de 20 000 à 50 000.

**Transition** : avec la langue dominante, les fichiers en VF seule
deviendront améliorables en MULTi. Encadrer la bascule (recherches de mise
à niveau de Profilarr suspendues au début) pour éviter une vague de
téléchargements.

**À reprendre de l'interface de Profilarr dans `tweaks/`** : les
modifications locales actuelles de cette base (score de « 2160p WEB-DL »
ramené à 0 dans « 2160p Compact FR » pour Radarr et Sonarr). Le reste de
la bascule (autres bases liées dans Profilarr, profils attribués) relève de
l'installation : voir le chantier « Profils de qualité » du dépôt `stacks`.

## Tests

- `python outils/compiler.py` : rejoue schéma, `ops/` et `tweaks/` dans
  une base SQLite en mémoire (comme Profilarr), s'arrête à la première
  erreur et peut écrire le résultat (`--sortie base.db`) pour comparer les
  profils.
- Sonarr et Radarr, en lecture seule : `GET /api/v3/parse?title=…`
  (formats reconnus pour un nom de release, comme à la recherche) et
  `GET /api/v3/manualimport?folder=…` (langues, formats et score calculés
  à l'import, sans rien importer).
- Profilarr : testeur de noms de release (conteneur `profilarr-parser`).
