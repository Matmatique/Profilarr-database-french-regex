"""Compile la base comme Profilarr, pour vérifier qu'elle s'applique.

Rejoue dans une base SQLite en mémoire les couches lues par Profilarr :
schéma (cloné, voir plus bas), base (`ops/`), puis nos `tweaks/`, chaque
dossier trié par le numéro en tête des noms de fichiers. S'arrête à la
première erreur, en nommant le fichier fautif.

    python outils/compiler.py                    compile et liste les profils
    python outils/compiler.py --sortie base.db   écrit aussi le résultat

Les fonctions qp(), cf() et dp() de Profilarr (nom → identifiant) sont
reproduites. Le schéma n'est pas dans le dépôt (Profilarr l'installe dans
`deps/schema`) : le script clone la version indiquée dans `pcd.json` dans
le dossier temporaire du système, une fois par version.
"""

import argparse
import json
import re
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
COUCHES = ("ops", "tweaks")


def fichiers(dossier: Path) -> list[Path]:
    if not dossier.exists():
        return []

    def ordre(f: Path):
        m = re.match(r"(\d+)", f.name)
        return (int(m.group(1)) if m else float("inf"), f.name)

    return sorted(dossier.glob("*.sql"), key=ordre)


def schema(racine: Path) -> Path:
    """Dossier des opérations du schéma, cloné au besoin."""
    deps = json.loads((racine / "pcd.json").read_text(encoding="utf-8"))["dependencies"]
    url, version = next((u, v) for u, v in deps.items() if u.rstrip("/").endswith("/schema"))
    dossier = Path(tempfile.gettempdir()) / "profilarr-schema" / version
    if not dossier.exists():
        subprocess.run(["git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1", "--branch", version, url, str(dossier)], check=True)
    return dossier / "ops"


def compiler(racine: Path) -> sqlite3.Connection:
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys = ON")
    for fonction, table in (("qp", "quality_profiles"), ("cf", "custom_formats"), ("dp", "delay_profiles")):
        def chercher(nom, table=table):
            ligne = db.execute(f"SELECT id FROM {table} WHERE name = ?", (nom,)).fetchone()
            if ligne is None:
                raise ValueError(f"{table} introuvable : {nom}")
            return ligne[0]
        db.create_function(fonction, 1, chercher)

    for f in fichiers(schema(racine)) + [f for c in COUCHES for f in fichiers(racine / c)]:
        try:
            db.executescript(f.read_text(encoding="utf-8"))
        except sqlite3.Error as e:
            sys.exit(f"ERREUR dans {f} : {e}")
    db.commit()
    return db


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--racine", type=Path, default=RACINE, help="dossier de la base (défaut : ce dépôt)")
    parser.add_argument("--sortie", type=Path, help="écrire la base compilée dans ce fichier")
    args = parser.parse_args()

    db = compiler(args.racine)
    if args.sortie:
        args.sortie.unlink(missing_ok=True)
        db.execute("VACUUM INTO ?", (str(args.sortie),))
    for (nom,) in db.execute("SELECT name FROM quality_profiles ORDER BY name"):
        print(nom)


if __name__ == "__main__":
    main()
