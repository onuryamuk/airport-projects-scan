# Prioritisation method and definitions

## Record construction
- A project is included only when at least one source was opened (fetched) or, failing that, a dated search excerpt from a named publisher was captured; the `access` field on each source says which.
- Facts (scope, values, dates, parties) repeat the source. Missing data is "Not publicly disclosed".
- Analyst judgments (score, rationale, potential services, next action, expected timing marked "judgment") are labelled as such in the detail panel and the CSV.
- Republished coverage of the same fact does not create a history entry or change `latest_update`.
- Completed, cancelled and suspended projects are retained as context, shown with a "Context" badge, and excluded from active totals.

## Priority score (0-20)
Five criteria scored 0-4. High = 15+, Medium = 10-14, Low < 10.

| Criterion | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|
| Service fit | Multidisciplinary terminal + airfield scope at planning/design stage | Terminal or airfield design scope | Single discipline, or construction-phase roles only (supervision, ORAT) | Marginal (FM, minor studies) | No relevant scope |
| Procurement timing | Consultancy tender, EOI or PPP process open now or within 6 months | Consultancy appointments expected 6-18 months | Construction-phase roles possible; >18 months for design | Unclear or >3 years | Completed / cancelled |
| Accessibility | Open EU/IFI procurement or existing SJ client; SJ/SMEC presence in country | Open with partner or registration | Partly closed (concessionaire self-delivery) but approachable | Largely domestic procurement | Closed, sanctioned or high security risk |
| Scale (reported total value, USD equivalent) | > 5bn | 1-5bn | 300m-1bn | < 300m or undisclosed | Not scored (context) |
| Evidence quality | Official source fetched, dated within 12 months | Industry press fetched or corroborated | Search excerpt only | Single weak or undated source | None |

Approximate currency conversion is used only for the scale band; displayed values keep their original currency.

## Opportunity types
- Confirmed procurement activity: a tender, EOI, PPP qualification or award stage is documented. Not the same as an open consultancy tender - the record states which roles are actually procurable.
- Potential future opportunity: inferred from scope and stage; no notice seen.
- Existing engagement or reference: SJ Group holds a role (Changi T5, Noida, KAIA).
- Track only: closed delivery, completed, cancelled, suspended or high risk.

## Region mapping (one region per country)
- Europe: EU/EEA/UK/Switzerland, Western Balkans, Türkiye.
- Middle East: GCC, Iraq, Syria, Jordan, Lebanon, Israel, Yemen, Iran.
- North Africa: Morocco, Algeria, Tunisia, Libya, Egypt.
- Central Asia: Kazakhstan, Uzbekistan, Kyrgyzstan, Tajikistan, Turkmenistan, plus Georgia, Armenia, Azerbaijan.
- Asia Pacific (excl. Australia): South Asia, Southeast Asia, East Asia, New Zealand, Pacific islands.
- Australia.
- North America: United States, Canada, Mexico (added 12 Sept 2026; Central America and the Caribbean not yet covered). Accessibility scoring notes SJ Group member B+H Architects (Toronto) for Canada; US records assume a US-licensed partner is needed.

## Freshness and conflicts
- Scan time = when sources were checked (dashboard header). Latest update = date of the most recent material development in the record.
- Records with latest update older than 180 days are flagged stale automatically.
- Conflicting figures are retained with a "Conflicting information" flag.
- Milestones marked "approx." sit on the first day of their stated window; "judgment" milestones are analyst expectations.

## SJ Group capability basis (verified 11 Sept 2026)
- sjgroup.com lists Aviation under Building + Cities and names SMEC, Atelier Ten and Robert Bird Group as group members; SJ Group is Diamond Sponsor of Passenger Terminal Expo Asia 2026.
- sjgroup.com/projects/king-abdulaziz-international-airport: project management consultancy for Jeddah Airports Company across 100+ capital projects.
- Passenger Terminal Today, 13 Apr 2018: Surbana Jurong Consultants appointed Master Building Consultant (engineering) and Master Civil Consultant for Changi Terminal 5.
- SMEC/SJ Group statement: SJ Aviation, SMEC and Robert Bird Group delivering detailed design consultancy for Noida International Airport EPC with Tata Projects.
Service suggestions per record are the analyst's mapping of scope to these capabilities.
