
--Aircraft damage and condition
SELECT 
	a.ev_id,
	a.damage,
	a.acft_fire,
	a.acft_expl
FROM aircraft AS a;

--Counting aircraft damage grouped by damage type and excluding the nulls
SELECT 
	a.damage,
	COUNT(a.damage) AS damage_type_count
FROM aircraft AS a
WHERE a.damage IS NOT NULL
GROUP BY a.damage;

--Damage count per aircraft make
SELECT
	a.acft_make,
	SUM(CASE WHEN a.damage = 'MINR' THEN 1 ELSE 0 END) AS minor,
	SUM(CASE WHEN a.damage = 'SUBS' THEN 1 ELSE 0 END) AS substantial,
	SUM(CASE WHEN a.damage = 'DEST' THEN 1 ELSE 0 END) AS destroyed,
	SUM(CASE WHEN a.damage IS NOT NULL then 1 ELSE 0 END) AS total_damage_count
FROM dbo.aircraft AS a
GROUP BY a.acft_make
ORDER BY total_damage_count DESC;


--Accident related aircraft make count in descending order
SELECT 
    a.acft_make,
    COUNT(*) AS make_count
FROM dbo.aircraft AS a
WHERE a.acft_make IS NOT NULL
GROUP BY a.acft_make
ORDER BY make_count DESC;

--Accident related aircraft model count in descending order
SELECT
    MAX(a.acft_make) ASacft_make,   
    a.acft_model,
    COUNT(a.acft_model) AS model_count
FROM dbo.aircraft AS a
WHERE a.acft_model IS NOT NULL
GROUP BY a.acft_model
ORDER BY model_count DESC;

--Model count with damage count
SELECT
	MAX(a.acft_make) AS acft_make,
	a.acft_model,
	COUNT(a.acft_model) AS model_count,
	SUM(CASE WHEN a.damage = 'MINR' THEN 1 ELSE 0 END) AS minor_damage,
	SUM(CASE WHEN a.damage = 'SUBS' THEN 1 ELSE 0 END) AS substantial_damage,
	SUM(CASE WHEN a.damage = 'DEST' THEN 1 ELSE 0 END) AS destroyed,
	SUM(CASE WHEN a.damage IS NOT NULL THEN 1 ELSE 0 END) AS total_damage
FROM dbo.aircraft AS a
WHERE a.acft_model IS NOT NULL
GROUP BY acft_model
ORDER BY model_count DESC;

--Opening flight phase table
SELECT *
FROM dbo.events AS e

--Flight phase analysis on aircraft damage


--Adding flight phase for later. We want to figure out which flight phase has the most events. This can help us identify common issues as well.
--Sentiment analysis will provide clues on common causes of damages. 
--Map of events can help provide areas that are prone to aviation accidents or mishaps. 





