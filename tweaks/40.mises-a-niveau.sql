-- Mises à niveau raisonnables (objectif C du CLAUDE.md).
--
-- Jojont54 : seuil d'arrêt à 1 000 000 (jamais atteint) et gain minimum
-- de 1, chaque petit bonus relançant un téléchargement. Ici, arrêt une fois
-- la MULTi obtenue au palier de qualité visé, et gain minimum de 20 000 :
-- un changement de palier de qualité (+30 000 en général) ou de langue
-- (+10 000 000), jamais un simple bonus (équipe, service, audio, HDR).

WITH seuils(profil, seuil) AS (VALUES
    ('4K · VF', 20920000),       -- MULTi + 2160p WEB-DL HEVC
    ('4K · VO', 20920000),
    ('4K Cinéma', 20940000),     -- MULTi + 2160p Bluray HEVC
    ('Compact · VF', 20930000),  -- MULTi + 1080p HDLight WEBRip
    ('Compact · VO', 20930000),
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
