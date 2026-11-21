-- PostgreSQL / Supabase. Та же модель, что в db/schema.sql (SQLite).
create table public.clients (
  id            bigint generated always as identity primary key,
  num           integer not null unique,
  name          text not null,
  phone         text,
  email         text,
  permit_expiry date,
  next_step     text not null default '',
  -- поля карточки; допустимые значения в config/crm_options.json
  situacion            text,
  tipo_autorizacion    text,
  estado_expediente    text,
  tipo_documento       text,
  otro_documento       text,
  resultado_expediente text not null default 'pendiente',
  goal                 text not null default '',
  next_note            text not null default ''
);

create table public.cases (
  id           bigint generated always as identity primary key,
  client_id    bigint not null references public.clients(id) on delete cascade,
  type         text not null check (type in ('Первичная подача','Продление','Модификация','Воссоединение семьи')),
  filed        date not null,
  req_received date,
  req_due      date,
  answered     date,
  result_text  text,
  result_date  date
);

create table public.notes (
  id        bigint generated always as identity primary key,
  client_id bigint not null references public.clients(id) on delete cascade,
  kind      text not null check (kind in ('note','event')),
  text      text not null,
  date      date not null
);

create index idx_cases_client on public.cases(client_id);
create index idx_notes_client on public.notes(client_id);

create view public.v_deadlines with (security_invoker = true) as
  select c.id as client_id, c.num, c.name, 'Ответ на запрос' as what, k.req_due as due,
         (k.req_due - current_date) as days_left
    from public.clients c join public.cases k on k.client_id = c.id
   where k.req_received is not null and k.answered is null and k.result_text is null
  union all
  select c.id, c.num, c.name, 'Истекает разрешение', c.permit_expiry,
         (c.permit_expiry - current_date)
    from public.clients c
   where c.permit_expiry is not null
     and not exists (select 1 from public.cases k where k.client_id = c.id and k.result_text is null)
  order by due;

-- Данные клиентов: доступ только после входа. Политики добавим вместе с авторизацией.
alter table public.clients enable row level security;
alter table public.cases   enable row level security;
alter table public.notes   enable row level security;
