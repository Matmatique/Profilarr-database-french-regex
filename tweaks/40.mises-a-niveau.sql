-- Mises à niveau raisonnables (objectif C du CLAUDE.md).
--
-- Jojont54 : seuil d'arrêt à 1 000 000 (jamais atteint) et gain minimum
-- de 1, chaque petit bonus relançant un téléchargement. Ici, arrêt une fois
-- la MULTi obtenue au palier de qualité visé, et gain minimum de 20 000 :
-- un changement de palier de qualité (+30 000 en général) ou de langue
-- (+10 000 000), jamais un simple bonus (équipe, service, audio, HDR).
--
-- Compact : le HDLight reste préféré au téléchargement, mais un fichier
-- MULTi déjà correct (WEB-DL ou encode de Blu-ray 1080p) n'est pas remplacé
-- pour gagner quelques Go (décision du 9 octobre 2026).
-- 4K · VF et 4K · VO : même principe, le WEB-DL 2160p reste préféré au
-- téléchargement, mais un encode de Blu-ray 2160p MULTi en place
-- (4KLight compris) n'est pas remplacé (même jour).

WITH seuils(profil, seuil) AS (VALUES
    ('4K · VF', 20905000),       -- MULTi + encode de Blu-ray 2160p HEVC
    ('4K · VO', 20905000),
    ('4K Cinéma', 20940000),     -- MULTi + 2160p Bluray HEVC
    ('Compact · VF', 20850000),  -- MULTi + 1080p WEB-DL AVC, pénalité de taille comprise
    ('Compact · VO', 20850000),
    ('Anime', 30860000)          -- MULTi + 1080p WEB-DL
)
UPDATE quality_profiles
SET upgrade_until_score = (SELECT seuil FROM seuils WHERE profil = name),
    upgrade_score_increment = 20000
WHERE name IN (SELECT profil FROM seuils);

-- Écran sans HDR10+ : bonus inutile.
UPDATE quality_profile_custom_formats SET score = 0
WHERE quality_profile_name IN ('4K · VF', '4K · VO', '4K Cinéma')
  AND custom_format_name = 'HDR10+';

-- Compact : un encode de Blu-ray 1080p (ni HDLight, ni remux) vaut un
-- WEB-DL AVC. « 1080p Bluray » de Jojont54 ne convient pas : il reconnaît
-- aussi les HDLight, qui seraient comptés deux fois.
INSERT INTO custom_formats (name, description) VALUES
    ('1080p Bluray (encode)', 'Encode de Blu-ray 1080p qui n''est ni un HDLight ni un remux (profils Compact).');

INSERT INTO custom_format_conditions (custom_format_name, name, type, negate, required) VALUES
    ('1080p Bluray (encode)', '1080p', 'resolution', 0, 1),
    ('1080p Bluray (encode)', 'Bluray', 'source', 0, 1),
    ('1080p Bluray (encode)', 'Sans remux', 'release_title', 1, 1),
    ('1080p Bluray (encode)', 'Sans HDLight', 'release_title', 1, 1);

INSERT INTO condition_resolutions (custom_format_name, condition_name, resolution) VALUES
    ('1080p Bluray (encode)', '1080p', '1080p');
INSERT INTO condition_sources (custom_format_name, condition_name, source) VALUES
    ('1080p Bluray (encode)', 'Bluray', 'bluray');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES
    ('1080p Bluray (encode)', 'Sans remux', 'Remux'),
    ('1080p Bluray (encode)', 'Sans HDLight', 'HDLight');

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES
    ('Compact · VF', '1080p Bluray (encode)', 'all', 860000),
    ('Compact · VO', '1080p Bluray (encode)', 'all', 860000);

-- 4K · VF et 4K · VO : Jojont54 ne note que le WEB-DL 2160p (« 2160p
-- Balanced FR ») et pénalise le 4KLight. Un encode de Blu-ray 2160p HEVC
-- vaut 905 000, sous le WEB-DL HEVC (920 000) et au-dessus d'un 1080p
-- Bluray, bonus compris (890 000 + 14 000 au plus : équipe, DV, IMAX,
-- édition, DTS:X…) ; plus de pénalité 4KLight.
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES
    ('4K · VF', '2160p Bluray HEVC', 'all', 905000),
    ('4K · VO', '2160p Bluray HEVC', 'all', 905000);

UPDATE quality_profile_custom_formats SET score = 0
WHERE quality_profile_name IN ('4K · VF', '4K · VO') AND custom_format_name = '4KLight';

-- Profils 4K : le nom de fichier ne dit pas toujours le codec (épisodes
-- d'un pack de saison, nommés « Série S01E01 - Titre.mkv »), et Sonarr juge
-- alors le fichier sur ce nom : « 2160p WEB-DL HEVC » ou « 2160p Bluray
-- HEVC » ne se déclenchent pas, et une 4K retombe sous le 1080p en place
-- (constaté le 10 octobre 2026 sur un pack de South Park). Une 2160p sans
-- codec dans le nom vaut 905 000, comme un encode de Blu-ray 2160p.
INSERT INTO custom_formats (name, description) VALUES
    ('2160p (codec absent du nom)', '2160p dont le nom ne cite ni HEVC ni x264 (fichiers d''un pack de saison) : profils 4K.');

INSERT INTO custom_format_conditions (custom_format_name, name, type, negate, required) VALUES
    ('2160p (codec absent du nom)', '2160p', 'resolution', 0, 1),
    ('2160p (codec absent du nom)', 'Sans HEVC', 'release_title', 1, 1),
    ('2160p (codec absent du nom)', 'Sans x264', 'release_title', 1, 1);

INSERT INTO condition_resolutions (custom_format_name, condition_name, resolution) VALUES
    ('2160p (codec absent du nom)', '2160p', '2160p');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES
    ('2160p (codec absent du nom)', 'Sans HEVC', 'HEVC'),
    ('2160p (codec absent du nom)', 'Sans x264', 'x264');

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES
    ('4K · VF', '2160p (codec absent du nom)', 'all', 905000),
    ('4K · VO', '2160p (codec absent du nom)', 'all', 905000),
    ('4K Cinéma', '2160p (codec absent du nom)', 'all', 905000);

-- Profils 4K : toutes les sources 1080p au même score (Jojont54 : Bluray
-- 890 000, WEB-DL 860 000, WEBRip 850 000). En attendant la 4K, un 1080p
-- ne remplace plus un autre 1080p, sauf pour la langue (constaté le
-- 10 octobre 2026 : WEB-DL 1080p remplacé par un Blu-ray 1080p). 880 000
-- laisse le 1080p sous le seuil de la 4K, bonus compris (20 000 au plus).
UPDATE quality_profile_custom_formats SET score = 880000
WHERE quality_profile_name IN ('4K · VF', '4K · VO', '4K Cinéma')
  AND custom_format_name IN ('1080p Bluray', '1080p WEB-DL', '1080p WEBRip');
