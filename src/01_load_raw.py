#!/usr/bin/env python
# coding: utf-8

"""
01_load_raw.py — load NTSB eADMS Excel exports into PostgreSQL as text staging tables.
 
Source:   https://data.ntsb.gov/avdata (2008-2025; 2025 is a partial year)
Target:   postgres @ localhost:5432 / ntsb
No cleaning here — casting and normalization happen in SQL.
 
Expected: events 29,423 | aircraft 29,912 | findings 69,082 | events_sequence 63,203
          engines 26,942 | injury 166,562 | flight_time 383,068 | country 259
"""

import pandas as pd
from sqlalchemy import create_engine
from pathlib import Path

DATA = Path(r"C:\Users\racol\OneDrive\Documents\GitHub\ntsb-aviation-acidents\data")
engine = create_engine("postgresql+psycopg2://postgres@localhost:5432/ntsb")

files = {
    "events_raw":          "events.xlsx",
    "aircraft_raw":        "aircraft.xlsx",
    "findings_raw":        "Findings.xlsx",
    "events_sequence_raw": "Events_Sequence.xlsx",
    "engines_raw":         "engines.xlsx",
    "injury_raw":          "injury.xlsx",
    "flight_time_raw":     "flight_time.xlsx",
    "country_raw":         "Country.xlsx",
}

for table, fname in files.items():
    df = pd.read_excel(DATA / fname, dtype=str)
    df.columns = [c.strip().lower() for c in df.columns]
    df.to_sql(table, engine, if_exists="replace", index=False,
              chunksize=5000, method="multi")
    print(f"{table}: {len(df):,} rows")





