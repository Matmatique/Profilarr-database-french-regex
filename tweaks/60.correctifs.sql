-- Correctifs de la base de Jojont54, à retirer quand il les aura faits.

-- Formats « … Size > N GiB » (ops/28) : taille sans maximum (NULL),
-- envoyée à 0 par Profilarr ; Sonarr et Radarr refusent un maximum
-- inférieur au minimum, et ces formats n'existent pas chez eux (la pénalité
-- de taille des profils Compact est donc perdue). Maximum à 1 000 GiB.
UPDATE condition_sizes SET max_bytes = 1073741824000
WHERE max_bytes IS NULL
  AND custom_format_name LIKE '%Size > % GiB';
