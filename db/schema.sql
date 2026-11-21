-- Тестовая база: клиенты, дела по резиденциям, заметки.
-- Модель повторяет данные прототипа в index.html.
PRAGMA foreign_keys = ON;

CREATE TABLE clients (
  id           INTEGER PRIMARY KEY,
  num          INTEGER NOT NULL UNIQUE,          -- номер клиента
  name         TEXT    NOT NULL,
  phone        TEXT,
  email        TEXT,
  permit_expiry DATE,                            -- срок действия текущего вида на жительство
  next_step    TEXT    NOT NULL DEFAULT ''       -- ручной «следующий шаг»
);

CREATE TABLE cases (
  id           INTEGER PRIMARY KEY,
  client_id    INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  type         TEXT    NOT NULL CHECK (type IN
                 ('Первичная подача','Продление','Модификация','Воссоединение семьи')),
  filed        DATE    NOT NULL,                 -- дата подачи
  req_received DATE,                             -- получен запрос от ведомства
  req_due      DATE,                             -- срок ответа на запрос
  answered     DATE,                             -- дата отправки ответа
  result_text  TEXT,                             -- «Одобрено» / «Отказ»
  result_date  DATE
);

CREATE TABLE notes (
  id        INTEGER PRIMARY KEY,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  kind      TEXT NOT NULL CHECK (kind IN ('note','event')),
  text      TEXT NOT NULL,
  date      DATE NOT NULL
);

CREATE INDEX idx_cases_client ON cases(client_id);
CREATE INDEX idx_notes_client ON notes(client_id);

-- Что горит: открытые запросы и истекающие разрешения, по возрастанию срока.
CREATE VIEW v_deadlines AS
  SELECT c.id AS client_id, c.num, c.name, 'Ответ на запрос' AS what, k.req_due AS due,
         CAST(julianday(k.req_due) - julianday('now','localtime','start of day') AS INTEGER) AS days_left
    FROM clients c JOIN cases k ON k.client_id = c.id
   WHERE k.req_received IS NOT NULL AND k.answered IS NULL AND k.result_text IS NULL
  UNION ALL
  SELECT c.id, c.num, c.name, 'Истекает разрешение', c.permit_expiry,
         CAST(julianday(c.permit_expiry) - julianday('now','localtime','start of day') AS INTEGER)
    FROM clients c
   WHERE c.permit_expiry IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM cases k WHERE k.client_id = c.id AND k.result_text IS NULL)
  ORDER BY due;
