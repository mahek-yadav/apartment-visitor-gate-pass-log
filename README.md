# Apartment Visitor Gate Pass Log Database

## 1. Project overview

This project implements an Apartment Visitor Gate Pass Log using PostgreSQL.

The system records:
- flats and their residents
- visitors and their visitor type
- visitor passes linking a visitor to the flat being visited
- resident approval
- entry and exit events at the gate

The database can answer questions such as:
1. Which visitors are currently inside?
2. Which flats had the most visitors this month?
3. Which visitors stayed longer than four hours?
4. How many delivery visits arrived in each hour?
5. Which passes issued yesterday have no exit record?

## 2. Files

- `schema.sql` - tables, primary keys, foreign keys, checks and indexes.
- `seed.sql` - compact realistic sample data.
- `queries.sql` - required reports plus JSONB, array, joins, grouping, HAVING and subqueries.
- `ER_Diagram.png` - ER diagram.
- `ER_Diagram.pdf` - ER diagram in PDF form.
- `DESIGN_DECISIONS.md` - design choices and rejected alternatives.
- `JSONB_ARRAY_JUSTIFICATION.md` - written argument for every JSONB/array column , weighed    against its normalised alternative.
- `README.md` - MongoDB comparison.

## 3. Run order

Use PostgreSQL / pgAdmin:

```text
1. Create a database, for example: apartment_gate_pass
2. Run schema.sql
3. Run seed.sql
4. Run queries.sql
```

The seed uses `current_date`, so the "yesterday" and "this month" reports continue to make sense when the database is rerun on a different date.

## 4. Main design

The central transaction is a visitor pass.

`visitor -> pass -> gate event`

A pass also links the visitor to the flat and optionally records the resident who approved the visit.

Entry and exit are stored as separate events instead of storing only `entry_time` and `exit_time` in the pass table. This makes the current-inside report derivable from the latest gate event.

## 5. Why JSONB?

`visitors.extra_details` uses JSONB for genuinely variable information.

Examples:
- delivery company
- vehicle number
- vehicle type
- service trade
- ID type
- ID last four digits

Not every visitor has all these fields. A delivery visitor may have a company and vehicle number, while a guest may have only an ID field. JSONB avoids adding many mostly-null columns.

JSONB is queried with PostgreSQL operators such as:
- `->>`
- `@>`

### Normalised alternative rejected

A separate `visitor_details` table could store one row per visitor and attribute type. That would improve strict relational structure but would make simple gate queries require more joins and would require schema changes or an attribute-value design as new optional fields appear. Because these fields are genuinely variable and are not core relational facts used for joins, JSONB is reasonable here.

JSONB is not used for core entities such as flats, residents, passes or gate events because those relationships need normal relational constraints.

## 6. Why an array column?

`flats.parking_slots` uses a PostgreSQL `text[]` because a flat owns a small bounded list of assigned parking slots.

Example:

```text
{A1-01,A1-02}
```

The list is naturally queried as a group using array operators such as `ANY`.

### Normalised alternative rejected

A separate `flat_parking_slots(flat_id, slot_code)` table would be more strictly normalised and would be preferable if parking slots needed their own attributes, history, ownership changes or many-to-many relationships. For this small bounded list, the array is simpler and still belongs to exactly one flat.

## 7. Date and time decisions

`issued_at`, `valid_until` and `event_time` use `timestamptz` because gate events are time-based facts.

Queries use:
- `current_date`
- `date_trunc`
- `extract`
- interval arithmetic

This supports daily, monthly and duration-based reporting.

## 8. MongoDB comparison

The same system could be modelled in MongoDB. One possible document could keep a visitor with pass information and an embedded list of gate events.

### What MongoDB gains

- Flexible fields are natural in documents.
- Visitor-specific attributes do not require a fixed schema.
- Related information can be embedded and read in one document.
- Horizontal scaling and distributed deployment are common strengths of document databases.

### What MongoDB loses / changes

- Strong relational foreign-key enforcement is not the same as PostgreSQL.
- Cross-document transactions are possible but add complexity and are not the default modelling style.
- Repeated information can become duplicated if data is embedded.
- Complex joins/reporting may require aggregation pipelines.

### CAP and BASE vs ACID

CAP describes trade-offs in a distributed system when a network partition occurs: consistency, availability and partition tolerance cannot all be guaranteed simultaneously.

BASE is a common distributed-database approach emphasising Basically Available, Soft state and Eventual consistency.

PostgreSQL's relational design is centred on ACID transactions:
- Atomicity
- Consistency
- Isolation
- Durability

For a gate-pass system, ACID is useful because an entry/exit record should be reliable and constraints should prevent invalid references. A MongoDB design can also provide ACID transactions, so the comparison is about modelling and distributed-system trade-offs rather than saying "MongoDB has no transactions."

## 9. Core relationship summary

- One flat can have many residents.
- One flat can have many passes.
- One resident can approve many passes.
- One visitor can have many passes.
- One pass can have many gate events.
- Each gate event belongs to exactly one pass.

## 10. Design principle

JSONB and arrays are used only where they fit the data. Core entities and relationships remain normalised relational tables with primary keys, foreign keys and constraints.

## ER diagram notation

The ER diagram uses written `1 : many` relationship notation instead of crow's-foot notation. The labels show the cardinality for each relationship.
