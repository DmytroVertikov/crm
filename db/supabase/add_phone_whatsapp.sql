-- Признак «на основном номере есть WhatsApp».
alter table public.clients add column if not exists phone_whatsapp boolean not null default false;
