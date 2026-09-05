-- =============================================================================
-- 00_schema.sql — NTSB Aviation Accident Database
--
-- Builds typed tables from the all-text _raw staging tables created by
-- src/01_load_raw.py. Re-runnable: drops and rebuilds everything.
--
-- Run order matters. Each table's parent must exist before its foreign key
-- can be declared: events -> aircraft -> (findings, engines, injury, flight_time)
--
-- Data scope: 2008-2025. 2025 is a PARTIAL year (~972 events vs ~1,650
-- typical) — exclude it from trend analysis or annotate it.
-- =============================================================================


-- EVENTS ----------------------------------------------------------------------
-- One row per accident/incident. Top of the hierarchy.

DROP TABLE IF EXISTS events CASCADE;

CREATE TABLE events (
    ev_id             text PRIMARY KEY,
    ntsb_no           text,
    ev_type           text,          -- ACC = accident, INC = incident
    ev_date           date,
    ev_year           integer,
    ev_month          integer,
    ev_city           text,
    ev_state          text,
    ev_country        text,
    latitude          text,          -- mixed formats: decimal AND packed DMS
    longitude         text,          -- e.g. '381326N' — parse in 02_transform
    mid_air           text,
    light_cond        text,
    wx_cond_basic     text,
    ev_highest_injury text,
    inj_tot_f         integer,       -- fatal
    inj_tot_s         integer,       -- serious
    inj_tot_m         integer,       -- minor
    inj_tot_n         integer,       -- none
    inj_tot_t         integer        -- total
);

INSERT INTO events
SELECT
    ev_id,
    ntsb_no,
    ev_type,
    ev_date::date,
    ev_year::integer,
    ev_month::integer,
    ev_city,
    ev_state,
    ev_country,
    latitude,
    longitude,
    mid_air,
    light_cond,
    wx_cond_basic,
    ev_highest_injury,
    inj_tot_f::integer,
    inj_tot_s::integer,
    inj_tot_m::integer,
    inj_tot_n::integer,
    inj_tot_t::integer
FROM events_raw;


-- AIRCRAFT --------------------------------------------------------------------
-- One row per aircraft. 486 events involve more than one aircraft (midairs,
-- ground collisions), so ev_id alone is NOT unique here — the key is the pair.
--
-- acft_make deliberately left as raw text. ~4,400 distinct spellings;
-- normalization is a transformation with judgment calls, handled separately.

DROP TABLE IF EXISTS aircraft CASCADE;

CREATE TABLE aircraft (
    ev_id          text,
    aircraft_key   integer,
    regis_no       text,
    far_part       text,          -- 091, 121, 135, etc.
    damage         text,          -- DEST / SUBS / MINR / UNK
    acft_make      text,
    acft_model     text,
    acft_series    text,
    acft_category  text,
    homebuilt      text,
    num_eng        integer,
    total_seats    integer,
    type_last_insp text,
    date_last_insp date,
    afm_hrs        numeric,
    type_fly       text,
    acft_year      integer,
    PRIMARY KEY (ev_id, aircraft_key),
    FOREIGN KEY (ev_id) REFERENCES events (ev_id)
);

INSERT INTO aircraft
SELECT
    ev_id,
    aircraft_key::integer,
    regis_no,
    far_part,
    damage,
    acft_make,
    acft_model,
    acft_series,
    acft_category,
    homebuilt,
    num_eng::integer,
    total_seats::integer,
    type_last_insp,
    date_last_insp::date,
    afm_hrs::numeric,
    type_fly,
    acft_year::integer
FROM aircraft_raw;


-- FINDINGS --------------------------------------------------------------------
-- MANY rows per aircraft (69,082 rows across 23,184 events). Counting events
-- off this table without DISTINCT or EXISTS will double-count.
--
-- Post-2008 taxonomy. finding_description carries the full hierarchy as text,
-- e.g. 'Personnel issues-Action/decision-Info processing-Pilot - C'

DROP TABLE IF EXISTS findings CASCADE;

CREATE TABLE findings (
    ev_id               text,
    aircraft_key        integer,
    finding_no          integer,
    finding_code        text,
    finding_description text,
    category_no         text,
    subcategory_no      text,
    cause_factor        text,       -- C = cause, F = factor
    PRIMARY KEY (ev_id, aircraft_key, finding_no),
    FOREIGN KEY (ev_id, aircraft_key) REFERENCES aircraft (ev_id, aircraft_key)
);

