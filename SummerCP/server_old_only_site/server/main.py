# SummerCP/server/server/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv
import pathlib

load_dotenv()

app = FastAPI(title="Прайс-лист инструментов")

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

def get_db_connection():
    try:
        conn = psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)
        return conn
    except Exception as e:
        print(f"Ошибка подключения к БД: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка подключения к базе данных: {str(e)}")

class Instrument(BaseModel):
    id: int
    i_name: str
    price: float
    i_more: str

@app.get("/")
async def root():
    html_path = pathlib.Path(__file__).parent.parent.parent / "site" / "site" / "main_site.html"

    if not html_path.exists():
        return HTMLResponse(content=f"<h1>Файл не найден: {html_path}</h1>", status_code=404)

    with open(html_path, "r", encoding="utf-8") as f:
        html_content = f.read()
    return HTMLResponse(content=html_content)


@app.get("/api/instruments", response_model=List[Instrument])
async def get_instruments(search: Optional[str] = None):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if search and search.strip():
                cur.execute(
                    """SELECT id, i_name, price, i_more 
                       FROM instrument 
                       WHERE i_name ILIKE %s 
                       ORDER BY id""",
                    (f'%{search.strip()}%',)
                )
            else:
                cur.execute(
                    """SELECT id, i_name, price, i_more 
                       FROM instrument 
                       ORDER BY id"""
                )
            instruments = cur.fetchall()
            return [dict(instr) for instr in instruments]
    except Exception as e:
        print(f"Ошибка в get_instruments: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/api/instruments/{instrument_id}")
async def get_instrument(instrument_id: int):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, i_name, price, i_more FROM instrument WHERE id = %s",
                (instrument_id,)
            )
            instrument = cur.fetchone()
            if not instrument:
                raise HTTPException(status_code=404, detail="Инструмент не найден")
            return dict(instrument)
    except Exception as e:
        print(f"Ошибка: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
