-- Correctifs de la base de Jojont54, à retirer quand il les aura faits.

-- Formats « … Size > N GiB » (ops/28) : taille sans maximum (NULL),
-- envoyée à 0 par Profilarr ; Sonarr et Radarr refusent un maximum
-- inférieur au minimum, et ces formats n'existent pas chez eux (la pénalité
-- de taille des profils Compact est donc perdue). Maximum à 1 000 GiB.
UPDATE condition_sizes SET max_bytes = 1073741824000
WHERE max_bytes IS NULL
  AND custom_format_name LIKE '%Size > % GiB';

-- Full Disc (ops/1) : sa condition obligatoire « Not x265 » écarte tout
-- titre portant HEVC, donc la plupart des disques UHD
-- (« ….2160p.UHD.BluRay.ISO.…HEVC-… » passait à +20 910 610 dans Sonarr,
-- qui n'a pas de qualité BR-DISK pour « Full Disc (Quality Match) »).
-- HEVC seul ne peut pas suffire à rejeter : Jojont54 note ces titres comme
-- des encodes (« 2160p Bluray HEVC »). La négation ne vaut donc plus pour
-- les titres marqués image disque (ISO, BDMV, BR-DISK, BD25 à BD100,
-- COMPLETE BLURAY) ; x265 et h265 restent exclus par le motif Full Disc.
INSERT INTO regular_expressions (name, pattern, description) VALUES (
    'x265 (hors image disque)',
    '^(?!.*remux)(?!.*\b(ISO|BDMV|BR[-_. ]?DISK|(BD|UHD)[-_. ]?(25|50|66|100)|COMPLETE[-_. ]?(UHD[-_. ]?)?BLU[-_. ]?RAY)\b).*([x][ ._-]?265|\bHEVC(\b|\d))',
    'Motif x265, sauf sur les titres marqués image disque (tweak du fork, condition « Not x265 » de Full Disc).'
);
UPDATE condition_patterns SET regular_expression_name = 'x265 (hors image disque)'
WHERE custom_format_name = 'Full Disc' AND condition_name = 'Not x265';
