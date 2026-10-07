-- Nos six profils, copiés des profils de Jojont54 à chaque compilation :
-- qualités, formats et scores suivent ainsi ses mises à jour, nos
-- changements (fichiers suivants) s'appliquant par-dessus.
--
-- Chaque instruction répète la table de correspondance (nom, base).

WITH copie(nom, base, description) AS (VALUES
    ('4K · VF', '2160p Balanced FR', '2160p WEB-DL. MULTi > VF > VO.'),
    ('4K · VO', '2160p Balanced FR', '2160p WEB-DL. MULTi > VO > VF.'),
    ('4K Cinéma', '2160p Quality FR', 'Encodes de Blu-ray UHD. MULTi > VO > VF.'),
    ('Compact · VF', '1080p Compact FR', 'HDLight 1080p. MULTi > VF > VO.'),
    ('Compact · VO', '1080p Compact FR', 'HDLight 1080p. MULTi > VO > VF.'),
    ('Anime', 'Anime 1080p FR', 'Anime 1080p. MULTi > VOSTFR > VF.')
)
INSERT INTO quality_profiles (name, description, upgrades_allowed, minimum_custom_format_score, upgrade_until_score, upgrade_score_increment)
SELECT c.nom, c.description, p.upgrades_allowed, p.minimum_custom_format_score, p.upgrade_until_score, p.upgrade_score_increment
FROM copie c JOIN quality_profiles p ON p.name = c.base;

WITH copie(nom, base) AS (VALUES
    ('4K · VF', '2160p Balanced FR'), ('4K · VO', '2160p Balanced FR'),
    ('4K Cinéma', '2160p Quality FR'),
    ('Compact · VF', '1080p Compact FR'), ('Compact · VO', '1080p Compact FR'),
    ('Anime', 'Anime 1080p FR')
)
INSERT INTO quality_profile_tags (quality_profile_name, tag_name)
SELECT c.nom, t.tag_name
FROM copie c JOIN quality_profile_tags t ON t.quality_profile_name = c.base;

WITH copie(nom, base) AS (VALUES
    ('4K · VF', '2160p Balanced FR'), ('4K · VO', '2160p Balanced FR'),
    ('4K Cinéma', '2160p Quality FR'),
    ('Compact · VF', '1080p Compact FR'), ('Compact · VO', '1080p Compact FR'),
    ('Anime', 'Anime 1080p FR')
)
INSERT INTO quality_profile_languages (quality_profile_name, language_name, type)
SELECT c.nom, l.language_name, l.type
FROM copie c JOIN quality_profile_languages l ON l.quality_profile_name = c.base;

-- Le groupe de qualités qui porte le nom du profil de base prend le nôtre.
WITH copie(nom, base) AS (VALUES
    ('4K · VF', '2160p Balanced FR'), ('4K · VO', '2160p Balanced FR'),
    ('4K Cinéma', '2160p Quality FR'),
    ('Compact · VF', '1080p Compact FR'), ('Compact · VO', '1080p Compact FR'),
    ('Anime', 'Anime 1080p FR')
)
INSERT INTO quality_groups (quality_profile_name, name)
SELECT c.nom, CASE WHEN g.name = c.base THEN c.nom ELSE g.name END
FROM copie c JOIN quality_groups g ON g.quality_profile_name = c.base;

WITH copie(nom, base) AS (VALUES
    ('4K · VF', '2160p Balanced FR'), ('4K · VO', '2160p Balanced FR'),
    ('4K Cinéma', '2160p Quality FR'),
    ('Compact · VF', '1080p Compact FR'), ('Compact · VO', '1080p Compact FR'),
    ('Anime', 'Anime 1080p FR')
)
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position)
SELECT c.nom, CASE WHEN m.quality_group_name = c.base THEN c.nom ELSE m.quality_group_name END, m.quality_name, m.position
FROM copie c JOIN quality_group_members m ON m.quality_profile_name = c.base;

WITH copie(nom, base) AS (VALUES
    ('4K · VF', '2160p Balanced FR'), ('4K · VO', '2160p Balanced FR'),
    ('4K Cinéma', '2160p Quality FR'),
    ('Compact · VF', '1080p Compact FR'), ('Compact · VO', '1080p Compact FR'),
    ('Anime', 'Anime 1080p FR')
)
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until)
SELECT c.nom, q.quality_name, CASE WHEN q.quality_group_name = c.base THEN c.nom ELSE q.quality_group_name END, q.position, q.enabled, q.upgrade_until
FROM copie c JOIN quality_profile_qualities q ON q.quality_profile_name = c.base;

WITH copie(nom, base) AS (VALUES
    ('4K · VF', '2160p Balanced FR'), ('4K · VO', '2160p Balanced FR'),
    ('4K Cinéma', '2160p Quality FR'),
    ('Compact · VF', '1080p Compact FR'), ('Compact · VO', '1080p Compact FR'),
    ('Anime', 'Anime 1080p FR')
)
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score)
SELECT c.nom, f.custom_format_name, f.arr_type, f.score
FROM copie c JOIN quality_profile_custom_formats f ON f.quality_profile_name = c.base;
