-- Apartment Visitor Gate Pass Log
-- All queries are PostgreSQL-compatible.
-- Sample outputs are based on the supplied seed when run on 2026-10-02.

-- 1. Visitors currently inside the premises.
select v.full_name, p.pass_code, f.flat_number, e.event_time as last_entry
from visitors v
join passes p on p.visitor_id = v.visitor_id
join flats f on f.flat_id = p.flat_id
join gate_events e on e.pass_id = p.pass_id
where e.event_type = 'entry'
  and not exists (
      select 1
      from gate_events x
      join passes xp on xp.pass_id = x.pass_id
      where xp.visitor_id = v.visitor_id
        and x.event_time > e.event_time
  )
order by e.event_time desc;

-- sample output:
-- Neha Delivery | VIS-1002 | A-102 | yesterday 10:15
-- (one current visitor)

-- 2. Flats with the most visitors this month.
select f.flat_number, count(*) as visitor_count
from flats f
join passes p on p.flat_id = f.flat_id
where p.issued_at >= date_trunc('month', current_date)
  and p.issued_at < date_trunc('month', current_date) + interval '1 month'
group by f.flat_number
having count(*) = (
    select max(visitor_count)
    from (
        select count(*) as visitor_count
        from passes
        where issued_at >= date_trunc('month', current_date)
          and issued_at < date_trunc('month', current_date) + interval '1 month'
        group by flat_id
    ) x
)
order by f.flat_number;

-- sample output on 2026-10-02:
-- A-101 | 1
-- A-102 | 1
-- A-201 | 1


-- 3. Visitors who stayed longer than four hours.
select v.full_name,
       p.pass_code,
       round(extract(epoch from (exit_event.event_time - entry_event.event_time)) / 3600, 2)
           as stay_hours
from passes p
join visitors v on v.visitor_id = p.visitor_id
join gate_events entry_event
  on entry_event.pass_id = p.pass_id and entry_event.event_type = 'entry'
join gate_events exit_event
  on exit_event.pass_id = p.pass_id and exit_event.event_type = 'exit'
where exit_event.event_time - entry_event.event_time > interval '4 hours'
order by stay_hours desc;

-- sample output on 2026-10-02:
-- CleanPro Team       | VIS-1008 | 5.50
-- Vivek Kumar         | VIS-1003 | 5.17
-- Maya Roy            | VIS-1012 | 5.00
-- Karan Verma         | VIS-1016 | 4.83
-- Pooja Sharma        | VIS-1005 | 4.75
-- Anjali Desai        | VIS-1010 | 4.75
-- Suresh Electrician  | VIS-1004 | 4.67
-- Pooja Sharma        | VIS-1014 | 4.50
-- Karan Verma         | VIS-1017 | 4.50
-- Suresh Electrician  | VIS-1013 | 4.17

-- 4. Number of delivery visits arriving in each hour of the day.
select extract(hour from e.event_time)::integer as arrival_hour,
       count(*) as delivery_visits
from gate_events e
join passes p on p.pass_id = e.pass_id
join visitors v on v.visitor_id = p.visitor_id
where e.event_type = 'entry'
  and v.visitor_type = 'delivery'
group by extract(hour from e.event_time)
order by arrival_hour;

-- sample output:
-- 09 | 1
-- 10 | 1
-- 12 | 1


-- 5. Passes issued yesterday that have no exit record.
select p.pass_code, v.full_name, f.flat_number, p.issued_at
from passes p
join visitors v on v.visitor_id = p.visitor_id
join flats f on f.flat_id = p.flat_id
where p.issued_at::date = current_date - 1
  and not exists (
      select 1
      from gate_events e
      where e.pass_id = p.pass_id
        and e.event_type = 'exit'
  )
order by p.issued_at;

-- sample output on 2026-10-02:
-- VIS-1002 | Neha Delivery | A-102 | yesterday 10:15


