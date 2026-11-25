-- Даты действий менеджера по задачам (записи case_log с action = 'plan'): создание, выполнение, перенос.
-- Нужны для «последней активности» клиента.
alter table public.case_log add column if not exists created_on date;
alter table public.case_log add column if not exists done_on date;
alter table public.case_log add column if not exists moved_on date;
