
create table if not exists move_users (
  emp_id      text primary key,
  full_name   text not null,
  branch      text not null default '',
  role        text not null default 'REQUESTER'
                check (role in ('REQUESTER', 'APPROVER', 'ADMIN')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create index if not exists move_users_role_idx on move_users (role) where active;


create table if not exists assets (
  id           bigint generated always as identity primary key,

  asset_code   text not null unique,

  name         text not null,
  category     text not null default '',
  serial_no    text not null default '',
  brand        text not null default '',
  model        text not null default '',

  branch       text not null default '',
  location     text not null default '',
  holder_name  text not null default '',
  status       text not null default 'in_stock'
                 check (status in ('in_stock', 'out', 'disposed')),

  image_url    text not null default '',
  note         text not null default '',

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists assets_status_idx on assets (status);
create index if not exists assets_branch_idx on assets (branch);
create extension if not exists pg_trgm;

create index if not exists assets_search_idx on assets
  using gin ((
    asset_code || ' ' || name || ' ' || brand || ' ' ||
    model || ' ' || serial_no || ' ' || holder_name
  ) gin_trgm_ops);

create sequence if not exists move_doc_seq;

create or replace function next_move_doc_no() returns text
language plpgsql
as $$
declare
  year_part text := to_char(now() at time zone 'Asia/Bangkok', 'YYYY');
  running   bigint := nextval('move_doc_seq');
begin
  return 'MV-' || year_part || '-' || lpad(running::text, 4, '0');
end;
$$;

create table if not exists move_requests (
  id            bigint generated always as identity primary key,
  doc_no        text not null unique default next_move_doc_no(),

  move_type     text not null check (move_type in ('permanent', 'temporary')),

  reason        text not null,
  destination   text not null default '',
  receiver_name text not null default '',

  expected_out_at    timestamptz not null,
  expected_return_at timestamptz,

  requester_emp_id text not null references move_users (emp_id),
  requester_name   text not null,
  requester_branch text not null default '',
  approver_emp_id  text not null references move_users (emp_id),
  approver_name    text not null,

  status        text not null default 'pending'
                  check (status in ('pending','approved','rejected','cancelled','returned')),

  approved_at   timestamptz,
  rejected_at   timestamptz,
  reject_reason text not null default '',

  returned_at      timestamptz,
  returned_by      text references move_users (emp_id),
  return_note      text not null default '',

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint move_requests_return_date_matches_type check (
    (move_type = 'temporary' and expected_return_at is not null) or
    (move_type = 'permanent' and expected_return_at is null)
  ),

  constraint move_requests_closed_has_timestamp check (
    (status <> 'approved' or approved_at is not null) and
    (status <> 'rejected' or rejected_at is not null) and
    (status <> 'returned' or returned_at is not null)
  ),

  constraint move_requests_only_temporary_returns check (
    status <> 'returned' or move_type = 'temporary'
  )
);

create index if not exists move_requests_requester_idx
  on move_requests (requester_emp_id, created_at desc);

create index if not exists move_requests_approver_pending_idx
  on move_requests (approver_emp_id) where status = 'pending';

create index if not exists move_requests_due_idx
  on move_requests (expected_return_at) where status = 'approved';


create table if not exists move_request_items (
  id          bigint generated always as identity primary key,
  request_id  bigint not null references move_requests (id) on delete cascade,
  asset_id    bigint not null references assets (id),

  asset_code  text not null,
  asset_name  text not null,

  qty         integer not null default 1 check (qty > 0),
  note        text not null default '',

  unique (request_id, asset_id)
);

create index if not exists move_request_items_asset_idx
  on move_request_items (asset_id);


create table if not exists move_photos (
  id          bigint generated always as identity primary key,
  request_id  bigint not null references move_requests (id) on delete cascade,
  url         text not null,
  kind        text not null default 'out' check (kind in ('out', 'return')),
  created_at  timestamptz not null default now()
);

create index if not exists move_photos_request_idx on move_photos (request_id);


create or replace function touch_updated_at() returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists assets_touch on assets;
create trigger assets_touch before update on assets
  for each row execute function touch_updated_at();

drop trigger if exists move_requests_touch on move_requests;
create trigger move_requests_touch before update on move_requests
  for each row execute function touch_updated_at();

create or replace function assert_asset_not_in_open_request() returns trigger
language plpgsql
as $$
declare
  clash text;
begin
  select r.doc_no into clash
  from move_request_items i
  join move_requests r on r.id = i.request_id
  where i.asset_id = new.asset_id
    and i.request_id <> new.request_id
    and r.status in ('pending', 'approved')
  limit 1;

  if clash is not null then
    raise exception 'ทรัพย์สินนี้อยู่ในใบ % ที่ยังไม่ปิด', clash
      using errcode = 'unique_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists move_items_no_double_booking on move_request_items;
create trigger move_items_no_double_booking
  before insert on move_request_items
  for each row execute function assert_asset_not_in_open_request();

create or replace function sync_asset_status_from_request() returns trigger
language plpgsql
as $$
begin
  if new.status = old.status then
    return new;
  end if;

  if new.status = 'approved' then
    update assets a
       set status = case when new.move_type = 'permanent' then 'disposed' else 'out' end
      from move_request_items i
     where i.request_id = new.id
       and a.id = i.asset_id;

  elsif new.status = 'returned' then
    update assets a
       set status = 'in_stock'
      from move_request_items i
     where i.request_id = new.id
       and a.id = i.asset_id;

  end if;

  return new;
end;
$$;

drop trigger if exists move_requests_sync_assets on move_requests;
create trigger move_requests_sync_assets
  after update of status on move_requests
  for each row execute function sync_asset_status_from_request();

create or replace view move_requests_overdue as
select
  r.*,
  (now() - r.expected_return_at) as overdue_by
from move_requests r
where r.status = 'approved'
  and r.move_type = 'temporary'
  and r.expected_return_at < now();

alter table move_users          enable row level security;
alter table assets              enable row level security;
alter table move_requests       enable row level security;
alter table move_request_items  enable row level security;
alter table move_photos         enable row level security;
