# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a university final project for a Databases course. The goal is to select a real-world industry/case, analyze its Database Management Systems (DBMS), and propose an optimization/improvement. The final presentation simulates a corporate context where the team presents to a CTO.

**Final deadline: November 24, 2025 (non-negotiable)**

## Required Deliverables (Sprint Final folder)

1. Presentation (.ppt or .pdf)
2. Business report — max 5 pages (.pdf)
3. ER model (.pdf or .jpg)
4. Business rules library (.txt, .csv, or .xlsx)
5. SQL scripts (.sql, .txt, or .pdf)
6. NoSQL scripts (.json/.bson, .txt, or README)
7. Databases — initial and evolved versions (.csv or .xlsx)
8. Cloud architecture diagram — max 2 pages (.pdf, .png, .jpg, or .txt)
9. Financial report — max 2 pages (.pdf)
10. Legal/ethical/standards framework — max 2 pages (.pdf)
11. .zip of everything above

## Grading Rubric Summary (100 pts)

| Component | Points | Key requirement |
|---|---|---|
| ER Model | 10 | Normalized entities, PK/FK, cardinalities, data types |
| Business Rules | 5 | ≥5 verifiable rules traceable to tables/constraints |
| SQL Implementation | 15 | DDL, DML, JOINs, subqueries, aggregations, window functions, views, 1 stored procedure, 1 function — must execute without errors |
| NoSQL Module | 15 | Document/key-value model with ≥2 useful queries/aggregations, minimal integration with relational domain |
| Cloud Architecture | 10 | Diagram with compute service, managed DB service, storage, IAM/Secret Manager, observability |
| Cost & ROI | 15 | Explicit assumptions, per-resource cost breakdown (taxes included), ROI formula, scenarios |
| Legal & Ethics | 10 | Personal data identification, national + international legal basis, ethical considerations (bias, transparency) |
| Results Analysis | 10 | ≥5 queries with business interpretation and actionable insights |
| Executive Presentation | 10 | 5–10 min, clear narrative, readable visuals, decision/roadmap |

## SQL Script Requirements

Scripts must include: DDL (CREATE TABLE with constraints), DML (INSERT/UPDATE/DELETE), JOINs, subqueries, aggregations (GROUP BY), window functions, views, at least 1 stored procedure, and at least 1 function.

## NoSQL Requirements

Choose document (e.g., MongoDB) or key-value model. Design collections/partition keys and indexes intentionally. Include ≥2 aggregation queries. Show integration with the relational model (e.g., catalog, events, logs, or cache).

## Cloud Architecture Requirements

Must include: one compute service (Lambda/Cloud Functions/Cloud Run or VM), one managed DB service, blob/object storage, IAM/Secret Manager, and observability (logs/metrics). Justify the cloud provider choice. Show deployment evidence or commands.

## Financial Analysis Requirements

Explicit traffic/volume assumptions, cost per resource (compute, DB, storage, transfer, users) with taxes, human talent costs if applicable (including social security), ROI formula, at least two scenarios (e.g., optimistic/pessimistic), and an executive conclusion.
