# First Reading After Gap: Quota Delta and Alert Behavior

## CORRECTION (2026-10-02, second review)

An earlier version of this document asserted that the first accumulated delta and any
resulting alerts are "correct and expected". **That claim was not supported by the deployed
code and has been withdrawn.** What follows is the actual inspected logic.

---

## 1. Verified: `Get Previous Reading1` has no staleness guard

```sql
SELECT id, router_id, uptime, wan1_rx, wan1_tx, wan2_rx, wan2_tx, received_at
FROM mikrotik_wan_readings
WHERE router_id = $1
ORDER BY received_at DESC
LIMIT 1;
```

There is **no time window, no age check, and no gap detection**. The first post-outage
reading will be compared against the last row from 2026-09-30 17:35 UTC regardless of the
~43 h gap.

**Consequence: the gap delta will NOT be skipped or capped.** This is verified.

## 2. Verified: counter-reset handling exists, but will not trigger

`Calculate WAN Delta` (code node, deployed):

```js
function computeDelta(currVal, prevVal) {
  if (!hasPrevious) return { delta: 0n, reset: false };
  const c = toBigIntSafe(currVal), p = toBigIntSafe(prevVal);
  if (c < p) return { delta: 0n, reset: true };   // counter wrapped/reset
  return { delta: c - p, reset: false };
}
const isReset = dWan1Rx.reset || dWan1Tx.reset || dWan2Rx.reset || dWan2Tx.reset;
if (isReset) { /* ALL four counters forced to 0 */ }
```

A reset yields **zero**, not the accumulated total. Observed last-known state:

| received_at | uptime | wan1_rx | wan2_rx |
|---|---|---|---|
| 2026-09-30 17:35:23 UTC | 1w3d01:30:18 | 118,246,759,452 | 10,571,906,753 |

`uptime` was 10 days at the last successful read, and the router has kept POSTing since
(so it did not reboot). **VERIFIED: the router did not reset; counters kept increasing.**

**Therefore the first post-recovery reading will produce a delta representing the entire
outage period** (~43 h of real traffic), not zero. This follows directly from the code
above and the counter evidence.

## 3. Verified: this delta lands in a single usage row

`Calculate WAN Delta` emits one object with `usage_at = current.received_at`. There is no
backfill loop — one reading, one delta, one timestamp. The outage interval is **not**
reconstructed across the missing 5-minute slots.

**Impact:** `mikrotik_wan_usage` will contain one row whose magnitude represents ~43 h,
sitting at a single `usage_at` timestamp. Dashboards plotting usage per interval will show
one spike. This is a real distortion, not a cosmetic one.

## 4. Verified: threshold dedup — and a blocking defect

`Check Quota Thresholds` (deployed SQL):

```sql
CASE
    WHEN used_percentage >= 99.0 AND NOT alerted_100 THEN '100'
    WHEN used_percentage >= 95.0 AND NOT alerted_95  THEN '95'
    WHEN used_percentage >= 80.0 AND NOT alerted_80  THEN '80'
    ELSE NULL
END AS triggered_tier
```

Dedup is per `(router_id, interface_name, cycle_start)` — one alert per tier per cycle.
`Update Quota State` upserts with `ON CONFLICT (router_id, interface_name, cycle_start)`.

**BLOCKING DEFECT (verified by live read-only query):** both nodes reference
`alerted_100`, but `quota_alert_state` in production has only:

```
router_id | interface_name | cycle_start | alerted_80 | alerted_95 | last_alert_at
```

`alerted_100` **does not exist**. Running the deployed threshold SQL against production fails:

```
ERROR:  column s.alerted_100 does not exist
HINT:  Perhaps you meant to reference the column "alerted_80".
```

**This means the quota workflow will still fail after the network patch**, at a later node,
with a different error. The patch is necessary but **not sufficient**.

## 5. Current quota state (read-only, inspected 2026-10-02)

| router | iface | quota_gb | used_gb | pct | cycle_start | renewal | a80 | a95 |
|---|---|---|---|---|---|---|---|---|
| home-router-01 | wan1 | 200.00 | 74.39 | 37.20% | 2026-09-19 | 2026-10-19 | f | f |
| home-router-01 | wan2 | 150.00 | 150.12 | **100.00%** | 2026-09-07 | 2026-10-07 | t | t |

**wan2 is already at 100% of quota** with both 80 and 95 flags set. The `alerted_100` flag
is missing, so the 100% tier has never been recorded and will fire on first success.

## 6. Billing-cycle boundary behaviour

`calculate_cycle_boundary_date(target_year, target_month, renewal_day)` clamps to the last
day of month when `renewal_day > last_day_num`; otherwise returns `make_date(y, m, renewal_day)`.
No cycle boundary is crossed by this outage (both cycles started in September and renew in
October), so the accumulated delta is attributed to the **current** cycle.

## 7. `calculate_adaptive_burn_rate` interaction

Uses `elapsed_days = GREATEST(1, today - cycle_start)` and a 7-day weighted moving average
from `view_mikrotik_wan_daily_usage` joined to `quota_day_weights`. The cold-start guard
(`elapsed_days < 3`) does **not** apply here — both cycles are > 3 days old. So
`effective_rate = (wma_7d_rate * 0.60) + (cycle_daily_rate * 0.40)`.

The one large delta will inflate `cycle_daily_rate` for the current cycle.

## 8. What is NOT verified

- Whether the ~43 h delta crosses 80/95/99% for wan1 — depends on post-recovery counters,
  which cannot be known until a reading lands.
- Whether the `alerted_100` defect blocks the workflow *before* or *after* the usage row is
  written. Node ordering in the deployed graph was not fully traced.
- Duplicate-reading handling: **no unique constraint was found** on
  `mikrotik_wan_readings(received_at)`. Replayed webhooks could double-count. Not tested.
- Router-side: whether the scheduler retried and buffered payloads during the outage
  (would produce a burst, not a single delta).

## 9. Do not

- ❌ Replay stored payloads
- ❌ Delete or backfill usage rows
- ❌ Reset alert flags to force/suppress alerts
- ❌ Assume the delta is "correct" — it is *accurate about total bytes* but
  **misrepresents time distribution**, which distorts burn rate and alerting.
- ❌ Treat the network patch as complete — the `alerted_100` defect must be fixed separately.
