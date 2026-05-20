# CKA Exam Report — session-fixture

**Blueprint:** mock-alpha
**Started:** 2026-05-10T09:00:00Z  **Completed:** 2026-05-10T11:35:00Z  **Duration:** 02:35:00
**Total Score: 64/100  (FAIL vs 66% pass mark)**

## Per-Domain Breakdown (weakest first)

| Domain | Score | Percentage | Blueprint Weight |
|--------|-------|------------|------------------|
| troubleshooting | 20/40 | 50% | 30% |
| cluster-architecture | 20/32 | 63% | 25% |
| services-networking | 16/24 | 67% | 20% |
| storage | 12/16 | 75% | 10% |
| workloads-scheduling | 20/24 | 83% | 15% |

## Top 5 Traps Hit

| # | Trap ID | Count | Description |
|---|---------|-------|-------------|
| 1 | mock-trap-b | 9 | mock-trap-b |
| 2 | mock-trap-a | 8 | mock-trap-a |
| 3 | mock-trap-c | 3 | mock-trap-c |
| 4 | mock-trap-e | 3 | mock-trap-e |
| 5 | mock-trap-d | 1 | mock-trap-d |

## Suggested Next Drills

Your weakest domains: troubleshooting, cluster-architecture, services-networking. Drill these next:

- `cka-sim drill troubleshooting`
- `cka-sim drill cluster-architecture`
- `cka-sim drill services-networking`

## Question-by-Question Detail

| # | Domain | Question | Score | Status | Traps |
|---|--------|----------|-------|--------|-------|
| 1 | storage | mock-alpha-01 | 8/8 | passed | — |
| 2 | storage | mock-alpha-02 | 4/8 | failed | mock-trap-b, mock-trap-b |
| 3 | workloads-scheduling | mock-alpha-03 | 8/8 | passed | — |
| 4 | workloads-scheduling | mock-alpha-04 | 4/8 | failed | mock-trap-a, mock-trap-b |
| 5 | workloads-scheduling | mock-alpha-05 | 8/8 | passed | — |
| 6 | services-networking | mock-alpha-06 | 4/8 | failed | mock-trap-b, mock-trap-a |
| 7 | services-networking | mock-alpha-07 | 8/8 | passed | — |
| 8 | services-networking | mock-alpha-08 | 4/8 | failed | mock-trap-e, mock-trap-b |
| 9 | cluster-architecture | mock-alpha-09 | 4/8 | failed | mock-trap-c, mock-trap-a |
| 10 | cluster-architecture | mock-alpha-10 | 4/8 | failed | mock-trap-a, mock-trap-b |
| 11 | cluster-architecture | mock-alpha-11 | 8/8 | passed | — |
| 12 | cluster-architecture | mock-alpha-12 | 4/8 | failed | mock-trap-d, mock-trap-a |
| 13 | troubleshooting | mock-alpha-13 | 4/8 | failed | mock-trap-a, mock-trap-c |
| 14 | troubleshooting | mock-alpha-14 | 4/8 | failed | mock-trap-c, mock-trap-b |
| 15 | troubleshooting | mock-alpha-15 | 4/8 | failed | mock-trap-b, mock-trap-e |
| 16 | troubleshooting | mock-alpha-16 | 4/8 | failed | mock-trap-e, mock-trap-a |
| 17 | troubleshooting | mock-alpha-17 | 4/8 | failed | mock-trap-a, mock-trap-b |
