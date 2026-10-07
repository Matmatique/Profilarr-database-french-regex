"""Score de noms de release dans nos profils, d'après la base compilée.

Compile la base (comme `compiler.py`), fait analyser chaque nom par
Radarr ou Sonarr (`GET /api/v3/parse` : qualité, groupe, langues, langue
originale de l'œuvre si elle est dans la bibliothèque), puis évalue
lui-même les formats de la base et additionne les scores de chaque profil,
comme Radarr et Sonarr le feraient avec cette base.

    python outils/scores.py "Dune.Part.Two.2024.MULTi.2160p.WEB-DL.H265-FW"
    python outils/scores.py --arr sonarr --langues French,English "Serie.S01..."
    python outils/scores.py --verifier

Adresse et clé d'API dans les variables d'environnement RADARR_URL,
RADARR_API_KEY, SONARR_URL et SONARR_API_KEY (lecture seule).

`/parse` ne connaît pas l'indexeur : une MULTi n'y a que les langues lues
dans le nom. `--langues` impose la liste vue à la recherche sur un
indexeur français (français + langue originale) ou à l'import (pistes
audio). `--vo` impose la langue originale, `--taille` la taille (Gio).

Évaluation reprise de Radarr et Sonarr (`CustomFormatCalculationService`) :
conditions regroupées par type ; dans chaque groupe, toutes les conditions
obligatoires et au moins une condition doivent être satisfaites. Motifs
insensibles à la casse, module `regex` (lookbehind de largeur variable,
comme .NET) : `pip install regex`.
"""

import argparse
import json
import os
import sqlite3
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass, field

import regex

from compiler import RACINE, compiler

PROFILS = ("4K · VF", "4K · VO", "4K Cinéma", "Compact · VF", "Compact · VO", "Anime")

# Sources de Radarr et Sonarr → vocabulaire de Profilarr
SOURCES = {
    "webdl": "web_dl", "web": "web_dl", "webrip": "webrip", "webRip": "webrip",
    "bluray": "bluray", "blurayRaw": "bluray_raw", "tv": "television",
    "television": "television", "televisionRaw": "television", "dvd": "dvd",
}


@dataclass
class Release:
    titre: str
    arr: str = "radarr"
    qualite: str | None = None         # "WEBDL-2160p"
    resolution: str | None = None      # "2160p"
    source: str | None = None          # vocabulaire de Profilarr : "web_dl"…
    modificateur: str | None = None    # "remux", "brdisk"
    groupe: str | None = None
    langues: list[str] = field(default_factory=list)
    vo: str | None = None              # langue originale de l'œuvre
    pack: bool = False                 # pack de saison
    taille: float | None = None        # Gio


def analyser(titre: str, arr: str) -> Release:
    """Release analysée par l'API de Radarr ou Sonarr."""
    prefixe = arr.upper()
    url, cle = os.environ.get(f"{prefixe}_URL"), os.environ.get(f"{prefixe}_API_KEY")
    if not url or not cle:
        sys.exit(f"Variables {prefixe}_URL et {prefixe}_API_KEY nécessaires")
    requete = urllib.request.Request(f"{url.rstrip('/')}/api/v3/parse?title={urllib.parse.quote(titre)}", headers={"X-Api-Key": cle})
    with urllib.request.urlopen(requete) as r:
        d = json.load(r)
    info = d.get("parsedMovieInfo") or d.get("parsedEpisodeInfo") or {}
    qualite = info.get("quality", {}).get("quality", {})
    oeuvre = d.get("movie") or d.get("series") or {}
    modificateur = qualite.get("modifier")
    return Release(
        titre=titre,
        arr=arr,
        qualite=qualite.get("name"),
        resolution=f"{qualite['resolution']}p" if qualite.get("resolution") else None,
        source=SOURCES.get(qualite.get("source")),
        modificateur=modificateur if modificateur not in (None, "none") else None,
        groupe=info.get("releaseGroup"),
        langues=[l["name"] for l in d.get("languages", [])],
        vo=oeuvre.get("originalLanguage", {}).get("name"),
        pack=bool(info.get("fullSeason")),
    )


