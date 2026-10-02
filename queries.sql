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

-- 6. JSONB: find delivery visitors from a specific company.
select full_name, phone, extra_details->>'company' as company
from visitors
where extra_details @> '{"company":"QuickKart"}';

-- sample output:
-- Neha Delivery | 9100000002 | QuickKart

-- 7. JSONB: extract vehicle number from visitors whose JSON says they have a vehicle.
select full_name,
       extra_details->>'vehicle_number' as vehicle_number
from visitors
where extra_details @> '{"has_vehicle":true}'
order by full_name;

-- sample output:
-- Amit Courier | MH05GH9087
-- Neha Delivery | MH05CD2211
-- Swiggy Partner | MH05JK1190

-- 8. Array query: flats containing a particular parking slot.
select flat_number, parking_slots
from flats
where 'A1-01' = any(parking_slots);

-- sample output:
-- A-101 | {A1-01,A1-02}

-- 9. Join: visitor log with resident approval.
select p.pass_code,
       v.full_name as visitor,
       f.flat_number,
       r.full_name as approved_by,
       p.purpose
from passes p
join visitors v on v.visitor_id = p.visitor_id
join flats f on f.flat_id = p.flat_id
join residents r on r.resident_id = p.approved_by_resident_id
order by p.issued_at desc
limit 10;

-- sample output on 2026-10-02:
-- VIS-1002 | Neha Delivery | A-102 | Kabir Shah | food delivery
-- VIS-1003 | Vivek Kumar | A-201 | Nisha Patel | family visit
-- VIS-1001 | Rohan Gupta | A-101 | Aarav Mehta | guest visit
-- VIS-1004 | Suresh Electrician | A-202 | Arjun Rao | electrical repair
-- VIS-1005 | Pooja Sharma | B-101 | Simran Kapoor | guest visit
-- VIS-1006 | Amit Courier | B-102 | Dev Malhotra | courier delivery
-- VIS-1007 | Karan Verma | B-201 | Anaya Singh | guest visit
-- VIS-1008 | CleanPro Team | B-202 | Rahul Jain | housekeeping
-- VIS-1009 | Swiggy Partner | B-301 | Ishita Verma | delivery
-- VIS-1010 | Anjali Desai | B-302 | Vikram Joshi | guest visit

-- 10. Grouping + having: flats that received at least two visits this month.
select f.flat_number, count(*) as visitor_count
from flats f
join passes p on p.flat_id = f.flat_id
where p.issued_at >= date_trunc('month', current_date)
  and p.issued_at < date_trunc('month', current_date) + interval '1 month'
group by f.flat_number
having count(*) >= 2
order by visitor_count desc, f.flat_number;

-- sample output  on 2026-10-02:
-- NO OUTPUT because max 1 visitor only visited as per the seed data

-- 11. Subquery: visitors whose total number of passes is above the average.
select v.full_name, count(*) as pass_count
from visitors v
join passes p on p.visitor_id = v.visitor_id
group by v.visitor_id, v.full_name
having count(*) > (
    select avg(pass_count)
    from (
        select visitor_id, count(*) as pass_count
        from passes
        group by visitor_id
    ) x
)
order by pass_count desc;

-- sample output :
-- Rohan Gupta  | 3
-- Vivek Kumar  | 3
-- Pooja Sharma | 3
-- Karan Verma  | 2

-- 12. Date/time reporting: average stay by visitor type.
select v.visitor_type,
       round(avg(extract(epoch from (exit_event.event_time - entry_event.event_time)) / 3600), 2)
           as average_stay_hours
from visitors v
join passes p on p.visitor_id = v.visitor_id
join gate_events entry_event
  on entry_event.pass_id = p.pass_id and entry_event.event_type = 'entry'
join gate_events exit_event
  on exit_event.pass_id = p.pass_id and exit_event.event_type = 'exit'
group by v.visitor_type
order by average_stay_hours desc;

-- sample output (query 12):
-- service   | 4.78
-- guest     | 4.42
-- delivery  | 0.54
