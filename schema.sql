-- Apartment Visitor Gate Pass Log
-- PostgreSQL schema

create database apartment_gate_pass

drop table if exists gate_events cascade;
drop table if exists passes cascade;
drop table if exists visitors cascade;
drop table if exists residents cascade;
drop table if exists flats cascade;

create table flats (
    flat_id serial primary key,
    flat_number varchar(10) not null unique,
    block varchar(10) not null,
    floor_no integer not null check (floor_no >= 0),
    parking_slots text[] not null default '{}'
);

create table residents (
    resident_id serial primary key,
    flat_id integer not null references flats(flat_id),
    full_name varchar(100) not null,
    phone varchar(15) not null unique,
    email varchar(120) unique,
    resident_type varchar(20) not null
        check (resident_type in ('owner', 'tenant', 'family')),
    is_primary boolean not null default false
);

create table visitors (
    visitor_id serial primary key,
    full_name varchar(100) not null,
    phone varchar(15) not null unique,
    visitor_type varchar(20) not null
        check (visitor_type in ('guest', 'delivery', 'service')),
    extra_details jsonb not null default '{}'::jsonb
);

create table passes (
    pass_id serial primary key,
    pass_code varchar(20) not null unique,
    visitor_id integer not null references visitors(visitor_id),
    flat_id integer not null references flats(flat_id),
    approved_by_resident_id integer references residents(resident_id),
    purpose varchar(120) not null,
    issued_at timestamptz not null,
    valid_until timestamptz not null,
    check (valid_until > issued_at)
);

create table gate_events (
    event_id serial primary key,
    pass_id integer not null references passes(pass_id) on delete cascade,
    event_type varchar(10) not null
        check (event_type in ('entry', 'exit')),
    event_time timestamptz not null,
    gate_name varchar(30) not null default 'main gate',
    notes varchar(200)
);

create index idx_passes_issued_at on passes(issued_at);
create index idx_gate_events_pass_time on gate_events(pass_id, event_time);
create index idx_visitors_extra_details on visitors using gin(extra_details);
