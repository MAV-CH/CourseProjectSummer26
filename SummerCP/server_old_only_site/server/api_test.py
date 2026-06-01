import requests
import json

# Проверяем API
try:

    # Проверка инструментов
    response = requests.get("http://localhost:8000/api/instruments")
    print(f"Инструменты: {response.status_code}")
    if response.status_code == 200:
        instruments = response.json()
        print(f"Количество: {len(instruments)}")
        if instruments:
            print(f"Первый инструмент: {instruments[0]}")
    else:
        print(f"Ошибка: {response.text}")

except Exception as e:
    print(f"Ошибка подключения: {e}")