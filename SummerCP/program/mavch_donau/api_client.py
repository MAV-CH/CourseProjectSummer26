import requests

API_URL = "http://localhost:8000/api/app"
AUTH_URL = "http://localhost:8000/api"


class APIClient:
    _token = None

    @classmethod
    def set_token(cls, token):
        cls._token = token

    @classmethod
    def _get_headers(cls):
        headers = {}
        if cls._token:
            headers["token"] = cls._token
        return headers

    @staticmethod
    def login(username, password):
        try:
            response = requests.post(f"{AUTH_URL}/auth/login", json={"username": username, "password": password})
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Ошибка авторизации: {e}")
            return None

    @staticmethod
    def logout(token):
        try:
            response = requests.post(f"{AUTH_URL}/auth/logout", params={"token": token})
            return response.status_code == 200
        except Exception:
            return False

    @classmethod
    def get_orders(cls):
        response = requests.get(f"{API_URL}/orders", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        print(f"Ошибка get_orders: {response.status_code}")
        return []

    @classmethod
    def get_order(cls, order_id):
        response = requests.get(f"{API_URL}/orders/{order_id}", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return None

    @classmethod
    def create_order(cls, data):
        response = requests.post(f"{API_URL}/orders", json=data, headers=cls._get_headers())
        return response.status_code == 200, response.json() if response.status_code == 200 else None

    @classmethod
    def update_order(cls, order_id, data):
        response = requests.put(f"{API_URL}/orders/{order_id}", json=data, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def complete_order(cls, order_id):
        response = requests.put(f"{API_URL}/orders/{order_id}/complete", headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def change_payment_status(cls, order_id, status):
        response = requests.put(f"{API_URL}/orders/{order_id}/payment", json={"status": status}, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def extend_order(cls, order_id, extra_days):
        response = requests.put(f"{API_URL}/orders/{order_id}/extend",
                                json={"order_id": order_id, "extra_days": extra_days},
                                headers=cls._get_headers())
        return response.status_code == 200, response.json() if response.status_code == 200 else None

    @classmethod
    def get_customers(cls):
        response = requests.get(f"{API_URL}/customers", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        print(f"Ошибка get_customers: {response.status_code}")
        return []

    @classmethod
    def get_customer(cls, customer_id):
        response = requests.get(f"{API_URL}/customers/{customer_id}", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return None

    @classmethod
    def create_customer(cls, data):
        response = requests.post(f"{API_URL}/customers", json=data, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def update_customer(cls, customer_id, data):
        response = requests.put(f"{API_URL}/customers/{customer_id}", json=data, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def delete_customer(cls, customer_id):
        response = requests.delete(f"{API_URL}/customers/{customer_id}", headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def get_instruments(cls):
        response = requests.get(f"{API_URL}/instruments", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        print(f"Ошибка get_instruments: {response.status_code}")
        return []

    @classmethod
    def create_instrument(cls, data):
        response = requests.post(f"{API_URL}/instruments", json=data, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def update_instrument(cls, instrument_id, data):
        response = requests.put(f"{API_URL}/instruments/{instrument_id}", json=data, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def delete_instrument(cls, instrument_id):
        response = requests.delete(f"{API_URL}/instruments/{instrument_id}", headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def update_instrument_status(cls, instrument_id, status):
        response = requests.put(f"{API_URL}/instruments/{instrument_id}/status", json={"i_status": status}, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def get_users(cls):
        response = requests.get(f"{API_URL}/users", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return []

    @classmethod
    def get_top_instruments(cls, period="all", limit=10):
        response = requests.get(f"{API_URL}/statistics/top-instruments", params={"period": period, "limit": limit}, headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return []

    @classmethod
    def get_top_customers(cls, period="all", limit=10):
        response = requests.get(f"{API_URL}/statistics/top-customers", params={"period": period, "limit": limit}, headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return []

    @classmethod
    def get_revenue_stats(cls, period="all"):
        response = requests.get(f"{API_URL}/statistics/revenue", params={"period": period}, headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return []

    @classmethod
    def get_dashboard_stats(cls):
        response = requests.get(f"{API_URL}/statistics/dashboard", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return {}

    @classmethod
    def get_admin_users(cls):
        response = requests.get(f"{API_URL}/admin/users", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return []

    @classmethod
    def get_admin_user(cls, user_id):
        response = requests.get(f"{API_URL}/admin/users/{user_id}", headers=cls._get_headers())
        if response.status_code == 200:
            return response.json()
        return None

    @classmethod
    def create_admin_user(cls, data):
        response = requests.post(f"{API_URL}/admin/users", json=data, headers=cls._get_headers())
        return response.status_code == 200, response.json() if response.status_code == 200 else None

    @classmethod
    def update_admin_user(cls, user_id, data):
        response = requests.put(f"{API_URL}/admin/users/{user_id}", json=data, headers=cls._get_headers())
        return response.status_code == 200

    @classmethod
    def delete_admin_user(cls, user_id):
        response = requests.delete(f"{API_URL}/admin/users/{user_id}", headers=cls._get_headers())
        print(f"DEBUG delete_admin_user: token={cls._token}")  # отладка
        print(f"DEBUG delete_admin_user: status={response.status_code}")
        return response.status_code == 200

    @classmethod
    def get_backup_list(cls):
        response = requests.get(f"{API_URL}/admin/backup/list", headers=cls._get_headers())
        return response.json() if response.status_code == 200 else []

    @classmethod
    def create_backup(cls):
        response = requests.post(f"{API_URL}/admin/backup/create", headers=cls._get_headers())
        return response.json() if response.status_code == 200 else {"success": False, "message": "Ошибка"}

    @classmethod
    def restore_backup(cls, backup_name):
        response = requests.post(f"{API_URL}/admin/backup/restore/{backup_name}", headers=cls._get_headers())
        return response.json() if response.status_code == 200 else {"success": False, "message": "Ошибка"}

    @classmethod
    def delete_backup(cls, backup_name):
        response = requests.delete(f"{API_URL}/admin/backup/delete/{backup_name}", headers=cls._get_headers())
        return response.json() if response.status_code == 200 else {"success": False, "message": "Ошибка"}

    @classmethod
    def apply_discount(cls, order_id, discount_percent):
        try:
            response = requests.put(f"{API_URL}/orders/{order_id}/discount",
                                    json={"discount_percent": discount_percent},
                                    headers=cls._get_headers())
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Ошибка применения скидки: {e}")
            return None

    @classmethod
    def get_order_discount(cls, order_id):
        try:
            response = requests.get(f"{API_URL}/orders/{order_id}/discount", headers=cls._get_headers())
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Ошибка получения скидки: {e}")
            return None

    @classmethod
    def export_orders_to_csv(cls):
        response = requests.get(f"{API_URL}/export/orders/csv", headers=cls._get_headers())
        return response.content if response.status_code == 200 else None

    @classmethod
    def export_orders_to_excel(cls):
        response = requests.get(f"{API_URL}/export/orders/excel", headers=cls._get_headers())
        return response.content if response.status_code == 200 else None

    @classmethod
    def export_customers_to_csv(cls):
        response = requests.get(f"{API_URL}/export/customers/csv", headers=cls._get_headers())
        return response.content if response.status_code == 200 else None

    @classmethod
    def export_customers_to_excel(cls):
        response = requests.get(f"{API_URL}/export/customers/excel", headers=cls._get_headers())
        return response.content if response.status_code == 200 else None

    @classmethod
    def export_instruments_to_csv(cls):
        response = requests.get(f"{API_URL}/export/instruments/csv", headers=cls._get_headers())
        return response.content if response.status_code == 200 else None

    @classmethod
    def export_instruments_to_excel(cls):
        response = requests.get(f"{API_URL}/export/instruments/excel", headers=cls._get_headers())
        return response.content if response.status_code == 200 else None
