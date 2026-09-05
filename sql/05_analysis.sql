-- =============================================================================
-- 05_analysis.sql — NTSB Aviation Accident Analysis
--
-- The queries behind the findings in README.md. Each is labeled with the
-- question it answers and the result it produced.
--
-- Scope: 2008-2025. Time-based queries exclude 2024-2025 (open investigations).
-- =============================================================================


-- FINDING 1 -------------------------------------------------------------------
-- Where the taxonomy files maintenance causation
-- -----------------------------------------------------------------------------

-- Q: How large is the branch a general analyst would search for maintenance?
-- A: 375 findings — the smallest of the seven Aircraft sub-branches.
SELECT SPLIT_PART(finding_description, '-', 2) AS aircraft_branch,
       COUNT(*) AS findings
FROM findings
WHERE SPLIT_PART(finding_description, '-', 1) = 'Aircraft'
GROUP BY 1
ORDER BY findings DESC;


-- Q: When maintenance is named as the CAUSE, where does the taxonomy file it?
-- A: 969 findings total, only 83 in Aircraft handling/service. The other 91%
--    are filed under whichever component failed — power plant, systems,
--    fluids, propeller, structures.
SELECT SPLIT_PART(finding_description, '-', 2) AS aircraft_branch,
       COUNT(*) AS findings
FROM findings
WHERE finding_description ILIKE '%service/maintenance%'
GROUP BY 1
ORDER BY findings DESC;


-- Q: When maintenance PERSONNEL are named as the actor, what were they doing?
-- A: 1,039 findings; 916 under Task performance (inspection, servicing,
--    installation).
SELECT SPLIT_PART(finding_description, '-', 2) AS personnel_branch,
       COUNT(*) AS findings
FROM findings
WHERE finding_description ILIKE '%maintenance personnel%'
GROUP BY 1
ORDER BY findings DESC;


-- FINDING 2 -------------------------------------------------------------------
-- Share of accidents involving maintenance
-- -----------------------------------------------------------------------------

-- Q: How many distinct accidents have at least one maintenance-related
--    finding? COUNT(DISTINCT ev_id) because findings is many-per-aircraft —
--    an accident with four maintenance findings must count once.
-- A: 1,532 events.
SELECT COUNT(DISTINCT ev_id) AS maint_events
FROM findings
WHERE finding_description ILIKE '%service/maintenance%'
   OR finding_description ILIKE '%maintenance personnel%'
   OR SPLIT_PART(finding_description, '-', 2) = 'Aircraft handling/service';


-- Q: The denominator. Events WITH coded findings, not all 29,423 events —
--    ~6,200 events have no findings at all and could not have a maintenance
--    finding by construction.
-- A: 23,184 events.  1,532 / 23,184 = 6.6%
SELECT COUNT(DISTINCT ev_id) AS events_with_findings
FROM findings;


-- Q: Narrowed to NTSB-designated causes only. This is the floor.
-- A: 795 events = 3.4%. Note cause_factor = 'C' also drops the 25,556
--    findings where cause_factor is NULL, so this is conservative twice over.
SELECT COUNT(DISTINCT ev_id) AS maint_cause_events
FROM findings
WHERE cause_factor = 'C'
  AND (finding_description ILIKE '%service/maintenance%'
    OR finding_description ILIKE '%maintenance personnel%'
    OR SPLIT_PART(finding_description, '-', 2) = 'Aircraft handling/service');


-- FINDING 3 -------------------------------------------------------------------
-- Maintenance share by operating rule
-- -----------------------------------------------------------------------------

-- Q: Does maintenance-related causation vary by FAR part? Part 121 and 135
--    operate under mandated continuous airworthiness programs; Part 91
--    largely does not. Expectation: stricter rules, lower maintenance share.
--
-- A: The opposite. Part 121 = 11.4%, Part 135 = 9.7%, Part 91 = 6.3%.
--    Interpreted as a measure of investigation depth rather than maintenance
--    quality — see README.
--
-- Unit is aircraft, not events: far_part is an aircraft attribute, and 486
-- events involve more than one aircraft.
-- Excludes 2024-2025 (open investigations, unstable denominator).
-- Groups below ~100 aircraft are not interpreted.
WITH maint AS (
    SELECT DISTINCT ev_id, aircraft_key
    FROM findings
    WHERE finding_description ILIKE '%service/maintenance%'
       OR finding_description ILIKE '%maintenance personnel%'
       OR SPLIT_PART(finding_description, '-', 2) = 'Aircraft handling/service'
),
coded AS (
    SELECT DISTINCT ev_id, aircraft_key
    FROM findings
)
SELECT
    a.far_part,
    COUNT(*) AS aircraft_with_findings,
    COUNT(m.ev_id) AS maint_aircraft,
    ROUND(100.0 * COUNT(m.ev_id) / COUNT(*), 1) AS maint_pct
FROM aircraft a
JOIN events e  ON e.ev_id = a.ev_id
JOIN coded  c  ON c.ev_id = a.ev_id AND c.aircraft_key = a.aircraft_key
LEFT JOIN maint m
       ON m.ev_id = a.ev_id AND m.aircraft_key = a.aircraft_key
WHERE e.ev_year <= 2023
GROUP BY a.far_part
ORDER BY aircraft_with_findings DESC;


-- SUPPORTING ------------------------------------------------------------------
-- Why 2024-2025 are excluded
-- -----------------------------------------------------------------------------

-- Q: Are events without findings concentrated in recent years (open
--    investigations) or spread evenly (structural)?
-- A: Both. 2024 (822) and 2025 (811) are clearly open investigations, but the
--    baseline also climbs from ~200/yr (2008-2014) to 531 (2023) while total
--    accidents FELL. The denominator is not stable across years.
--
-- NOT EXISTS rather than NOT IN — NOT IN returns nothing if the subquery
-- contains a NULL.
SELECT e.ev_year,
       COUNT(*) AS events_without_findings
FROM events e
WHERE NOT EXISTS (
    SELECT 1 FROM findings f WHERE f.ev_id = e.ev_id
)
GROUP BY 1
ORDER BY 1;

-- Q: Do accidents and incidents differ in maintenance share?
-- A: Yes, substantially. ACC 1,215/22,678 = 5.4%; INC 101/506 = 20.0%.
--    Maintenance-caused failures skew toward survivable outcomes.
SELECT e.ev_type,
       COUNT(DISTINCT f.ev_id) AS events_with_findings,
       COUNT(DISTINCT f.ev_id) FILTER (
           WHERE f.finding_description ILIKE '%service/maintenance%'
              OR f.finding_description ILIKE '%maintenance personnel%'
       ) AS maint_events
FROM findings f
JOIN events e ON e.ev_id = f.ev_id
GROUP BY e.ev_type;
-- =============================================================================
