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

WITH seuils(profil, seuil) AS (VALUES
    ('4K · VF', 20920000),       -- MULTi + 2160p WEB-DL HEVC
    ('4K · VO', 20920000),
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
