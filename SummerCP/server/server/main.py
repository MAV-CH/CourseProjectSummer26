import hashlib
import threading
import time
import subprocess
import datetime
import glob
import os

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
import pathlib

import io
import csv

import secrets

load_dotenv()

app = FastAPI(title="Система проката инструментов")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_CONFIG = {
    'dbname': os.getenv('DB_NAME', 'postgres'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'options': '-c search_path=summer_cp'
}

BACKUP_DIR = os.path.join(os.path.dirname(__file__), "backups")
if not os.path.exists(BACKUP_DIR):
    os.makedirs(BACKUP_DIR)

#хранилище сессий
sessions = {}


def get_db_connection():
    try:
        conn = psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)
        return conn
    except Exception as e:
        print(f"Ошибка подключения к БД: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def schedule_backup(interval_hours=6):
    def backup_worker():
        while True:
            try:
                time.sleep(interval_hours * 3600)

                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                backup_file = os.path.join(BACKUP_DIR, f"auto_backup_{timestamp}.sql")

                dbname = DB_CONFIG['dbname']
                user = DB_CONFIG['user']
                password = DB_CONFIG['password']
                host = DB_CONFIG['host']
                port = DB_CONFIG['port']

                env = os.environ.copy()
                env['PGPASSWORD'] = password

                cmd = [
                    'pg_dump',
                    '-h', host,
                    '-p', str(port),
                    '-U', user,
                    '-d', dbname,
                    '-F', 'p',
                    '-f', backup_file
                ]

                result = subprocess.run(cmd, env=env, capture_output=True, text=True)

                if result.returncode == 0:
                    print(f"[{datetime.datetime.now()}] Автоматический бэкап создан: {backup_file}")
                    auto_backups = sorted(glob.glob(os.path.join(BACKUP_DIR, "auto_backup_*.sql")))
                    while len(auto_backups) > 10:
                        os.remove(auto_backups.pop(0))
                else:
                    print(f"[{datetime.datetime.now()}] Ошибка авто-бэкапа: {result.stderr}")

            except Exception as e:
                print(f"[{datetime.datetime.now()}] Ошибка в планировщике бэкапов: {e}")

    thread = threading.Thread(target=backup_worker, daemon=True)
    thread.start()
    print("Планировщик автоматических бэкапов запущен (интервал: 6 часов)")


schedule_backup(6)


def check_role(allowed_roles: list, token: str = Header(...)):
    if token not in sessions:
        raise HTTPException(status_code=401, detail="Неавторизован")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            user_id = sessions[token]
            cur.execute("SELECT u_role FROM users WHERE id = %s", (user_id,))
            user = cur.fetchone()
            if not user or user['u_role'] not in allowed_roles:
                raise HTTPException(status_code=403, detail="Недостаточно прав")
            return user['u_role']
    finally:
        conn.close()


#модели данных
class Instrument(BaseModel):
    id: int
    i_name: str
    price: float
    i_more: str


class UserCreate(BaseModel):
    u_name: str
    u_password: str
    u_role: str


class DiscountApply(BaseModel):
    discount_percent: float


class UserUpdate(BaseModel):
    u_name: str
    u_password: Optional[str] = None
    u_role: str


class Customer(BaseModel):
    id: int
    l_name: str
    f_name: str
    v_name: Optional[str]
    phone: str
    passport_number: str
    passport_home: str


class CustomerCreate(BaseModel):
    l_name: str
    f_name: str
    v_name: Optional[str] = ""
    phone: str
    passport_number: str
    passport_home: str


class InstrumentCreate(BaseModel):
    i_name: str
    price: float
    i_more: str = "-"


class OrderCreate(BaseModel):
    id_customer: int
    id_instrument: int
    id_user: int
    count_days: int
    o_more: str = "-"


class OrderExtend(BaseModel):
    order_id: int
    extra_days: int


class LoginRequest(BaseModel):
    username: str
    password: str


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


# для сайта
@app.get("/")
async def root():
    html_path = pathlib.Path(__file__).parent.parent.parent / "site" / "site" / "main_site.html"
    if not html_path.exists():
        return HTMLResponse(content="<h1>Сайт не найден</h1>", status_code=404)
    with open(html_path, "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/api/instruments")
async def get_instruments(search: Optional[str] = None):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if search and search.strip():
                cur.execute(
                    "SELECT id, i_name, price, i_more, i_status FROM instrument WHERE i_name ILIKE %s ORDER BY id",
                    (f'%{search.strip()}%',)
                )
            else:
                cur.execute("SELECT id, i_name, price, i_more, i_status FROM instrument ORDER BY id")
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


#для приложения

@app.post("/api/auth/login")
async def login(login_data: LoginRequest):
    print(f"DEBUG: Попытка входа - {login_data.username}")
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, u_name, u_password, u_role FROM users WHERE u_name = %s",
                (login_data.username,)
            )
            user = cur.fetchone()

            if not user:
                raise HTTPException(status_code=401, detail="Неверный логин или пароль")

            hashed_input = hash_password(login_data.password)

            if user['u_password'] != hashed_input:
                raise HTTPException(status_code=401, detail="Неверный логин или пароль")

            token = secrets.token_urlsafe(32)
            sessions[token] = user['id']

            return {
                "success": True,
                "token": token,
                "user_id": user['id'],
                "username": user['u_name'],
                "role": user['u_role']
            }
    finally:
        conn.close()


