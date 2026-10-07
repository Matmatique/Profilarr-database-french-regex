-- La langue avant la qualité (objectifs A et B du CLAUDE.md).
--
-- Échelle de nos profils :
--   paliers de langue, espacés de 10 000 000 (MULTi 20 000 000, langue
--   préférée 10 000 000, l'autre 0 ; l'anime a un palier de plus) ;
--   qualité et bonus de Jojont54 sous 1 000 000 ;
--   repli -1 000 000 par format : accepté faute de mieux (30.rejets.sql) ;
--   rejet -100 000 000 : jamais ; score minimum -9 000 000.
-- Une release acceptée, même avec plusieurs replis, reste ainsi dans la
-- bande de son palier de langue (vérification :
-- `python outils/scores.py --verifier`).
--
-- Les formats se fondent sur les langues détectées par Sonarr et Radarr :
-- à la recherche, nom de la release et réglage « Multi Languages » des
-- indexeurs français (français + langue originale pour une MULTi) ; à
-- l'import, pistes audio (MediaInfo). Langue inconnue = langue originale.
-- Le nom ne sert que de complément, pour une MULTi que les langues ne
-- confirment pas. MULTi, VF, VO et « absente » s'excluent l'un l'autre.

INSERT INTO custom_formats (name, description) VALUES
    ('Langue MULTi', 'Français et langue originale parmi les langues détectées (indexeurs français à la recherche, pistes audio à l''import), ou œuvre d''origine française en français.'),
    ('Langue MULTi (nom)', 'Marqueur MULTi dans le nom quand les langues détectées ne le confirment pas (indexeur sans réglage Multi Languages, piste française non étiquetée).'),
    ('Langue VF', 'Français sans la langue originale (doublage seul).'),
    ('Langue VO', 'Langue originale sans le français (VO, VOSTFR).'),
    ('Langue VOSTFR', 'VO annoncée VOSTFR dans le nom : en plus de « Langue VO », pour l''anime.'),
    ('Langue VOSTFR (MULTiSUB)', 'VO annoncée MULTiSUB dans le nom (sous-titres en plusieurs langues, dont le français) : en plus de « Langue VO », pour l''anime.'),
    ('Langue VOSTFR (groupe)', 'VO d''un groupe d''anime qui fournit des sous-titres français, sans marqueur dans le nom : en plus de « Langue VO », pour l''anime.'),
    ('Langue absente', 'Ni le français ni la langue originale (autre doublage).'),
    ('VFQ doublée', 'Doublage québécois (VFQ) d''une œuvre qui n''est pas d''origine francophone. Remplace « French VFQ » de Jojont54, qui rejette aussi les œuvres québécoises en VO.');

INSERT INTO custom_format_conditions (custom_format_name, name, type, negate, required) VALUES
    ('Langue MULTi', 'Français', 'language', 0, 1),
    ('Langue MULTi', 'Langue originale', 'language', 0, 1),

    ('Langue MULTi (nom)', 'MULTi', 'release_title', 0, 1),
    ('Langue MULTi (nom)', 'Sans français', 'language', 1, 0),
    ('Langue MULTi (nom)', 'Sans langue originale', 'language', 1, 0),

    ('Langue VF', 'Français', 'language', 0, 1),
    ('Langue VF', 'Sans langue originale', 'language', 1, 1),
    ('Langue VF', 'Sans MULTi', 'release_title', 1, 1),

    ('Langue VO', 'Langue originale', 'language', 0, 1),
    ('Langue VO', 'Sans français', 'language', 1, 1),
    ('Langue VO', 'Sans MULTi', 'release_title', 1, 1),

    ('Langue VOSTFR', 'Langue originale', 'language', 0, 1),
    ('Langue VOSTFR', 'Sans français', 'language', 1, 1),
    ('Langue VOSTFR', 'Sans MULTi', 'release_title', 1, 1),
    ('Langue VOSTFR', 'VOSTFR', 'release_title', 0, 1),

    -- Conditions d'un même type : toutes les obligatoires, et au moins
    -- une satisfaite ; une négation satisfaite compte. D'où un format par
    -- marqueur plutôt que deux alternatives à côté de « Sans MULTi ».
    ('Langue VOSTFR (MULTiSUB)', 'Langue originale', 'language', 0, 1),
    ('Langue VOSTFR (MULTiSUB)', 'Sans français', 'language', 1, 1),
    ('Langue VOSTFR (MULTiSUB)', 'Sans MULTi', 'release_title', 1, 1),
    ('Langue VOSTFR (MULTiSUB)', 'Sans VOSTFR', 'release_title', 1, 1),
    ('Langue VOSTFR (MULTiSUB)', 'MULTiSUB', 'release_title', 0, 1),

    ('Langue VOSTFR (groupe)', 'Langue originale', 'language', 0, 1),
    ('Langue VOSTFR (groupe)', 'Sans français', 'language', 1, 1),
    ('Langue VOSTFR (groupe)', 'Sans MULTi', 'release_title', 1, 1),
    ('Langue VOSTFR (groupe)', 'Sans VOSTFR', 'release_title', 1, 1),
    ('Langue VOSTFR (groupe)', 'Sans MULTiSUB', 'release_title', 1, 1),
    ('Langue VOSTFR (groupe)', 'Erai-raws', 'release_group', 0, 0),
    ('Langue VOSTFR (groupe)', 'ToonsHub', 'release_group', 0, 0),
    ('Langue VOSTFR (groupe)', 'VARYG', 'release_group', 0, 0),

    ('Langue absente', 'Sans français', 'language', 1, 1),
    ('Langue absente', 'Sans langue originale', 'language', 1, 1),
    ('Langue absente', 'Sans MULTi', 'release_title', 1, 1),

    -- Origine francophone : toutes les langues sont le français et la
    -- langue originale (même test que « French Original » de Jojont54).
    ('VFQ doublée', 'VFQ', 'release_title', 0, 1),
    ('VFQ doublée', 'Sans VOF ni VOQ', 'release_title', 1, 1),
    ('VFQ doublée', 'Autre langue que le français', 'language', 0, 0),
    ('VFQ doublée', 'Autre langue que l''originale', 'language', 0, 0);

