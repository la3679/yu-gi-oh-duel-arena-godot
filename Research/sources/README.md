# Research/sources — fetching the primary rules documents

This directory holds **local, untracked copies** of the official Konami documents the
engine's rules are derived from. The files themselves are **deliberately not committed**:
they are Konami publications, and this project holds no right to redistribute them. They
are free downloads from Konami's own website, so vendoring them buys nothing and creates
copyright exposure for anyone who forks this repository.

What *is* committed is everything that makes the sources reproducible and auditable:

* [`../RULES_SOURCES.md`](../RULES_SOURCES.md) — the source register: title, publisher,
  canonical URL, byte size, **SHA-256**, date accessed, and the exact list of rules each
  source establishes, with page numbers.
* [`../RULES_SPEC.md`](../RULES_SPEC.md) — the rules the engine actually implements, every
  section citing the source (`[S1 p.44]`, `[S2]`, …) it came from.
* [`../CARD_RULINGS.md`](../CARD_RULINGS.md) — the per-card ruling decisions and their
  confidence levels.

You do **not** need these files to build, run, or test the project. Fetch them only if you
are adding or re-verifying a rule and need to read the primary text yourself.

## Fetching

Run from the repository root. Both files are ignored by
[`.gitignore`](../../.gitignore), so they will never be committed by accident.

### S1 — Official Rulebook Version 10

```bash
curl -L -o Research/sources/SD_RuleBook_EN_10.pdf https://www.yugioh-card.com/en/downloads/rulebook/SD_RuleBook_EN_10.pdf
```

### S2 — Official Fast Effect Timing chart

```bash
curl -L -o Research/sources/FastEffectTiming_Flowchart_EN-US.jpg https://www.yugioh-card.com/en/wp-content/uploads/2021/05/T-Flowchart_EN-US.jpg
```

### PowerShell equivalents

```powershell
Invoke-WebRequest -Uri "https://www.yugioh-card.com/en/downloads/rulebook/SD_RuleBook_EN_10.pdf" -OutFile "Research/sources/SD_RuleBook_EN_10.pdf"
```

```powershell
Invoke-WebRequest -Uri "https://www.yugioh-card.com/en/wp-content/uploads/2021/05/T-Flowchart_EN-US.jpg" -OutFile "Research/sources/FastEffectTiming_Flowchart_EN-US.jpg"
```

## Verifying you got the same document we read

The rules in `RULES_SPEC.md` cite **page numbers in a specific revision**. If Konami
re-publishes a document, the page numbers can drift. Check the hash before trusting a
citation:

```bash
sha256sum Research/sources/SD_RuleBook_EN_10.pdf
```

```powershell
Get-FileHash Research/sources/SD_RuleBook_EN_10.pdf -Algorithm SHA256
```

| File | Expected SHA-256 | Size |
|---|---|---|
| `SD_RuleBook_EN_10.pdf` | `82BE14641B2B7940467034A5B14B0D4037835831866537738D34FD9DF5A0F444` | 3,415,528 bytes |
| `FastEffectTiming_Flowchart_EN-US.jpg` | `B1F78848CAB3D0288C1BA645D749971752F3BF53D27C6185CA2E2FEBCCBDFF08` | 201,965 bytes |

**A hash mismatch is not automatically a problem** — it means Konami revised the document.
It *is* a signal that any citation you are about to add or re-check must be re-read against
the new revision, and that `RULES_SOURCES.md` needs a new dated entry rather than an edit in
place. Never silently update a page number.

S3 (Damage Step rules) and S4 (the official card database) are web pages rather than
downloadable files; their URLs and access dates are recorded in `RULES_SOURCES.md`.
