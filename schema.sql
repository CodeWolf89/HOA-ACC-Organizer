-- Copyright © 2026 Christopher Mcmahon-Sutton.
-- Licensed under the PolyForm Perimeter License 1.0.1.
-- Author: Christopher Mcmahon-Sutton.
-- Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
-- See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

-- Reference schema. The app applies the same migration in SQLiteStore.swift.
CREATE TABLE lots (
  id TEXT PRIMARY KEY,
  lot_number TEXT NOT NULL UNIQUE,
  owner_name TEXT NOT NULL DEFAULT '',
  primary_address TEXT NOT NULL DEFAULT '',
  billing_address TEXT NOT NULL DEFAULT '',
  is_rental_unit INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE violations (
  id TEXT PRIMARY KEY,
  lot_id TEXT NOT NULL REFERENCES lots(id),
  observed_at TEXT,
  correction_deadline TEXT,
  created_at TEXT,
  escalation_date TEXT,
  final_warning_date TEXT,
  resolved_date TEXT,
  inspector_name TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT '',
  source_hash TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE acc_requests (
  id TEXT PRIMARY KEY,
  lot_id TEXT NOT NULL REFERENCES lots(id),
  applicant_name TEXT NOT NULL DEFAULT '',
  applicant_phone TEXT NOT NULL DEFAULT '',
  proposed_change_address TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  color TEXT NOT NULL DEFAULT '',
  proposed_start_date TEXT,
  proposed_completion_date TEXT,
  submitted_at TEXT,
  status TEXT NOT NULL DEFAULT 'Draft',
  acc_recommendation TEXT NOT NULL DEFAULT '',
  remarks TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
