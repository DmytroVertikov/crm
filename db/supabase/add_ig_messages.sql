create table public.ig_messages (
  mid          text primary key,
  sender_id    text,
  sender_name  text,
  recipient_id text,
  recipient_name text,
  body         text,
  attachments  jsonb,
  is_echo      boolean not null default false,
  sent_at      timestamptz not null,
  created_at   timestamptz not null default now()
);
create index idx_ig_messages_sent on public.ig_messages(sent_at desc);
-- Без политик: доступ только у Edge Function (service_role).
alter table public.ig_messages enable row level security;
revoke all on public.ig_messages from anon, authenticated;
grant select, insert, update, delete on public.ig_messages to service_role;