INSERT INTO findings
SELECT
    ev_id,
    aircraft_key::integer,
    finding_no::integer,
    finding_code,
    finding_description,
    category_no,
    subcategory_no,
    cause_factor
FROM findings_raw;


-- ENGINES ---------------------------------------------------------------------
-- One row per engine.
--
-- TRAP: hp_or_lbs holds the UNIT ('HP' 22,167 / 'LBS' 1,592 / null 3,183),
-- not a number. power_units holds the value. Never compare or average
-- power_units across units — HP is shaft power, LBS is thrust.

DROP TABLE IF EXISTS engines CASCADE;

CREATE TABLE engines (
    ev_id               text,
    aircraft_key        integer,
    eng_no              integer,
    eng_type            text,
    eng_mfgr            text,
    eng_model           text,
    power_units         numeric,    -- the number
    hp_or_lbs           text,       -- the unit: HP or LBS
    carb_fuel_injection text,
    propeller_type      text,
    eng_time_total      numeric,
    eng_time_last_insp  numeric,
    eng_time_overhaul   numeric,
    PRIMARY KEY (ev_id, aircraft_key, eng_no),
    FOREIGN KEY (ev_id, aircraft_key) REFERENCES aircraft (ev_id, aircraft_key)
);

INSERT INTO engines
SELECT
    ev_id,
    aircraft_key::integer,
    eng_no::integer,
    eng_type,
    eng_mfgr,
    eng_model,
    power_units::numeric,
    hp_or_lbs,
    carb_fuel_injection,
    propeller_type,
    eng_time_total::numeric,
    eng_time_last_insp::numeric,
    eng_time_overhaul::numeric
FROM engines_raw;


-- INJURY ----------------------------------------------------------------------
-- Injury counts broken out by person category and severity. Four-column key:
-- one aircraft has several person categories, each at several injury levels.

DROP TABLE IF EXISTS injury CASCADE;

CREATE TABLE injury (
    ev_id               text,
    aircraft_key        integer,
    inj_person_category text,
    injury_level        text,
    inj_person_count    integer,
    PRIMARY KEY (ev_id, aircraft_key, inj_person_category, injury_level),
    FOREIGN KEY (ev_id, aircraft_key) REFERENCES aircraft (ev_id, aircraft_key)
);

INSERT INTO injury
SELECT
    ev_id,
    aircraft_key::integer,
    inj_person_category,
    injury_level,
    inj_person_count::integer
FROM injury_raw;


-- FLIGHT_TIME -----------------------------------------------------------------
-- Crew hours. Five-column key: each crew member logs hours by flight_type
-- (total, last 90 days, last 24 hours) and flight_craft (this make/model,
-- all aircraft). Largest table at 383k rows — slowest insert.

DROP TABLE IF EXISTS flight_time CASCADE;

CREATE TABLE flight_time (
    ev_id        text,
    aircraft_key integer,
    crew_no      integer,
    flight_type  text,
    flight_craft text,
    flight_hours numeric,
    PRIMARY KEY (ev_id, aircraft_key, crew_no, flight_type, flight_craft),
    FOREIGN KEY (ev_id, aircraft_key) REFERENCES aircraft (ev_id, aircraft_key)
);

INSERT INTO flight_time
SELECT
    ev_id,
    aircraft_key::integer,
    crew_no::integer,
    flight_type,
    flight_craft,
    flight_hours::numeric
FROM flight_time_raw;


-- VERIFY ----------------------------------------------------------------------
q

SELECT 'events' AS tbl, COUNT(*) FROM events
UNION ALL SELECT 'aircraft',    COUNT(*) FROM aircraft
UNION ALL SELECT 'findings',    COUNT(*) FROM findings
UNION ALL SELECT 'engines',     COUNT(*) FROM engines
UNION ALL SELECT 'injury',      COUNT(*) FROM injury
UNION ALL SELECT 'flight_time', COUNT(*) FROM flight_time;


-- NOT PROMOTED ----------------------------------------------------------------
-- events_sequence_raw — occurrence + phase of flight; overlaps findings
-- country_raw         — small lookup, join from _raw if ever needed
-- narratives          — source export was empty (0 rows)
-- =============================================================================