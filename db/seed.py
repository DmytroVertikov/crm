#!/usr/bin/env python3
"""Создаёт db/crm_test.db: схема + тестовые данные. Даты считаются от сегодняшнего дня,
поэтому запустите скрипт заново, чтобы «сдвинуть» сроки. Запуск: python3 db/seed.py"""
import random, sqlite3, pathlib
from datetime import date, timedelta

HERE = pathlib.Path(__file__).parent
DB = HERE / "crm_test.db"
TODAY = date.today()
def off(n): return (TODAY + timedelta(days=n)).isoformat() if n is not None else None

# (num, имя, срок ВНЖ, дело | None, заметки)  дело = (тип, подана, запрос получен, срок ответа, ответ, результат, дата результата)
HAND = [
 (1031,"Иванова Мария",75,("Продление",-40,-12,3,None,None,None),[("note","Клиентка прислала новый padrón, нужно приложить к ответу.",-11)]),
 (1034,"Петров Алексей",None,("Первичная подача",-95,None,None,None,None,None),[("note","Подали через сеть. Ведомство пока молчит.",-95)]),
 (1029,"Смирнова Ольга",28,None,[("note","Работает по контракту, документы от работодателя будут к концу месяца.",-20)]),
 (1022,"Козлов Дмитрий",96,None,[]),
 (1017,"Назарова Елена",210,None,[]),
 (1038,"Кузнецов Игорь",50,("Модификация",-8,None,None,None,None,None),[]),
 (1026,"Белова Анна",330,("Продление",-60,-30,-16,-18,None,None),[("note","Ответ ушёл заранее, ждём решение.",-18)]),
 (1011,"Орлов Сергей",-5,None,[("note","Клиент не отвечал на сообщения. Попробовать позвонить.",-9)]),
 (1008,"Фёдорова Ксения",400,("Продление",-150,-100,-85,-90,"Одобрено",-10),[]),
 (1040,"Тихонов Павел",150,("Первичная подача",-30,-3,9,None,None,None),[]),
]
SURN = ["Морозов","Волков","Соколов","Лебедев","Новиков","Егоров","Павлов","Зайцев","Крылов","Макаров",
        "Григорьев","Мельник","Ткаченко","Бондаренко","Шевченко","Романов","Фролов","Гусев","Комаров","Леонов"]
GIVEN = ["Андрей","Татьяна","Виктор","Наталья","Максим","Юлия","Роман","Инна","Артём","Светлана"]
TYPES = ["Первичная подача","Продление","Модификация","Воссоединение семьи"]

def gen_case(r):
    t = r.choice(TYPES); filed = -r.randint(5, 180)
    stage = r.choice(["wait","request","answered","closed"])
    if stage == "wait": return (t, filed, None, None, None, None, None)
    if stage == "request":
        recv = -r.randint(1, 18); return (t, min(filed, recv - 5), recv, recv + 15, None, None, None)
    recv = min(filed + r.randint(10, 40), -4); filed = min(filed, recv - 5); due = recv + 15
    ans = min(recv + r.randint(2, 12), -1)
    if stage == "answered": return (t, filed, recv, due, ans, None, None)
    return (t, filed, recv, due, ans, r.choice(["Одобрено","Одобрено","Одобрено","Отказ"]), min(ans + r.randint(10, 60), -1))

def main():
    r = random.Random(42)
    rows = list(HAND)
    for i in range(20):
        name = f"{SURN[i]} {r.choice(GIVEN)}"
        has_case = r.random() < 0.7
        rows.append((1043 + i, name, r.choice([None, r.randint(-30, 420), r.randint(10, 120)]),
                     gen_case(r) if has_case else None, []))
    if DB.exists(): DB.unlink()
    con = sqlite3.connect(DB)
    con.executescript((HERE / "schema.sql").read_text(encoding="utf-8"))
    for n, (num, name, exp, case, notes) in enumerate(rows, 1):
        phone = f"+34 611 000 {100 + n:03d}"
        email = f"client{num}@example.test"
        con.execute("INSERT INTO clients(id,num,name,phone,email,permit_expiry) VALUES (?,?,?,?,?,?)",
                    (n, num, name, phone, email, off(exp)))
        if case:
            t, f, rc, rd, an, res, rdate = case
            con.execute("INSERT INTO cases(client_id,type,filed,req_received,req_due,answered,result_text,result_date)"
                        " VALUES (?,?,?,?,?,?,?,?)", (n, t, off(f), off(rc), off(rd), off(an), res, off(rdate)))
        for kind, text, d in notes:
            con.execute("INSERT INTO notes(client_id,kind,text,date) VALUES (?,?,?,?)", (n, kind, text, off(d)))
    con.commit()
    for t in ("clients", "cases", "notes"):
        print(t, con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])
    print("\nБлижайшие сроки:")
    for row in con.execute("SELECT num,name,what,due,days_left FROM v_deadlines LIMIT 8"): print(" ", row)
    con.close()

if __name__ == "__main__": main()
