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

Skill `mise-a-jour-jojont54` (`.claude/skills/`) : nouveaux commits
d'`upstream/stable`, résumé, effet sur nos profils (`outils/comparer.py`),
tweaks à adapter, puis fusion et push après accord de l'utilisateur.
Profilarr récupère le dépôt toutes les heures et synchronise.

## Profils

| Profil | Base Jojont54 | Langue |
|---|---|---|
| 4K · VF | 2160p Balanced FR | MULTi > VF > VO |
| 4K · VO | 2160p Balanced FR | MULTi > VO > VF |
| 4K Cinéma | 2160p Quality FR | MULTi > VO > VF |
| Compact · VF | 1080p Compact FR (HDLight) | MULTi > VF > VO |
| Compact · VO | 1080p Compact FR (HDLight) | MULTi > VO > VF |
| Anime | Anime 1080p FR | MULTi > VOSTFR > VO > VF |

Écran principal : OLED 4K, Dolby Vision et HDR10, **pas de HDR10+** (bonus
inutile). D'autres personnes regardent sur des installations moins
poussées : Dolby Vision sans repli HDR10, AV1, VP9 et VVC restent rejetés.
Pas de remux. La piste audio est choisie à la lecture, série par série :
une version MULTi convient toujours, la variante VF/VO ne joue que sans
MULTi.

Tweaks (le détail est en tête de chaque fichier) :

- `10.profils.sql` : les six profils, copiés de ceux de Jojont54 à chaque
  compilation ;
- `20.langue.sql` : **la langue avant la qualité**. Jojont54 ne fait que
  pénaliser la langue (une VF 1080p bat une MULTi 720p) et interdit la VO
  seule. Ici, paliers de langue espacés de 10 000 000 (MULTi 20 000 000,
  langue préférée 10 000 000, l'autre 0), qualité et bonus de Jojont54
  restant sous 1 000 000. VFQ rejetée, sauf œuvre d'origine francophone ;
- `30.rejets.sql` : **une release médiocre plutôt que rien**. Les rejets
  de Jojont54 deviennent des replis (-1 000 000, en dernier dans le palier
  de langue), sauf les cas rédhibitoires (3D, CAM, remux, codecs
  illisibles…), rejetés (-100 000 000). Score minimum -9 000 000 : les
  releases sans palier de qualité passent aussi, en dernier ;
- `40.mises-a-niveau.sql` : arrêt une fois la MULTi au palier de qualité
  visé, gain minimum de 20 000 (Jojont54 : seuil jamais atteint, gain de
  1, chaque petit bonus relançant un téléchargement) ;
- `50.interface.sql` : modifications faites auparavant dans l'interface de
  Profilarr (« 2160p WEB-DL » à 0 dans « 2160p Compact FR »).

**Langues fiables à l'import.** Constaté dans Sonarr/Radarr (code de
`AggregateLanguage` et de `CustomFormatCalculationService`) :
- à l'import, les langues viennent du nom du fichier, du dossier, du
  torrent, puis **des pistes audio** (MediaInfo), la dernière source non
  vide l'emportant ; une piste `und` est ignorée ;
- langue inconnue = langue originale de l'œuvre (recherche comme import) ;
- le nom testé par les formats est celui de la release si Sonarr l'a
  gardé, sinon celui du fichier (cas des packs de saison) ;
- conditions d'un même type : toutes les obligatoires, et au moins une
  satisfaite, une négation satisfaite comptant. Une condition facultative
  à côté d'une négation obligatoire ne sert donc à rien.

D'où des formats de langue fondés sur les langues détectées (réglage
« Multi Languages » des indexeurs FR à la recherche, pistes audio à
l'import), le nom ne servant que de complément. Limite connue : un pack de
saison `…S03.MULTI…` dont la piste française est en `und` et les fichiers
sans `MULTI` dans le nom n'a plus que la VO à l'import ; vu comme une mise
à niveau, il reste bloqué en « Not a Custom Format upgrade ».

**Transition** : avec la langue dominante, les fichiers en VF seule
deviendront améliorables en MULTi. Encadrer la bascule (recherches de mise
à niveau de Profilarr suspendues au début) pour éviter une vague de
téléchargements. Le reste de la bascule (autres bases liées dans
Profilarr, profils attribués) relève de l'installation : voir le chantier
« Profils de qualité » du dépôt `stacks`.

## Tests

- `python outils/compiler.py` : rejoue schéma, `ops/` et `tweaks/` dans
  une base SQLite en mémoire (comme Profilarr), s'arrête à la première
  erreur et peut écrire le résultat (`--sortie base.db`) ; signale les
  instructions de `tweaks/` qui ne touchent plus aucune ligne.
- `python outils/comparer.py [référence]` : nos profils avant et après
  fusion de `upstream/stable` (ou de la référence), sans toucher à la
  copie de travail.
- `python outils/scores.py "<nom de release>"` : score du nom dans nos
  profils, formats évalués d'après la base compilée, nom analysé par
  Radarr (`--arr sonarr` pour Sonarr) ; `--langues French,English` impose
  les langues vues sur un indexeur français ou à l'import. Variables
  `RADARR_URL`, `RADARR_API_KEY`, `SONARR_URL`, `SONARR_API_KEY`
  (variables d'environnement utilisateur, jamais lues dans les
  `config.xml` des serveurs) ; module Python `regex`.
- `python outils/scores.py --verifier` : sur des releases synthétiques
  (chaque qualité active, codecs, marqueurs, bonus), la qualité ne doit
  jamais faire passer une langue devant une autre. Doit afficher
  « 0 écart(s) », à vérifier après chaque mise à jour de Jojont54.
- Sonarr et Radarr, en lecture seule : `GET /api/v3/parse?title=…`
  (formats reconnus pour un nom de release, comme à la recherche) et
  `GET /api/v3/manualimport?folder=…` (langues, formats et score calculés
  à l'import, sans rien importer).
- Profilarr : testeur de noms de release (conteneur `profilarr-parser`).