class Base:
    def __init__(self, db: sqlite3.Connection):
        self.db = db
        self.motifs = {}
        self.conditions = {}
        for cf, nom, type_, arr, negate, requis in db.execute(
                "SELECT custom_format_name, name, type, arr_type, negate, required FROM custom_format_conditions ORDER BY id"):
            self.conditions.setdefault(cf, []).append((nom, type_, arr, negate, requis))
        self.valeurs = {}
        requetes = {  # motifs : titre et groupe de release
            "motif": "SELECT c.custom_format_name, c.condition_name, r.pattern FROM condition_patterns c JOIN regular_expressions r ON r.name = c.regular_expression_name",
            "language": "SELECT custom_format_name, condition_name, language_name, except_language FROM condition_languages",
            "source": "SELECT custom_format_name, condition_name, source FROM condition_sources",
            "resolution": "SELECT custom_format_name, condition_name, resolution FROM condition_resolutions",
            "quality_modifier": "SELECT custom_format_name, condition_name, quality_modifier FROM condition_quality_modifiers",
            "release_type": "SELECT custom_format_name, condition_name, release_type FROM condition_release_types",
            "size": "SELECT custom_format_name, condition_name, min_bytes, max_bytes FROM condition_sizes",
        }
        for type_, sql in requetes.items():
            for cf, nom, *v in db.execute(sql):
                self.valeurs[(cf, nom)] = v

    def motif(self, texte: str):
        if texte not in self.motifs:
            self.motifs[texte] = regex.compile(texte, regex.IGNORECASE)
        return self.motifs[texte]

    def condition(self, cf: str, nom: str, type_: str, r: Release) -> bool:
        v = self.valeurs.get((cf, nom))
        if type_ in ("release_title", "release_group"):
            if v is None:
                return False
            cible = r.titre if type_ == "release_title" else r.groupe
            return bool(cible) and bool(self.motif(v[0]).search(cible))
        if type_ == "language":
            langue, sauf = v
            if langue == "Original":
                langue = r.vo or "Original"
            if sauf:
                return any(l != langue for l in r.langues)
            return langue in r.langues
        if type_ == "source":
            return r.source == v[0]
        if type_ == "resolution":
            return r.resolution == v[0]
        if type_ == "quality_modifier":
            return r.modificateur == v[0]
        if type_ == "release_type":
            return r.pack and v[0] == "season_pack"
        if type_ == "size":
            if r.taille is None:
                return False
            octets = r.taille * 1024 ** 3
            return (v[0] is None or octets > v[0]) and (v[1] is None or octets <= v[1])
        return False

    def correspond(self, cf: str, r: Release) -> bool:
        groupes = {}
        for nom, type_, arr, negate, requis in self.conditions.get(cf, []):
            if arr not in ("all", r.arr):
                continue
            ok = self.condition(cf, nom, type_, r) != bool(negate)
            groupes.setdefault(type_, []).append((ok, requis))
        if not groupes:
            return False
        return all(any(ok for ok, _ in g) and all(ok for ok, requis in g if requis) for g in groupes.values())

    def scores(self, profil: str, arr: str) -> dict[str, int]:
        """Score de chaque format dans le profil ; la ligne propre à l'arr l'emporte sur « all »."""
        lignes = {}
        for cf, a, score in self.db.execute(
                "SELECT custom_format_name, arr_type, score FROM quality_profile_custom_formats WHERE quality_profile_name = ? AND arr_type IN ('all', ?) ORDER BY arr_type = 'all'",
                (profil, arr)):
            lignes.setdefault(cf, score)
        return lignes

    def qualites(self, profil: str) -> set[str]:
        """Qualités actives du profil, seules ou dans un groupe actif."""
        return {q for (q,) in self.db.execute(
            "SELECT quality_name FROM quality_profile_qualities WHERE quality_profile_name = ? AND enabled = 1 AND quality_name IS NOT NULL "
            "UNION SELECT m.quality_name FROM quality_group_members m JOIN quality_profile_qualities q "
            "ON q.quality_profile_name = m.quality_profile_name AND q.quality_group_name = m.quality_group_name "
            "WHERE m.quality_profile_name = ? AND q.enabled = 1", (profil, profil))}

    def minimum(self, profil: str) -> int:
        return self.db.execute("SELECT minimum_custom_format_score FROM quality_profiles WHERE name = ?", (profil,)).fetchone()[0]

    def evaluer(self, r: Release, profils=PROFILS):
        """{profil: (score, formats comptés)}."""
        resultat = {}
        for p in profils:
            comptes = {cf: s for cf, s in self.scores(p, r.arr).items() if s and self.correspond(cf, r)}
            resultat[p] = (sum(comptes.values()), comptes)
        return resultat


# Qualités → (résolution, source, étiquette dans le nom), pour --verifier
QUALITES = {
    "WEBDL-2160p": ("2160p", "web_dl", "WEB-DL"), "WEBRip-2160p": ("2160p", "webrip", "WEBRip"),
    "Bluray-2160p": ("2160p", "bluray", "BluRay"), "HDTV-2160p": ("2160p", "television", "HDTV"),
    "WEBDL-1080p": ("1080p", "web_dl", "WEB-DL"), "WEBRip-1080p": ("1080p", "webrip", "WEBRip"),
    "Bluray-1080p": ("1080p", "bluray", "BluRay"), "HDTV-1080p": ("1080p", "television", "HDTV"),
    "WEBDL-720p": ("720p", "web_dl", "WEB-DL"), "WEBRip-720p": ("720p", "webrip", "WEBRip"),
    "Bluray-720p": ("720p", "bluray", "BluRay"), "HDTV-720p": ("720p", "television", "HDTV"),
    "Bluray-576p": ("576p", "bluray", "BluRay"), "Bluray-480p": ("480p", "bluray", "BluRay"),
    "WEBDL-480p": ("480p", "web_dl", "WEB-DL"), "WEBRip-480p": ("480p", "webrip", "WEBRip"),
    "DVD": ("480p", "dvd", "DVDRip"), "SDTV": ("480p", "television", "SDTV"),
}