INSERT INTO condition_languages (custom_format_name, condition_name, language_name, except_language) VALUES
    ('Langue MULTi', 'Français', 'French', 0),
    ('Langue MULTi', 'Langue originale', 'Original', 0),
    ('Langue MULTi (nom)', 'Sans français', 'French', 0),
    ('Langue MULTi (nom)', 'Sans langue originale', 'Original', 0),
    ('Langue VF', 'Français', 'French', 0),
    ('Langue VF', 'Sans langue originale', 'Original', 0),
    ('Langue VO', 'Langue originale', 'Original', 0),
    ('Langue VO', 'Sans français', 'French', 0),
    ('Langue VOSTFR', 'Langue originale', 'Original', 0),
    ('Langue VOSTFR', 'Sans français', 'French', 0),
    ('Langue VOSTFR (MULTiSUB)', 'Langue originale', 'Original', 0),
    ('Langue VOSTFR (MULTiSUB)', 'Sans français', 'French', 0),
    ('Langue VOSTFR (groupe)', 'Langue originale', 'Original', 0),
    ('Langue VOSTFR (groupe)', 'Sans français', 'French', 0),
    ('Langue absente', 'Sans français', 'French', 0),
    ('Langue absente', 'Sans langue originale', 'Original', 0),
    ('VFQ doublée', 'Autre langue que le français', 'French', 1),
    ('VFQ doublée', 'Autre langue que l''originale', 'Original', 1);

-- Motifs de Jojont54 (son MULTi exclut déjà la VFQ et les MULTi de
-- sous-titres).
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES
    ('Langue MULTi (nom)', 'MULTi', 'French MULTi'),
    ('Langue VF', 'Sans MULTi', 'French MULTi'),
    ('Langue VO', 'Sans MULTi', 'French MULTi'),
    ('Langue VOSTFR', 'Sans MULTi', 'French MULTi'),
    ('Langue VOSTFR', 'VOSTFR', 'French VOSTFR'),
    ('Langue VOSTFR (MULTiSUB)', 'Sans MULTi', 'French MULTi'),
    ('Langue VOSTFR (MULTiSUB)', 'Sans VOSTFR', 'French VOSTFR'),
    ('Langue VOSTFR (MULTiSUB)', 'MULTiSUB', 'French MultiSub (INTL)'),
    ('Langue VOSTFR (groupe)', 'Sans MULTi', 'French MULTi'),
    ('Langue VOSTFR (groupe)', 'Sans VOSTFR', 'French VOSTFR'),
    ('Langue VOSTFR (groupe)', 'Sans MULTiSUB', 'French MultiSub (INTL)'),
    ('Langue VOSTFR (groupe)', 'Erai-raws', 'Erai-raws'),
    ('Langue VOSTFR (groupe)', 'ToonsHub', 'ToonsHub'),
    ('Langue VOSTFR (groupe)', 'VARYG', 'VARYG'),
    ('Langue absente', 'Sans MULTi', 'French MULTi'),
    ('VFQ doublée', 'VFQ', 'French VFQ'),
    ('VFQ doublée', 'Sans VOF ni VOQ', 'French Original Marker');

-- Les formats de langue de Jojont54 sortent de nos profils : ils ne
-- regardent que le nom (« French Missing » rejette une VO sans marqueur
-- français, même avec une piste française).
DELETE FROM quality_profile_custom_formats
WHERE quality_profile_name IN ('4K · VF', '4K · VO', '4K Cinéma', 'Compact · VF', 'Compact · VO', 'Anime')
  AND custom_format_name IN ('French MULTi', 'French Original', 'French Original Marker', 'French VF', 'French VOSTFR', 'French Missing', 'French VFQ');

-- Anime : MULTi > VOSTFR > VO sans sous-titres français > VF.
WITH paliers(profil, multi, vf, vo, vostfr) AS (VALUES
    ('4K · VF', 20000000, 10000000, 0, 0),
    ('4K · VO', 20000000, 0, 10000000, 0),
    ('4K Cinéma', 20000000, 0, 10000000, 0),
    ('Compact · VF', 20000000, 10000000, 0, 0),
    ('Compact · VO', 20000000, 0, 10000000, 0),
    ('Anime', 30000000, 0, 10000000, 10000000)
)
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score)
SELECT profil, 'Langue MULTi', 'all', multi FROM paliers
UNION ALL SELECT profil, 'Langue MULTi (nom)', 'all', multi FROM paliers
UNION ALL SELECT profil, 'Langue VF', 'all', vf FROM paliers
UNION ALL SELECT profil, 'Langue VO', 'all', vo FROM paliers
UNION ALL SELECT profil, 'Langue VOSTFR', 'all', vostfr FROM paliers
UNION ALL SELECT profil, 'Langue VOSTFR (MULTiSUB)', 'all', vostfr FROM paliers
UNION ALL SELECT profil, 'Langue VOSTFR (groupe)', 'all', vostfr FROM paliers
UNION ALL SELECT profil, 'Langue absente', 'all', -100000000 FROM paliers
UNION ALL SELECT profil, 'VFQ doublée', 'all', -100000000 FROM paliers;
