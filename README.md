# NTSB Aviation Accident Analysis

**How the NTSB codes accidents determines what you can find in the data.** Maintenance causation is recorded against the component that failed, not against maintenance — so searching the maintenance branch of the taxonomy finds 9% of it. And the operating rules with the strictest maintenance requirements show the *highest* rate of maintenance findings, which says more about investigation depth than about maintenance quality.

PostgreSQL · Python (pandas, SQLAlchemy) · 2008–2025 · 29,423 events

[View the interactive dashboard](https://public.tableau.com/views/WhereMaintenanceHidesinNTSBAccidentData/Dashboard?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## The dataset

NTSB aviation accident data from [data.ntsb.gov/avdata](https://data.ntsb.gov/avdata), the eADMS export. Six normalized tables covering every civil aviation accident and incident investigated by the NTSB from 2008 through 2025.

| Table | Rows | Grain |
|---|---|---|
| `events` | 29,423 | one per event |
| `aircraft` | 29,912 | one per aircraft (486 events involve 2+) |
| `findings` | 69,082 | many per aircraft |
| `engines` | 26,942 | one per engine |
| `injury` | 166,562 | person category × severity |
| `flight_time` | 383,068 | crew member × hour type × craft type |

The population is **accidents and incidents** — 27,310 accidents (death, serious injury, or substantial damage) and 2,113 incidents (safety-significant but below that threshold). Both are included throughout unless noted.

This is a genuinely relational source — `events` → `aircraft` → four child tables, keyed on `(ev_id, aircraft_key)`. Getting the joins right is most of the work.

---

## Findings

### 1. The maintenance branch of the taxonomy contains 9% of maintenance findings

The NTSB findings taxonomy has a branch called `Aircraft handling/service`, which includes `Maintenance/inspections`. It holds **375 findings** out of 69,082 — the smallest of the seven `Aircraft` sub-branches. Read literally, maintenance barely registers as an accident cause.

It isn't that simple. The modifier `Incorrect service/maintenance` appears **969 times**, and only **83 of those** sit inside `Aircraft handling/service`:

| Where `service/maintenance` findings are filed | Count |
|---|---|
| Aircraft power plant | 366 |
| Aircraft systems | 319 |
| Aircraft handling/service | 83 |
| Fluids/misc hardware | 78 |
| Aircraft propeller/rotor | 64 |
| Aircraft structures | 59 |

**91% are filed under the component that failed rather than under maintenance.** A cracked cylinder is coded as a power plant finding; the fact that a maintenance action caused the crack appears only as a level-5 modifier. Separately, 1,039 findings name maintenance personnel as the actor, overwhelmingly under `Personnel issues-Task performance` — inspection and servicing tasks.

An analyst who searches the obvious category finds 375 findings. The real population is four times that.

### 2. Maintenance-related events: 3.4% to 6.6%

Counting distinct events rather than findings, against the 23,184 events that have any coded findings:

| Definition | Events | Share |
|---|---|---|
| Any maintenance-related finding | 1,532 | 6.6% |
| NTSB-designated **cause** only (`cause_factor = 'C'`) | 795 | 3.4% |

Reported as a range because the difference is a real definitional choice, not noise. The narrow figure also excludes the 25,556 findings (37%) where `cause_factor` is NULL — recorded in the sequence but designated neither cause nor factor.

### 3. Maintenance findings are four times more common in incidents than accidents

| Event type | With findings | Maintenance-related | Share |
|---|---|---|---|
| Accident | 22,678 | 1,215 | 5.4% |
| Incident | 506 | 101 | **20.0%** |

This is consistent with how mechanical failures present. A rough-running engine or an unsafe gear indication gives the crew warning and options; the event often ends as a diversion or precautionary landing rather than a crash. Pilot-cause events — stall on base, VFR into IMC, fuel exhaustion — offer less warning and end worse.

Two limits on reading too much into it. The incident sample is small (506 events with coded findings), and the NTSB investigates only a fraction of reported incidents. That selection likely favors mechanical events in the first place, since a component failure gets reported where a hard landing does not. Some of the 20% is real; some is selection.

### 4. Stricter maintenance rules, higher maintenance findings

Maintenance-related share by operating rule, 2008–2023, aircraft with coded findings:

| FAR Part | Aircraft | Maintenance | Share |
|---|---|---|---|
| 121 — scheduled airline | 668 | 76 | **11.4%** |
| 135 — commuter / on-demand | 793 | 77 | **9.7%** |
| 137 — agricultural | 1,072 | 71 | 6.6% |
| 091 — general aviation | 19,419 | 1,216 | 6.3% |

Part 121 operates under the most demanding maintenance regime in civil aviation — continuous airworthiness programs, approved inspection intervals, licensed repair stations — and shows nearly double the maintenance-finding rate of Part 91.

This almost certainly measures **detection, not occurrence**:

- **Records exist to be examined.** Part 121 maintenance records are detailed and auditable. Part 91 records are frequently incomplete, so a maintenance cause often cannot be substantiated even where it exists.
- **Event mix differs.** Part 91 accidents skew heavily toward pilot causes — fuel exhaustion, VFR into IMC, loss of control — which dilutes the maintenance share without maintenance being any less common in absolute terms.

Groups below ~100 aircraft (091K, 133, 129, and others) are excluded from interpretation; the denominators are too small for the percentages to be stable.

---

## Caveats

**These numbers describe NTSB coding, not aviation.** Every figure here is a floor. A maintenance cause that was never identified, never substantiated, or never coded does not appear in the data at all.

**The denominator is unstable across years.** Events with no coded findings rose from ~200/year in 2008–2014 to 531 in 2023, while total events *fell*. 2024 (822) and 2025 (811) are dominated by open investigations. All time-based analysis excludes 2024–2025; trend claims across the full period are not supportable without also reporting coded share.

**`acft_make` is free text** — 4,413 distinct spellings across 29,912 rows, including 19 variants of Cessna. Any ranking by manufacturer requires normalization first, and manufacturer counts track fleet size rather than reliability regardless.

**Four findings have malformed hierarchy strings** (level 1 and 2 missing, beginning `main system-`). Excluded; 0.006% of rows.

**`hp_or_lbs` holds the unit, not the value.** HP (22,167) or LBS (1,592); `power_units` holds the number. Shaft horsepower and thrust pounds are not comparable — any engine power comparison must filter or group on the unit.

---

## Reproducing

```
src/01_load_raw.py     Excel exports → all-text staging tables
sql/00_schema.sql      typed tables, primary and foreign keys
sql/03_checks.sql      key uniqueness and orphan validation
sql/04_eda.sql         taxonomy profiling, data quality
sql/05_analysis.sql    the queries behind the findings above
```

1. Download the eADMS export from [data.ntsb.gov/avdata](https://data.ntsb.gov/avdata) into `data/`
2. Create a `ntsb` database in PostgreSQL
3. Run `src/01_load_raw.py`
4. Run `sql/00_schema.sql`, then the rest in numbered order

Ingestion loads everything as text deliberately — pandas' type inference silently corrupts `ev_id` (to float) and `far_part` (`091` → `91`). Every cast is made explicitly in `00_schema.sql`, where the decision is visible and reviewable.

### Validation

All primary keys confirmed unique; all foreign key relationships confirmed free of orphans:

| Table | Key | Duplicates | Orphans |
|---|---|---|---|
| `events` | `ev_id` | 0 | — |
| `aircraft` | `ev_id, aircraft_key` | 0 | 0 |
| `findings` | `ev_id, aircraft_key, finding_no` | 0 | 0 |
| `engines` | `ev_id, aircraft_key, eng_no` | 0 | 0 |
| `injury` | `ev_id, aircraft_key, category, level` | — | 0 |
| `flight_time` | `ev_id, aircraft_key, crew_no, type, craft` | — | 0 |

---

## Data & security note

Public, unclassified NTSB data only. Nothing here originates from any employer system or non-public source.