# Bande de la qualité (score sans les formats « Langue ») d'une release
# acceptée : les paliers de langue sont espacés de 10 000 000.
BANDE = (-9_000_000, 1_000_000)


def verifier(base: Base, profils) -> int:
    """Releases synthétiques dont la qualité sortirait de sa bande.

    Pour chaque qualité active du profil : variantes de codec, de marqueur
    light (en HD), avec ou sans source dans le nom (sans source, Sonarr et
    Radarr supposent souvent HDTV), avec ou sans bonus (équipe de tête,
    Dolby Vision, HDR, audio). Le score sans les formats « Langue » doit
    rester dans BANDE, sinon la qualité ferait passer une langue devant une
    autre ; ou bien être assez bas pour que la release soit rejetée quel que
    soit son palier de langue.
    """
    ecarts = 0
    for arr in ("radarr", "sonarr"):
        for p in profils:
            langue = {cf: s for cf, s in base.scores(p, arr).items() if cf.startswith("Langue ") and s > 0}
            langue_max = max(langue.get("Langue MULTi", 0), langue.get("Langue VF", 0),
                             langue.get("Langue VO", 0) + max(langue.get(f, 0) for f in ("Langue VOSTFR", "Langue VOSTFR (MULTiSUB)", "Langue VOSTFR (groupe)")))
            for q in sorted(base.qualites(p)):
                if q not in QUALITES:
                    print(f"  {arr} {p} : qualité {q} non testée")
                    continue
                resolution, source, etiquette = QUALITES[q]
                marqueurs = ("", "HDLight.", "4KLight.") if resolution in ("2160p", "1080p", "720p") else ("",)
                for marqueur in marqueurs:
                    for codec in ("x264", "x265", "H264", "H265"):
                        for nom in (f"{etiquette}.", ""):
                            for bonus, groupe in (("", "GRP"), ("DV.HDR.TrueHD.Atmos.", "FW")):
                                r = Release(titre=f"Titre.2024.MULTi.{resolution}.{nom}{marqueur}{bonus}{codec}-{groupe}", arr=arr,
                                            resolution=resolution, source=source, groupe=groupe, langues=["French", "English"], vo="English")
                                total, comptes = base.evaluer(r, [p])[p]
                                qualite = total - sum(s for cf, s in comptes.items() if cf.startswith("Langue "))
                                if not (BANDE[0] <= qualite < BANDE[1] or qualite + langue_max < base.minimum(p)):
                                    ecarts += 1
                                    print(f"  {arr} {p} : {r.titre}  qualité {nombre(qualite)}")
    print(f"{ecarts} écart(s)")
    return ecarts


def nombre(n: int, signe=False) -> str:
    return f"{n:{'+' if signe else ''},}".replace(",", " ")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("titres", nargs="*")
    parser.add_argument("--verifier", action="store_true", help="vérifie que la qualité ne fait jamais passer une langue devant une autre")
    parser.add_argument("--arr", choices=("radarr", "sonarr"), default="radarr")
    parser.add_argument("--langues", help="langues imposées, séparées par des virgules (French,English)")
    parser.add_argument("--vo", help="langue originale imposée (English)")
    parser.add_argument("--taille", type=float, help="taille en Gio")
    parser.add_argument("--profils", help="profils, séparés par des virgules (défaut : les nôtres)")
    parser.add_argument("--racine", default=RACINE)
    args = parser.parse_args()

    base = Base(compiler(args.racine))
    profils = args.profils.split(",") if args.profils else PROFILS
    if args.verifier:
        sys.exit(1 if verifier(base, profils) else 0)
    for titre in args.titres:
        r = analyser(titre, args.arr)
        if args.langues:
            r.langues = args.langues.split(",")
        if args.vo:
            r.vo = args.vo
        r.taille = args.taille
        print(f"\n{titre}\n  {r.qualite} groupe={r.groupe} langues={r.langues} vo={r.vo}")
        for p, (score, comptes) in base.evaluer(r, profils).items():
            refus = "  QUALITÉ EXCLUE" if r.qualite not in base.qualites(p) else "  REJETÉ" if score < base.minimum(p) else ""
            detail = ", ".join(f"{cf} {nombre(s, True)}" for cf, s in sorted(comptes.items(), key=lambda x: -abs(x[1])))
            print(f"  {p:<14} {nombre(score):>12}{refus}   {detail}")


if __name__ == "__main__":
    main()