@app.post("/api/auth/logout")
async def logout(token: str):
    if token in sessions:
        del sessions[token]
    return {"success": True}


@app.get("/api/auth/check")
async def check_auth(token: str):
    if token in sessions:
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                user_id = sessions[token]
                cur.execute("SELECT id, u_name, u_role FROM users WHERE id = %s", (user_id,))
                user = cur.fetchone()
                if user:
                    return {"success": True, "user": dict(user)}
        finally:
            conn.close()
    return {"success": False}


#клиенты
@app.get("/api/app/customers")
async def get_customers(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    c.id,
                    c.l_name,
                    c.f_name,
                    c.v_name,
                    c.phone,
                    p.p_number as passport_number,
                    p.p_home as passport_home
                FROM customer c
                JOIN passport p ON c.id_passport = p.id
                ORDER BY c.id
            """)

            rows = cur.fetchall()
            customers = []

            for row in rows:
                customer = dict(row)
                if customer.get('v_name') is None:
                    customer['v_name'] = ''
                if customer.get('passport_home') is None:
                    customer['passport_home'] = ''

                customers.append(customer)

            return customers

    except Exception as e:
        print(f"Ошибка при получении клиентов: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка сервера: {str(e)}")
    finally:
        conn.close()


@app.get("/api/app/customers/{customer_id}")
async def get_customer(customer_id: int, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    c.id,
                    c.l_name,
                    c.f_name,
                    c.v_name,
                    c.phone,
                    p.p_number as passport_number,
                    p.p_home as passport_home
                FROM customer c
                JOIN passport p ON c.id_passport = p.id
                WHERE c.id = %s
            """, (customer_id,))

            customer = cur.fetchone()
            if not customer:
                raise HTTPException(status_code=404, detail="Клиент не найден")

            result = dict(customer)
            if result.get('v_name') is None:
                result['v_name'] = ''
            if result.get('passport_home') is None:
                result['passport_home'] = ''

            return result

    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка при получении клиента {customer_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.post("/api/app/customers")
async def create_customer(customer: CustomerCreate, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM passport WHERE p_number = %s",
                (customer.passport_number,)
            )
            existing_passport = cur.fetchone()

            if existing_passport:
                raise HTTPException(status_code=400, detail="Паспорт с таким номером уже существует")

            cur.execute(
                "INSERT INTO passport (p_number, p_home) VALUES (%s, %s) RETURNING id",
                (customer.passport_number, customer.passport_home)
            )
            passport_id = cur.fetchone()['id']

            cur.execute(
                """INSERT INTO customer (id_passport, l_name, f_name, v_name, phone) 
                   VALUES (%s, %s, %s, %s, %s) RETURNING id""",
                (passport_id, customer.l_name, customer.f_name,
                 customer.v_name if customer.v_name else '',
                 customer.phone)
            )
            customer_id = cur.fetchone()['id']

            conn.commit()
            return {"id": customer_id, "message": "Клиент успешно добавлен"}

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        print(f"Ошибка при создании клиента: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/customers/{customer_id}")
async def update_customer(customer_id: int, customer: CustomerCreate, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id_passport FROM customer WHERE id = %s", (customer_id,))
            result = cur.fetchone()
            if not result:
                raise HTTPException(status_code=404, detail="Клиент не найден")

            passport_id = result['id_passport']

            cur.execute("""
                SELECT c.id FROM customer c 
                JOIN passport p ON c.id_passport = p.id 
                WHERE p.p_number = %s AND c.id != %s
            """, (customer.passport_number, customer_id))

            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Паспорт с таким номером уже принадлежит другому клиенту")

            cur.execute(
                "UPDATE passport SET p_number = %s, p_home = %s WHERE id = %s",
                (customer.passport_number, customer.passport_home, passport_id)
            )

            cur.execute(
                """UPDATE customer 
                   SET l_name = %s, f_name = %s, v_name = %s, phone = %s 
                   WHERE id = %s""",
                (customer.l_name, customer.f_name,
                 customer.v_name if customer.v_name else '',
                 customer.phone, customer_id)
            )

            conn.commit()
            return {"message": "Клиент успешно обновлен"}

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        print(f"Ошибка при обновлении клиента {customer_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.delete("/api/app/customers/{customer_id}")
async def delete_customer(customer_id: int, token: str = Header(...)):
    check_role(['старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) FROM orders 
                WHERE id_customer = %s AND status IN ('неоплачено', 'оплачено')
            """, (customer_id,))
            active_orders = cur.fetchone()

            if active_orders and active_orders['count'] > 0:
                raise HTTPException(
                    status_code=400,
                    detail="Нельзя удалить клиента с активными заказами"
                )

            cur.execute("SELECT id_passport FROM customer WHERE id = %s", (customer_id,))
            result = cur.fetchone()

            if not result:
                raise HTTPException(status_code=404, detail="Клиент не найден")

            passport_id = result['id_passport']

            cur.execute("DELETE FROM customer WHERE id = %s RETURNING id", (customer_id,))

            conn.commit()
            return {"message": "Клиент успешно удален"}

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        print(f"Ошибка при удалении клиента {customer_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

#инструменты
@app.get("/api/app/instruments")
async def app_get_instruments(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, i_name, price, i_more, i_status FROM instrument ORDER BY id")
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


@app.post("/api/app/instruments")
async def create_instrument(instrument: InstrumentCreate, token: str = Header(...)):
    check_role(['старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO instrument (i_name, price, i_more) VALUES (%s, %s, %s) RETURNING id",
                (instrument.i_name, instrument.price, instrument.i_more)
            )
            conn.commit()
            return {"id": cur.fetchone()['id'], "message": "Инструмент добавлен"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/instruments/{instrument_id}")
async def update_instrument(instrument_id: int, instrument: InstrumentCreate, token: str = Header(...)):
    check_role(['старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE instrument SET i_name = %s, price = %s, i_more = %s WHERE id = %s RETURNING id",
                (instrument.i_name, instrument.price, instrument.i_more, instrument_id)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Инструмент не найден")
            conn.commit()
            return {"message": "Инструмент обновлен"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.delete("/api/app/instruments/{instrument_id}")
async def delete_instrument(instrument_id: int, token: str = Header(...)):
    check_role(['старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM instrument WHERE id = %s RETURNING id", (instrument_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Инструмент не найден")
            conn.commit()
            return {"message": "Инструмент удален"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/instruments/{instrument_id}/status")
async def update_instrument_status(instrument_id: int, status_data: dict, token: str = Header(...)):
    check_role(['старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            new_status = status_data.get('i_status', 'доступен')
            if new_status not in ['доступен', 'недоступен']:
                raise HTTPException(status_code=400,
                                    detail="Неверный статус. Допустимые значения: доступен, недоступен")

            cur.execute(
                "UPDATE instrument SET i_status = %s WHERE id = %s RETURNING id",
                (new_status, instrument_id)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Инструмент не найден")
            conn.commit()
            return {"message": f"Статус инструмента изменен на {new_status}"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


#заказы
@app.get("/api/app/orders")
async def get_orders(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT o.id, 
                       CONCAT(c.l_name, ' ', c.f_name) as customer_name,
                       i.i_name as instrument_name,
                       o.start_date,
                       o.count_days,
                       o.finish_date,
                       o.full_price,
                       o.discount,
                       o.discounted_price,
                       o.status,
                       i.price as price_per_day,
                       o.full_price as total_price,
                       o.o_more
                FROM orders o
                JOIN customer c ON o.id_customer = c.id
                JOIN instrument i ON o.id_instrument = i.id
                ORDER BY o.id DESC
            """)
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


@app.get("/api/app/orders/{order_id}")
async def get_order(order_id: int, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT o.id, o.count_days, o.o_more, o.status,
                       o.id_customer, o.id_instrument,
                       CONCAT(c.l_name, ' ', c.f_name) as customer_name,
                       i.i_name as instrument_name, i.price as price_per_day
                FROM orders o
                JOIN customer c ON o.id_customer = c.id
                JOIN instrument i ON o.id_instrument = i.id
                WHERE o.id = %s
            """, (order_id,))
            order = cur.fetchone()
            if not order:
                raise HTTPException(status_code=404, detail="Заказ не найден")
            return dict(order)
    finally:
        conn.close()


@app.post("/api/app/orders")
async def create_order(order: OrderCreate, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO orders (id_customer, id_instrument, id_user, count_days, o_more) 
                   VALUES (%s, %s, %s, %s, %s) RETURNING id, full_price, finish_date""",
                (order.id_customer, order.id_instrument, order.id_user, order.count_days, order.o_more)
            )
            result = cur.fetchone()
            conn.commit()
            return {
                "id": result['id'],
                "full_price": result['full_price'],
                "finish_date": result['finish_date'],
                "message": "Заказ создан"
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/orders/{order_id}")
async def update_order(order_id: int, order_data: dict, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE orders 
                SET count_days = %s, o_more = %s 
                WHERE id = %s RETURNING id
            """, (order_data.get('count_days'), order_data.get('o_more', '-'), order_id))

            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Заказ не найден")
            conn.commit()
            return {"message": "Заказ обновлен"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/orders/{order_id}/complete")
async def complete_order(order_id: int, token: str = Header(...)):
    check_role(['старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE orders SET status = 'возвращено' WHERE id = %s RETURNING id",
                (order_id,)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Заказ не найден")
            conn.commit()
            return {"message": "Заказ завершен"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/orders/{order_id}/discount")
async def apply_discount(order_id: int, discount_data: DiscountApply, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            discount = discount_data.discount_percent

            if discount < 0 or discount > 100:
                raise HTTPException(status_code=400, detail="Скидка должна быть от 0 до 100")

            cur.execute(
                """UPDATE orders 
                   SET discount = %s 
                   WHERE id = %s 
                   RETURNING full_price, discounted_price, discount""",
                (discount, order_id)
            )
            result = cur.fetchone()

            if not result:
                raise HTTPException(status_code=404, detail="Заказ не найден")

            conn.commit()

            return {
                "success": True,
                "full_price": float(result['full_price']),
                "discounted_price": float(result['discounted_price']),
                "discount_percent": float(result['discount']),
                "saved": float(result['full_price']) - float(result['discounted_price'])
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/api/app/orders/{order_id}/discount")
async def get_discount(order_id: int, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COALESCE(discount, 0) as discount, full_price, COALESCE(discounted_price, full_price) as discounted_price FROM orders WHERE id = %s",
                (order_id,)
            )
            order = cur.fetchone()
            if not order:
                raise HTTPException(status_code=404, detail="Заказ не найден")

            return {
                "discount_percent": float(order['discount']),
                "full_price": float(order['full_price']),
                "discounted_price": float(order['discounted_price'])
            }
    finally:
        conn.close()


@app.put("/api/app/orders/{order_id}/extend")
async def extend_order(order_id: int, extend: OrderExtend, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT count_days FROM orders WHERE id = %s",
                (order_id,)
            )
            order = cur.fetchone()
            if not order:
                raise HTTPException(status_code=404, detail="Заказ не найден")

            new_days = order['count_days'] + extend.extra_days
            cur.execute(
                "UPDATE orders SET count_days = %s WHERE id = %s RETURNING full_price, finish_date",
                (new_days, order_id)
            )
            result = cur.fetchone()
            conn.commit()
            return {
                "full_price": result['full_price'],
                "finish_date": result['finish_date'],
                "message": f"Добавлено {extend.extra_days} дней"
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/orders/{order_id}/payment")
async def change_payment_status(order_id: int, payment: dict, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            new_status = payment.get('status', 'неоплачено')
            if new_status not in ['неоплачено', 'оплачено']:
                raise HTTPException(status_code=400, detail="Неверный статус")

            cur.execute(
                "UPDATE orders SET status = %s WHERE id = %s RETURNING id",
                (new_status, order_id)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Заказ не найден")
            conn.commit()
            return {"message": f"Статус оплаты изменен на {new_status}"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


#пользователи
@app.get("/api/app/users")
async def get_users(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, u_name, u_role FROM users ORDER BY id")
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


#для статистики
@app.get("/api/app/statistics/top-instruments")
async def get_top_instruments(period: str = "all", limit: int = 10, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            view_map = {
                "all": "top_instruments_all",
                "month": "top_instruments_month",
                "quarter": "top_instruments_quarter",
                "half_year": "top_instruments_half_year",
                "year": "top_instruments_year"
            }
            view_name = view_map.get(period, "top_instruments_all")
            cur.execute(f"SELECT * FROM {view_name} LIMIT %s", (limit,))
            result = cur.fetchall()
            return [dict(r) for r in result]
    except Exception as e:
        print(f"ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/api/app/statistics/top-customers")
async def get_top_customers(period: str = "all", limit: int = 10, token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            view_map = {
                "all": "top_customers_all",
                "month": "top_customers_month",
                "quarter": "top_customers_quarter",
                "half_year": "top_customers_half_year",
                "year": "top_customers_year"
            }
            view_name = view_map.get(period, "top_customers_all")
            cur.execute(f"SELECT * FROM {view_name} LIMIT %s", (limit,))
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


@app.get("/api/app/statistics/revenue")
async def get_revenue_stats(period: str = "all", token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if period == "all":
                cur.execute("SELECT * FROM revenue_all")
            elif period == "month":
                cur.execute("SELECT * FROM revenue_by_month")
            elif period == "half_year":
                cur.execute("SELECT * FROM revenue_half_year")
            elif period == "year":
                cur.execute("SELECT * FROM revenue_year")
            else:
                cur.execute("SELECT * FROM revenue_all")
            return [dict(r) for r in cur.fetchall()]
    except Exception as e:
        print(f"ERROR revenue: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/api/app/statistics/dashboard")
async def get_dashboard_stats(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM dashboard_stats")
            return dict(cur.fetchone())
    finally:
        conn.close()


#админка
@app.get("/api/app/admin/users")
async def admin_get_users(token: str = Header(...)):
    check_role(['администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, u_name, u_role FROM users ORDER BY id")
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


@app.get("/api/app/admin/users/{user_id}")
async def admin_get_user(user_id: int, token: str = Header(...)):
    check_role(['администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, u_name, u_role FROM users WHERE id = %s", (user_id,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Пользователь не найден")
            return dict(user)
    finally:
        conn.close()


@app.post("/api/app/admin/users")
async def admin_create_user(user: UserCreate, token: str = Header(...)):
    check_role(['администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE u_name = %s", (user.u_name,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Пользователь с таким именем уже существует")

            hashed_password = hash_password(user.u_password)

            cur.execute(
                "INSERT INTO users (u_name, u_password, u_role) VALUES (%s, %s, %s) RETURNING id",
                (user.u_name, hashed_password, user.u_role)
            )
            conn.commit()
            return {"id": cur.fetchone()['id'], "message": "Пользователь создан"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.put("/api/app/admin/users/{user_id}")
async def admin_update_user(user_id: int, user: UserUpdate, token: str = Header(...)):
    check_role(['администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE id = %s", (user_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Пользователь не найден")

            cur.execute("SELECT id FROM users WHERE u_name = %s AND id != %s", (user.u_name, user_id))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Пользователь с таким именем уже существует")

            if user.u_password:
                hashed_password = hash_password(user.u_password)
                cur.execute(
                    "UPDATE users SET u_name = %s, u_password = %s, u_role = %s WHERE id = %s",
                    (user.u_name, hashed_password, user.u_role, user_id)
                )
            else:
                cur.execute(
                    "UPDATE users SET u_name = %s, u_role = %s WHERE id = %s",
                    (user.u_name, user.u_role, user_id)
                )
            conn.commit()
            return {"message": "Пользователь обновлен"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.delete("/api/app/admin/users/{user_id}")
async def admin_delete_user(user_id: int, token: str = Header(...)):
    print(f"DEBUG: Попытка удаления пользователя {user_id}")

    check_role(['администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT u_role FROM users WHERE id = %s", (user_id,))
            user = cur.fetchone()
            print(f"DEBUG: Найден пользователь: {user}")

            if not user:
                print("DEBUG: Пользователь не найден")
                raise HTTPException(status_code=404, detail="Пользователь не найден")

            #проверяем что он не последний
            if user['u_role'] == 'администратор':
                cur.execute("SELECT COUNT(*) FROM users WHERE u_role = 'администратор'")
                admin_count = cur.fetchone()
                print(f"DEBUG: Количество администраторов: {admin_count}")
                if admin_count and admin_count['count'] <= 1:
                    print("DEBUG: Нельзя удалить последнего администратора")
                    raise HTTPException(status_code=400, detail="Нельзя удалить последнего администратора")

            cur.execute("DELETE FROM users WHERE id = %s RETURNING id", (user_id,))
            result = cur.fetchone()
            print(f"DEBUG: Результат удаления: {result}")
            conn.commit()
            return {"message": "Пользователь удален"}
    except Exception as e:
        conn.rollback()
        print(f"DEBUG: Ошибка: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


#для резервного копирования
@app.get("/api/app/admin/backup/list")
async def get_backup_list(token: str = Header(...)):
    check_role(['администратор'], token)
    try:
        backups = []
        for file in sorted(glob.glob(os.path.join(BACKUP_DIR, "backup_*.sql")), reverse=True):
            stat = os.stat(file)
            backups.append({
                "name": os.path.basename(file),
                "size": stat.st_size,
                "created": datetime.datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            })
        return backups
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/app/admin/backup/create")
async def create_backup(token: str = Header(...)):
    check_role(['администратор'], token)
    try:
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = os.path.join(BACKUP_DIR, f"backup_{timestamp}.sql")

        dbname = DB_CONFIG['dbname']
        user = DB_CONFIG['user']
        password = DB_CONFIG['password']
        host = DB_CONFIG['host']
        port = DB_CONFIG['port']

        env = os.environ.copy()
        env['PGPASSWORD'] = password

        pg_dump_path = '/Applications/Postgres.app/Contents/Versions/18/bin/pg_dump'

        if not os.path.exists(pg_dump_path):
            alternatives = [
                '/Applications/Postgres.app/Contents/Versions/latest/bin/pg_dump',
                '/usr/local/bin/pg_dump',
                '/opt/homebrew/bin/pg_dump'
            ]
            for alt in alternatives:
                if os.path.exists(alt):
                    pg_dump_path = alt
                    break

        cmd = [
            pg_dump_path,
            '-h', host,
            '-p', str(port),
            '-U', user,
            '-d', dbname,
            '-F', 'p',
            '-f', backup_file
        ]

        result = subprocess.run(cmd, env=env, capture_output=True, text=True)

        if result.returncode == 0:
            return {
                "success": True,
                "file": os.path.basename(backup_file),
                "message": "Бэкап создан успешно"
            }
        else:
            return {
                "success": False,
                "message": f"Ошибка: {result.stderr}"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/app/admin/backup/restore/{backup_name}")
async def restore_backup(backup_name: str, token: str = Header(...)):
    check_role(['администратор'], token)
    try:
        backup_file = os.path.join(BACKUP_DIR, backup_name)

        if not os.path.exists(backup_file):
            raise HTTPException(status_code=404, detail="Бэкап не найден")

        dbname = DB_CONFIG['dbname']
        user = DB_CONFIG['user']
        password = DB_CONFIG['password']
        host = DB_CONFIG['host']
        port = DB_CONFIG['port']

        env = os.environ.copy()
        env['PGPASSWORD'] = password

        cmd = [
            'psql',
            '-h', host,
            '-p', str(port),
            '-U', user,
            '-d', dbname,
            '-f', backup_file
        ]

        result = subprocess.run(cmd, env=env, capture_output=True, text=True)

        if result.returncode == 0:
            return {"success": True, "message": "База данных восстановлена"}
        else:
            return {"success": False, "message": f"Ошибка: {result.stderr}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/app/admin/backup/delete/{backup_name}")
async def delete_backup(backup_name: str, token: str = Header(...)):
    check_role(['администратор'], token)
    try:
        backup_file = os.path.join(BACKUP_DIR, backup_name)

        if not os.path.exists(backup_file):
            raise HTTPException(status_code=404, detail="Бэкап не найден")

        os.remove(backup_file)
        return {"success": True, "message": "Бэкап удален"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


#для экспорта
@app.get("/api/app/export/orders/csv")
async def export_orders_csv(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT o.id, 
                       CONCAT(c.l_name, ' ', c.f_name) as customer_name,
                       i.i_name as instrument_name,
                       o.start_date,
                       o.count_days,
                       o.finish_date,
                       o.discounted_price as final_price,
                       o.status,
                       o.o_more
                FROM orders o
                JOIN customer c ON o.id_customer = c.id
                JOIN instrument i ON o.id_instrument = i.id
                ORDER BY o.id DESC
            """)
            rows = cur.fetchall()

            output = io.StringIO()
            writer = csv.writer(output, delimiter=';')
            writer.writerow(['ID', 'Клиент', 'Инструмент', 'Дата начала', 'Кол-во дней',
                             'Дата возврата', 'Сумма (₽)', 'Статус', 'Примечание'])

            for row in rows:
                writer.writerow([
                    row['id'], row['customer_name'], row['instrument_name'],
                    row['start_date'], row['count_days'], row['finish_date'],
                    float(row['final_price']) if row['final_price'] else 0,
                    row['status'], row['o_more']
                ])

            from fastapi.responses import Response
            return Response(
                content=output.getvalue().encode('utf-8-sig'),
                media_type="text/csv",
                headers={"Content-Disposition": "attachment; filename=orders.csv"}
            )
    finally:
        conn.close()


@app.get("/api/app/export/orders/excel")
async def export_orders_excel(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    try:
        import pandas as pd
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT o.id, 
                           CONCAT(c.l_name, ' ', c.f_name) as customer_name,
                           i.i_name as instrument_name,
                           o.start_date,
                           o.count_days,
                           o.finish_date,
                           o.discounted_price as final_price,
                           o.status,
                           o.o_more
                    FROM orders o
                    JOIN customer c ON o.id_customer = c.id
                    JOIN instrument i ON o.id_instrument = i.id
                    ORDER BY o.id DESC
                """)
                rows = cur.fetchall()

                df = pd.DataFrame(rows)
                df.columns = ['ID', 'Клиент', 'Инструмент', 'Дата начала', 'Кол-во дней',
                              'Дата возврата', 'Сумма (₽)', 'Статус', 'Примечание']

                output = io.BytesIO()
                with pd.ExcelWriter(output, engine='openpyxl') as writer:
                    df.to_excel(writer, sheet_name='Заказы', index=False)

                from fastapi.responses import Response
                return Response(
                    content=output.getvalue(),
                    media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    headers={"Content-Disposition": "attachment; filename=orders.xlsx"}
                )
        finally:
            conn.close()
    except ImportError:
        raise HTTPException(status_code=500, detail="Установите pandas и openpyxl: pip install pandas openpyxl")


@app.get("/api/app/export/customers/csv")
async def export_customers_csv(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT c.id, c.l_name, c.f_name, c.v_name, c.phone, 
                       p.p_number as passport_number, p.p_home as passport_home
                FROM customer c
                JOIN passport p ON c.id_passport = p.id
                ORDER BY c.id
            """)
            rows = cur.fetchall()

            output = io.StringIO()
            writer = csv.writer(output, delimiter=';')
            writer.writerow(['ID', 'Фамилия', 'Имя', 'Отчество', 'Телефон', 'Паспорт', 'Адрес'])

            for row in rows:
                writer.writerow([
                    row['id'], row['l_name'], row['f_name'],
                    row.get('v_name', ''), row['phone'],
                    row['passport_number'], row['passport_home']
                ])

            from fastapi.responses import Response
            return Response(
                content=output.getvalue().encode('utf-8-sig'),
                media_type="text/csv",
                headers={"Content-Disposition": "attachment; filename=customers.csv"}
            )
    finally:
        conn.close()


@app.get("/api/app/export/customers/excel")
async def export_customers_excel(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    try:
        import pandas as pd
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT c.id, c.l_name, c.f_name, c.v_name, c.phone, 
                           p.p_number as passport_number, p.p_home as passport_home
                    FROM customer c
                    JOIN passport p ON c.id_passport = p.id
                    ORDER BY c.id
                """)
                rows = cur.fetchall()

                df = pd.DataFrame(rows)
                df.columns = ['ID', 'Фамилия', 'Имя', 'Отчество', 'Телефон', 'Паспорт', 'Адрес']

                output = io.BytesIO()
                with pd.ExcelWriter(output, engine='openpyxl') as writer:
                    df.to_excel(writer, sheet_name='Клиенты', index=False)

                from fastapi.responses import Response
                return Response(
                    content=output.getvalue(),
                    media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    headers={"Content-Disposition": "attachment; filename=customers.xlsx"}
                )
        finally:
            conn.close()
    except ImportError:
        raise HTTPException(status_code=500, detail="Установите pandas и openpyxl")


@app.get("/api/app/export/instruments/csv")
async def export_instruments_csv(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, i_name, price, i_more, i_status
                FROM instrument
                ORDER BY id
            """)
            rows = cur.fetchall()

            output = io.StringIO()
            writer = csv.writer(output, delimiter=';')
            writer.writerow(['ID', 'Наименование', 'Цена за сутки (₽)', 'Примечание', 'Статус'])

            for row in rows:
                writer.writerow([
                    row['id'], row['i_name'], float(row['price']),
                    row.get('i_more', '-'), row.get('i_status', 'доступен')
                ])

            from fastapi.responses import Response
            return Response(
                content=output.getvalue().encode('utf-8-sig'),
                media_type="text/csv",
                headers={"Content-Disposition": "attachment; filename=instruments.csv"}
            )
    finally:
        conn.close()


@app.get("/api/app/export/instruments/excel")
async def export_instruments_excel(token: str = Header(...)):
    check_role(['сотрудник', 'старший сотрудник', 'администратор'], token)
    try:
        import pandas as pd
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, i_name, price, i_more, i_status
                    FROM instrument
                    ORDER BY id
                """)
                rows = cur.fetchall()

                df = pd.DataFrame(rows)
                df.columns = ['ID', 'Наименование', 'Цена за сутки (₽)', 'Примечание', 'Статус']

                output = io.BytesIO()
                with pd.ExcelWriter(output, engine='openpyxl') as writer:
                    df.to_excel(writer, sheet_name='Инструменты', index=False)

                from fastapi.responses import Response
                return Response(
                    content=output.getvalue(),
                    media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    headers={"Content-Disposition": "attachment; filename=instruments.xlsx"}
                )
        finally:
            conn.close()
    except ImportError:
        raise HTTPException(status_code=500, detail="Установите pandas и openpyxl")