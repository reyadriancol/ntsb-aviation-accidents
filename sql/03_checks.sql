-- Does each table's assumed key have duplicates?
SELECT 'events' AS tbl, COUNT(*) AS dupe_keys FROM (
    SELECT ev_id FROM events_raw GROUP BY ev_id HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'aircraft', COUNT(*) FROM (
    SELECT ev_id, aircraft_key FROM aircraft_raw
    GROUP BY ev_id, aircraft_key HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'findings', COUNT(*) FROM (
    SELECT ev_id, aircraft_key, finding_no FROM findings_raw
    GROUP BY ev_id, aircraft_key, finding_no HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'engines', COUNT(*) FROM (
    SELECT ev_id, aircraft_key, eng_no FROM engines_raw
    GROUP BY ev_id, aircraft_key, eng_no HAVING COUNT(*) > 1
) x;

-- ORPHAN CHECK: findings -> aircraft
-- Asks: does every findings row belong to an aircraft that actually exists?
-- Want: 0

SELECT COUNT(*) AS orphans      -- how many findings rows have no aircraft
FROM findings_raw f       -- f = the child table (many rows per aircraft)
LEFT JOIN aircraft_raw a       -- a = the parent table (one row per aircraft)
  ON a.ev_id = f.ev_id       -- match on BOTH key columns 
  AND a.aircraft_key = f.aircraft_key  -- ev_id alone isn't enough
WHERE a.ev_id IS NULL;   -- keeps only rows where no aircraft matched

-- ORPHAN CHECK: injury -> aircraft
-- Want: 0, but this is the one I'd expect to fail

SELECT COUNT(*) AS orphans
FROM injury_raw i   
LEFT JOIN aircraft_raw a
  ON a.ev_id = i.ev_id
  AND a.aircraft_key = i.aircraft_key
WHERE a.ev_id IS NULL;
