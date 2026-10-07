"""Compare nos profils avant et après la fusion d'une mise à jour de Jojont54.

Compile la base telle qu'elle est (`--avant`, défaut HEAD) et telle
qu'elle serait après fusion de la référence donnée (défaut
`upstream/stable`), sans toucher à la copie de travail : l'arbre fusionné
vient de `git merge-tree` et est extrait dans un dossier temporaire.

    python outils/comparer.py                      HEAD contre HEAD + upstream/stable
    python outils/comparer.py upstream/develop     ce qui arrive ensuite
    python outils/comparer.py --avant 1608a48 HEAD deux états du dépôt

Signale, pour nos profils (et ceux que nos tweaks modifient) :
- réglages (score minimum, seuil et gain de mise à niveau) et qualités ;
- scores de formats ajoutés, retirés ou changés ; un nouveau repli
  (-1 000 000) est un rejet ajouté par Jojont54, à classer (30.rejets.sql) ;
- formats notés dont les conditions ont changé, motifs modifiés ;
- instructions de `tweaks/` sans effet après fusion ;
- écarts de `scores.py --verifier` après fusion.
"""

import argparse
import io
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

import compiler
from compiler import RACINE
from scores import PROFILS, Base, verifier

# Profils de Jojont54 modifiés par nos tweaks (50.interface.sql)
AUTRES = ("2160p Compact FR",)


def git(*args: str) -> bytes:
    return subprocess.run(["git", "-C", str(RACINE), *args], check=True, capture_output=True).stdout


def extraire(arbre: str, dossier: Path) -> Path:
    tarfile.open(fileobj=io.BytesIO(git("archive", arbre)), mode="r:").extractall(dossier, filter="data")
    return dossier


def arbre(avant: str, apres: str | None) -> str:
    """Arbre de `avant`, ou de la fusion de `apres` dans `avant`."""
    if apres is None:
        return avant
    sortie = subprocess.run(["git", "-C", str(RACINE), "merge-tree", "--write-tree", avant, apres], capture_output=True, text=True)
    if sortie.returncode != 0:
        sys.exit(f"Conflits de fusion :\n{sortie.stdout}")
    return sortie.stdout.split()[0]


def compiler_arbre(reference: str, dossier: Path):
    compiler.MUETTES.clear()
    db = compiler.compiler(extraire(reference, dossier))
    return db, list(compiler.MUETTES)


def profils(db, noms):
    """{profil: {"réglages": …, "qualités": …, "scores": {(format, arr): score}}}."""
    resultat = {}
    for p in noms:
        reglages = db.execute(
            "SELECT minimum_custom_format_score, upgrade_until_score, upgrade_score_increment, upgrades_allowed FROM quality_profiles WHERE name = ?", (p,)).fetchone()
        if reglages is None:
            continue
        qualites = []
        for q, g, actif in db.execute(
                "SELECT quality_name, quality_group_name, enabled FROM quality_profile_qualities WHERE quality_profile_name = ? ORDER BY position", (p,)):
            if g:
                membres = [m for (m,) in db.execute(
                    "SELECT quality_name FROM quality_group_members WHERE quality_profile_name = ? AND quality_group_name = ? ORDER BY position", (p, g))]
                qualites.append(f"{'' if actif else '(désactivé) '}[{', '.join(membres)}]")
            elif actif:
                qualites.append(q)
        scores = {(cf, arr): s for cf, arr, s in db.execute(
            "SELECT custom_format_name, arr_type, score FROM quality_profile_custom_formats WHERE quality_profile_name = ?", (p,))}
        resultat[p] = {"réglages": reglages, "qualités": qualites, "scores": scores}
    return resultat


def definitions(db) -> dict[str, list]:
    """Empreinte de chaque format : conditions et leurs valeurs (motifs par leur nom)."""
    tables = {
        "condition_patterns": "regular_expression_name", "condition_languages": "language_name, except_language",
        "condition_sources": "source", "condition_resolutions": "resolution",
        "condition_quality_modifiers": "quality_modifier", "condition_release_types": "release_type",
        "condition_sizes": "min_bytes, max_bytes", "condition_indexer_flags": "flag",
    }
    valeurs = {}
    for table, colonnes in tables.items():
        for cf, nom, *v in db.execute(f"SELECT custom_format_name, condition_name, {colonnes} FROM {table}"):
            valeurs[(cf, nom)] = tuple(v)
    empreintes = {}
    for cf, nom, type_, arr, negate, requis in db.execute(
            "SELECT custom_format_name, name, type, arr_type, negate, required FROM custom_format_conditions"):
        v = valeurs.get((cf, nom), ())
        empreintes.setdefault(cf, []).append((nom, type_, arr, negate, requis, v))
    return {cf: sorted(c) for cf, c in empreintes.items()}


