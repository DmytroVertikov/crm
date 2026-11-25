-- PostgreSQL / Supabase. Та же модель, что в db/schema.sql (SQLite).
create table public.clients (
  id            bigint generated always as identity primary key,
  num           integer not null unique,
  name          text not null,
  phone         text,
  phone_whatsapp boolean not null default false,  -- на основном номере есть WhatsApp
  email         text,
  permit_expiry date,
  next_step     text not null default '',
  -- поля карточки; допустимые значения в config/crm_options.json
  situacion            text,
  tipo_autorizacion    text,
  estado_expediente    text,
  tipo_documento       text,
  otro_documento       text,
  goal                 text not null default '',
  next_note            text not null default '',
  nationality          text,                      -- ISO 3166-1 alpha-2, список в config/countries.json
  nie                  text,
  extra_phones         text[] not null default '{}'
);

create table public.cases (
  id           bigint generated always as identity primary key,
  client_id    bigint not null references public.clients(id) on delete cascade,
  type         text,  -- устарело: тип дела убран из приложения
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

-- Справочник опций (вкладка «Справочник»): один ряд key='dictionary', value = JSON со всеми списками.
create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;

-- Лента дела: единый журнал «дата, действие, комментарий» (одна лента на клиента, на все его дела).
-- Статус дела, шаги и напоминания приложение считает из этих записей.
-- Таблица notes устарела (оставлена для истории); cases пишется как расчётная строка для v_deadlines.
create table if not exists public.case_log (
  id bigint generated always as identity primary key,
  client_id bigint not null references public.clients(id) on delete cascade,
  entry_date date not null,
  action text not null,              -- podacha | zapros | otvet | reshenie | zvonok_out | zvonok_in | msg_out | msg_in | vstrecha | (устар.: zvonok, soobshenie) | primech | zakrytie | plan
  comment text not null default '',
  due_date date,                     -- для zapros: ответить до
  result text,                       -- для reshenie: Одобрено / Отказ / ...
  channel text,                      -- для общения: канал связи
  outcome text,                      -- для общения: результат (необязательно)
  plan text,                         -- для plan: что сделать (запись на будущую дату entry_date)
  done boolean not null default false, -- для plan: выполнено
  created_on date,                   -- для plan: когда задача создана
  done_on date,                      -- для plan: когда выполнена
  moved_on date                      -- для plan: когда в последний раз перенесена
);
create index if not exists idx_case_log_client on public.case_log(client_id, entry_date);
alter table public.case_log enable row level security;
