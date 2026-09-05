--Top count by manufacturer

SELECT acft_make, COUNT(*) AS n
FROM aircraft
GROUP BY acft_make
ORDER BY 2 DESC
LIMIT 25;

--NOTE: Manufacturer input have duplicates with variable letter case. Will need further cleanup.

--====================

--Case and whitespace normalized

SELECT UPPER(TRIM(acft_make)) AS make_norm,
	   COUNT(*) AS n
FROM aircraft
GROUP BY 1
ORDER BY n DESC
LIMIT 25;

--Findings: Cessna shows as the top manufacturer with the most events reported
--Followed by Piper, Boeing, Beech, and Bell

--====================

--Check how much it collapsed after normalizing

SELECT
    COUNT(DISTINCT acft_make) AS raw_values,
    COUNT(DISTINCT UPPER(TRIM(acft_make))) AS normalized_values
FROM aircraft;

--===================================

-- What are the top-level finding categories?

SELECT category_no, COUNT(*) AS n
FROM findings
GROUP BY 1
ORDER BY n DESC;

--===================================================

SELECT finding_description
FROM findings
LIMIT 20;

--===================================================

--What do maintenance-related findings actually look like?

SELECT finding_description, COUNT(*) AS n
FROM findings
WHERE finding_description ILIKE '%maintenance%'
GROUP BY finding_description
ORDER BY n DESC
LIMIT 30;

--====================================================

--Splitting the description to analize taxonomy

--LEVEL 1 

SELECT SPLIT_PART(finding_description, '-', 1) AS level_1,
       COUNT(*) AS n
FROM findings
GROUP BY 1
ORDER BY n DESC

--LEVEL 2 within Aircraft
SELECT SPLIT_PART(finding_description, '-', 2) AS level_2, COUNT(*) AS n
FROM findings
WHERE SPLIT_PART(finding_description, '-', 1) = 'Aircraft'
GROUP BY 1
ORDER BY n DESC;

--LEVEL 2 within Personnel issues
SELECT SPLIT_PART(finding_description, '-', 2) AS level_2, COUNT(*) AS n
FROM findings
WHERE SPLIT_PART(finding_description, '-', 1) = 'Personnel issues'
GROUP BY 1
ORDER BY n DESC;

--==================================================

-- Q: When maintenance is named as the CAUSE, where does the taxonomy file it?
--    Expectation was Aircraft handling/service. Result: only 83 of 969 land
--    there — the rest are filed under whichever component failed.

SELECT SPLIT_PART(finding_description, '-', 2) AS level_2,
       COUNT(*) AS n
FROM findings
WHERE finding_description ILIKE '%service/maintenance%'
GROUP BY 1
ORDER BY n DESC;

-- Q: When maintenance PERSONNEL are named as the actor, what were they doing?
--    916 of 1,039 are task performance — inspection, servicing, installation.

SELECT SPLIT_PART(finding_description, '-', 2) AS level_2,
       COUNT(*) AS n
FROM findings
WHERE finding_description ILIKE '%maintenance personnel%'
GROUP BY 1
ORDER BY n DESC;

--================================================

--How many distinct accidents have at least one maintenance-related finding?
SELECT COUNT(DISTINCT ev_id) AS maint_events
FROM findings
WHERE finding_description ILIKE '%service/maintenance%'
   OR finding_description ILIKE '%maintenance personnel%'
   OR SPLIT_PART(finding_description, '-', 2) = 'Aircraft handling/service';

--Against the total
SELECT COUNT(DISTINCT ev_id) FROM findings;

--1,532 / 23,184 = 6.6% of accidents with coded findings have at least one maintenance-related finding.

--======================================

--Check the cause factor

SELECT cause_factor, COUNT(*) 
FROM findings 
GROUP BY 1 
ORDER BY 2 DESC;

--Finding: There are 25,556 null values, this is a significant 
--		   number of unclassified findings. 

--=====================================================

-- Q: Narrowing to NTSB-designated causes only, how many accidents involve
--    maintenance? This is the floor; 1,532 (any maintenance finding) is the
--    ceiling. Result: 795 of 23,184 events with findings = 3.4%.
--    Note cause_factor = 'C' also drops the 25,556 unclassified findings,
--    so this is conservative twice over.

SELECT COUNT(DISTINCT ev_id) AS maint_cause_events
FROM findings
WHERE cause_factor = 'C'
  AND (finding_description ILIKE '%service/maintenance%'
       OR finding_description ILIKE '%maintenance personnel%'
       OR SPLIT_PART(finding_description, '-', 2) = 'Aircraft handling/service');

-- Q: Is the blank cause_factor a NULL or an empty string? Determines whether
--    IS NULL or = '' is the right filter. Result: 25,556 NULL, 0 empty —
--    so = '' would silently match nothing.

SELECT
    COUNT(*) FILTER (WHERE cause_factor IS NULL)  AS is_null,
    COUNT(*) FILTER (WHERE cause_factor = '')     AS is_empty_string
FROM findings;

--======================================================

--Events without findings grouped by year

SELECT e.ev_year, COUNT(*) AS events_without_findings
FROM events e
WHERE NOT EXISTS (SELECT 1 FROM findings f WHERE f.ev_id = e.ev_id)
GROUP BY 1
ORDER BY 1;









