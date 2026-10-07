-- Modifications faites jusqu'ici dans l'interface de Profilarr, reprises
-- ici pour ne plus dépendre de réglages non versionnés.

-- « 2160p Compact FR » (profil demandé aujourd'hui par Seerr) : les
-- 2160p WEB-DL ne sont plus rejetées (Jojont54 : -999 999).
UPDATE quality_profile_custom_formats SET score = 0
WHERE quality_profile_name = '2160p Compact FR' AND custom_format_name = '2160p WEB-DL';