def nombre(n) -> str:
    return f"{n:,}".replace(",", " ") if isinstance(n, int) else str(n)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("apres", nargs="?", default="upstream/stable", help="référence fusionnée (défaut : upstream/stable)")
    parser.add_argument("--avant", default="HEAD", help="état de départ (défaut : HEAD)")
    parser.add_argument("--sans-fusion", action="store_true", help="comparer avec la référence telle quelle, sans la fusionner")
    args = parser.parse_args()

    apres = args.apres if args.sans_fusion else arbre(args.avant, args.apres)
    with tempfile.TemporaryDirectory() as tmp:
        db_avant, _ = compiler_arbre(args.avant, Path(tmp, "avant"))
        db_apres, muettes = compiler_arbre(apres, Path(tmp, "apres"))

    noms = PROFILS + AUTRES
    p_avant, p_apres = profils(db_avant, noms), profils(db_apres, noms)
    d_avant, d_apres = definitions(db_avant), definitions(db_apres)
    notes = set()
    m_avant = dict(db_avant.execute("SELECT name, pattern FROM regular_expressions"))
    m_apres = dict(db_apres.execute("SELECT name, pattern FROM regular_expressions"))
    motifs = {}  # motif modifié → formats notés qui l'utilisent
    for p in noms:
        if p not in p_apres:
            print(f"\n## {p} : ABSENT après fusion")
            continue
        a, b = p_avant.get(p), p_apres[p]
        lignes = []
        if a and a["réglages"] != b["réglages"]:
            lignes.append(f"réglages (minimum, seuil, gain, mises à niveau) : {a['réglages']} → {b['réglages']}")
        if a and a["qualités"] != b["qualités"]:
            lignes.append(f"qualités :\n      avant {a['qualités']}\n      après {b['qualités']}")
        sa, sb = (a or {"scores": {}})["scores"], b["scores"]
        for cle in sorted(set(sa) | set(sb)):
            if sa.get(cle) != sb.get(cle):
                repli = "   ← nouveau repli : rejet de Jojont54 à classer" if sb.get(cle) == -1000000 and sa.get(cle) != -1000000 else ""
                lignes.append(f"{cle[0]} ({cle[1]}) : {nombre(sa.get(cle, '—'))} → {nombre(sb.get(cle, '—'))}{repli}")
        for (cf, _), score in sb.items():
            if not score:
                continue
            if d_avant.get(cf) != d_apres.get(cf):
                notes.add(cf)
            for nom, type_, *_, v in d_apres.get(cf, []):
                if type_ in ("release_title", "release_group") and v and m_avant.get(v[0]) != m_apres.get(v[0]):
                    motifs.setdefault(v[0], set()).add(cf)
        print(f"\n## {p}")
        print("\n".join(f"  - {l}" for l in lignes) if lignes else "  inchangé")

    print("\n## Formats notés dont les conditions changent")
    for cf in sorted(notes):
        print(f"  - {cf}" + (" (nouveau)" if cf not in d_avant else ""))
        for c in sorted(set(d_avant.get(cf, [])) ^ set(d_apres.get(cf, []))):
            print(f"      {'+' if c in d_apres.get(cf, []) else '-'} {c}")
    if not notes:
        print("  aucun")

    print("\n## Motifs modifiés (formats notés qui les utilisent)")
    for nom in sorted(motifs):
        print(f"  - {nom} : {', '.join(sorted(motifs[nom]))}\n      avant {m_avant.get(nom)}\n      après {m_apres.get(nom)}")
    if not motifs:
        print("  aucun")

    print("\n## Tweaks sans effet après fusion")
    print("\n".join(f"  - {m}" for m in muettes) if muettes else "  aucun")

    print("\n## Vérification des paliers après fusion")
    verifier(Base(db_apres), PROFILS)


if __name__ == "__main__":
    main()
