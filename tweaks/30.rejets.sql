-- Rejets et replis.
--
-- Une release médiocre vaut mieux que rien : les rejets de Jojont54
-- (-999 999) deviennent des replis (-1 000 000, accepté en dernier dans son
-- palier de langue), sauf les cas rédhibitoires, rejetés pour de bon
-- (-100 000 000). Un rejet que Jojont54 ajoute devient donc un repli :
-- l'ajouter ici s'il est rédhibitoire.
--
-- Le score minimum (-9 000 000) accepte tout le reste, y compris les
-- releases sans palier de qualité (score de qualité nul), que Jojont54
-- rejetait par son minimum de 20 000.

-- Rejets : illisible ou incompatible (AV1, VP9 et VVC sur les appareils
-- plus anciens, Dolby Vision sans repli HDR10 hors écran Dolby Vision),
-- pas le film (CAM, 3D, extras, versions chantées, noir et blanc,
-- audiodescription), fausse qualité (upscale, Xvid), trop gros (remux,
-- disques complets).
UPDATE quality_profile_custom_formats
SET score = CASE WHEN custom_format_name IN (
        '3D', 'AV1', 'Audio Description', 'B&W', 'CAM', 'Dolby Vision (Without Fallback)',
        'Extras', 'Full Disc', 'Full Disc (Quality Match)', 'Remux', 'Sing Along',
        'Upscale', 'VP9', 'VVC', 'Xvid'
    ) THEN -100000000 ELSE -1000000 END
WHERE quality_profile_name IN ('4K · VF', '4K · VO', '4K Cinéma', 'Compact · VF', 'Compact · VO', 'Anime')
  AND score <= -999999 AND score > -100000000;

-- Dolby Vision sans repli : non noté chez Jojont54 en 1080p.
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score)
SELECT name, 'Dolby Vision (Without Fallback)', 'all', -100000000 FROM quality_profiles
WHERE name IN ('Compact · VF', 'Compact · VO', 'Anime');

UPDATE quality_profiles SET minimum_custom_format_score = -9000000
WHERE name IN ('4K · VF', '4K · VO', '4K Cinéma', 'Compact · VF', 'Compact · VO', 'Anime');
