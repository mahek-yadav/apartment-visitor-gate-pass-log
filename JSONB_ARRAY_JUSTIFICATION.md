# JSONB and Array Columns: Justification

The database has exactly two JSONB/array columns. Everything else (identity, passes, gate events, approvals, timestamps) is in ordinary typed columns because it has the same shape in every row, must be checked by the database, and is used in joins.

| Column | Type | Table |
|---|---|---|
| `extra_details` | `jsonb` | `visitors` |
| `parking_slots` | `text[]` | `flats` |

---

## 1. `visitors.extra_details` (JSONB)

**What is stored:** facts that depend on the kind of visitor. Name, phone and `visitor_type` stay as normal columns.

| Visitor type | Example keys |
|---|---|
| Delivery | `company`, `has_vehicle`, `vehicle_no` |
| Service | `trade`, `agency` |
| Guest | `id_proof` (type, last 4 digits), `has_vehicle` |

**Why JSONB**
- The attributes truly differ by visitor type, and many are optional (a cyclist has no vehicle).
- New visitor types can be added with no `ALTER TABLE`.
- They are displayed and filtered, never used as join keys.
- PostgreSQL can still query them:

```sql
SELECT full_name, extra_details->>'company' AS company FROM visitors WHERE visitor_type = 'DELIVERY';
SELECT full_name FROM visitors WHERE extra_details @> '{"has_vehicle": true}';
```

**Normalised alternatives rejected**
- *Many nullable columns:* mostly NULLs, a schema change for every new detail, and nothing stops a guest row from holding a `trade`.
- *Key-value table `(visitor_id, key, value)`:* every value becomes text and reading one visitor needs a join and pivot. It is JSONB rebuilt badly by hand.
- *One table per visitor type:* clean, but extra tables and a join to the right one on every query.

| | JSONB | Nullable columns | Key-value table |
|---|---|---|---|
| Different fields per type | Yes | Yes, many NULLs | Yes |
| New field with no schema change | Yes | No | Yes |
| Database checks inner types | No | Yes | No |
| Foreign keys on inner fields | No | Yes | No |
| Read one visitor's details | Same row | Same row | Join + pivot |

**Verdict: JSONB is justified.** The varying part really varies and is only displayed and filtered.

**It would become wrong if:** we joined on `extra_details->>'company'` to a companies table, or had to *guarantee* that every delivery visitor has a company. Both need real columns with constraints.

---

## 2. `flats.parking_slots` (array)

**What is stored:** the slot codes assigned to a flat, e.g. `{P-12,P-13}` (`{}` if none).

**Why an array**
- A small, bounded list of simple labels owned by one flat.
- Read together with the flat, with no join.
- Array tools are enough:

```sql
SELECT block, flat_number FROM flats WHERE 'P-12' = ANY(parking_slots);
SELECT block, flat_number, COALESCE(array_length(parking_slots, 1), 0) AS slots FROM flats;
```

**Normalised alternative rejected:** `flat_parking_slots(flat_id, slot_code)`, with `UNIQUE (slot_code)`. Correct in theory, but it adds a table and a join for what is a short label list.

| | Array | Separate table |
|---|---|---|
| Extra tables | 0 | 1 |
| Read a flat with its slots | Same row | Join |
| Same slot given to two flats | Not prevented | Prevented by `UNIQUE` |
| Slot with its own attributes | No | Yes |

**Verdict: an array is justified** for the current scope. The price paid is that the database cannot stop one slot appearing in two flats. This check finds such mistakes (it should return 0 rows):

```sql
SELECT slot, COUNT(*) FROM flats, unnest(parking_slots) AS slot GROUP BY slot HAVING COUNT(*) > 1;
```

**It would become wrong if:** a slot needed its own attributes (covered, EV charging, rent, history), or the database had to guarantee one owner per slot. Then it should be a normalised table.

---

## Summary

| Column | Keep as | Switch to normalised if |
|---|---|---|
| `visitors.extra_details` | JSONB | inner values need foreign keys or enforced required fields |
| `flats.parking_slots` | `text[]` | slots get their own attributes, or need one-owner-per-slot enforcement |

**Rule used:** normal column if the data is the same in every row, must be checked, or is joined. JSONB or an array only for small, variable or list-shaped leftovers.
