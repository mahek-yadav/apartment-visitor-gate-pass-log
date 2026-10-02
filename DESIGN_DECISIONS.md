# Design Decisions and Alternatives

## Decision 1 - Separate `gate_events` from `passes`

### Chosen
A pass has many gate events. Each event is `entry` or `exit`.

### Reason
The requirement is to record entry and exit events and derive who is still inside. Keeping events separate also allows more than one gate event to be recorded for a pass if the operational process later requires it.

### Rejected alternative
Store `entry_time` and `exit_time` directly in `passes`.

### Trade-off
The alternative is simpler for a single entry and single exit, but it makes event history less flexible. The chosen design needs a join or subquery for reports.

---

## Decision 2 - JSONB for variable visitor details

### Chosen
`visitors.extra_details jsonb`

### Reason
Visitor-specific fields vary by visitor type. Delivery visitors may have company and vehicle information; service visitors may have trade information; guests may have identification details.

### Rejected alternative
Create many nullable columns or a generic key-value table.

### Trade-off
JSONB gives flexibility and simple extraction, but values inside JSONB do not have the same relational foreign-key and type enforcement as normal columns.

### Example operators
```sql
extra_details->>'company'
extra_details @> '{"has_vehicle":true}'
```

---

## Decision 3 - Array for parking slots

### Chosen
`flats.parking_slots text[]`

### Reason
Each flat has a small bounded list of assigned slot codes. The slots are simple values owned by the flat.

### Rejected alternative
`flat_parking_slots(flat_id, slot_code)`

### Trade-off
The normalised table would be better if a parking slot needed its own attributes, status or history. The array is shorter and convenient for the current scope.

---

## Decision 4 - `timestamptz`

### Chosen
Use `timestamptz` for pass and event timestamps.

### Reason
Gate records are time-sensitive. PostgreSQL can handle timezone-aware timestamps and interval calculations.

### Rejected alternative
Store only a `date` and a separate text time.

### Trade-off
The chosen approach supports direct duration calculations and avoids treating time as plain text.

---

## Decision 5 - Resident approval

### Chosen
`passes.approved_by_resident_id` is a foreign key to `residents`.

### Reason
A gate pass is more useful when the security supervisor can identify which resident approved it.

### Rejected alternative
Store only the resident name in the pass.

### Trade-off
The foreign key prevents inconsistent resident references and avoids duplicated resident names.

---

## JSONB / Array defence

The JSONB and array columns are deliberately limited to information that is variable or naturally list-shaped. Core facts such as visitor identity, flat identity, pass identity and gate events are relational.

This avoids using JSONB as an excuse to avoid database design.
