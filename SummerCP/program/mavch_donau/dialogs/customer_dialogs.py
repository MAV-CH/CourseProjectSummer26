# SummerCP/dialogs/customer_dialogs.py
import tkinter as tk
from tkinter import ttk, messagebox
from api_client import APIClient
from dialogs.order_dialogs import AddOrderDialog
from utils.helpers import center_window


class AddCustomerDialog:
    def __init__(self, parent, refresh_callback):
        self.parent = parent
        self.refresh_callback = refresh_callback

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Новый клиент")
        self.dialog.geometry("700x400")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Новый клиент", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        labels = ['Фамилия:*', 'Имя:*', 'Отчество:', 'Телефон:*',
                  'Серия и номер паспорта:*', 'Адрес прописки:*']
        self.entries = []

        for i, label in enumerate(labels):
            ttk.Label(frame, text=label, font=('Arial', 14)).grid(row=i, column=0, sticky=tk.W, pady=8)
            entry = ttk.Entry(frame, width=40)
            entry.grid(row=i, column=1, pady=8, padx=10)
            self.entries.append(entry)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Сохранить", command=self.save, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def save(self):
        data = {
            "l_name": self.entries[0].get(),
            "f_name": self.entries[1].get(),
            "v_name": self.entries[2].get(),
            "phone": self.entries[3].get(),
            "passport_number": self.entries[4].get(),
            "passport_home": self.entries[5].get()
        }

        if not all([data['l_name'], data['f_name'], data['phone'], data['passport_number'], data['passport_home']]):
            messagebox.showwarning("Внимание", "Заполните все поля, помеченные звездочкой (*)")
            return

        if APIClient.create_customer(data):
            messagebox.showinfo("Успех", "Клиент добавлен")
            self.dialog.destroy()
            self.refresh_callback()
        else:
            messagebox.showerror("Ошибка", "Не удалось добавить клиента")
class EditCustomerDialog:
    def __init__(self, parent, customer_id, refresh_callback):
        self.parent = parent
        self.customer_id = customer_id
        self.refresh_callback = refresh_callback

        self.customer = APIClient.get_customer(customer_id)
        if not self.customer:
            messagebox.showerror("Ошибка", f"Клиент с ID {customer_id} не найден в базе данных")
            return

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Редактирование клиента")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        center_window(self.dialog, 550, 650)
        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Редактирование клиента", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        labels = ['Фамилия:*', 'Имя:*', 'Отчество:', 'Телефон:*',
                  'Серия и номер паспорта:*', 'Адрес прописки:*']
        self.entries = []

        default_values = [
            self.customer.get('l_name', ''),
            self.customer.get('f_name', ''),
            self.customer.get('v_name', ''),
            self.customer.get('phone', ''),
            self.customer.get('passport_number', ''),
            self.customer.get('passport_home', '')
        ]

        for i, label in enumerate(labels):
            ttk.Label(frame, text=label, font=('Arial', 14)).grid(row=i, column=0, sticky=tk.W, pady=8)
            entry = ttk.Entry(frame, width=40)
            entry.grid(row=i, column=1, pady=8, padx=10)
            entry.insert(0, default_values[i] if default_values[i] else '')
            self.entries.append(entry)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Обновить", command=self.update, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def update(self):
        data = {
            "l_name": self.entries[0].get().strip(),
            "f_name": self.entries[1].get().strip(),
            "v_name": self.entries[2].get().strip(),
            "phone": self.entries[3].get().strip(),
            "passport_number": self.entries[4].get().strip(),
            "passport_home": self.entries[5].get().strip()
        }

        if not all([data['l_name'], data['f_name'], data['phone'], data['passport_number'], data['passport_home']]):
            messagebox.showwarning("Внимание", "Заполните все поля, помеченные звёздочкой (*)")
            return

        if APIClient.update_customer(self.customer_id, data):
            messagebox.showinfo("Успех", "Клиент обновлён")
            self.dialog.destroy()
            self.refresh_callback()
        else:
            messagebox.showerror("Ошибка", "Не удалось обновить клиента. Проверьте корректность введённых данных.")

class CustomerDetailsDialog:
    def __init__(self, parent, customer, app):
        self.parent = parent
        self.customer = customer
        self.app = app

        self.dialog = tk.Toplevel(parent)
        self.dialog.title(f"Карточка клиента: {customer['l_name']} {customer['f_name']}")
        self.dialog.geometry("600x500")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Информация о клиенте", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10, fill=tk.BOTH, expand=True)

        info = [
            ("Фамилия:", self.customer['l_name']),
            ("Имя:", self.customer['f_name']),
            ("Отчество:", self.customer.get('v_name', '-')),
            ("Телефон:", self.customer['phone']),
            ("Паспорт:", self.customer['passport_number']),
            ("Адрес регистрации:", self.customer['passport_home'])
        ]

        for i, (label, value) in enumerate(info):
            ttk.Label(frame, text=label, font=('Arial', 14, 'bold')).grid(row=i, column=0, sticky=tk.W, pady=10)
            ttk.Label(frame, text=value, font=('Arial', 14)).grid(row=i, column=1, sticky=tk.W, pady=10, padx=10)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)

        def create_order():
            self.dialog.destroy()
            AddOrderDialog(self.parent, self.app.orders_page.load_orders,
                           self.customer['id'], f"{self.customer['l_name']} {self.customer['f_name']}")

        def view_orders():
            self.dialog.destroy()
            self.app.notebook.select(0)
            self.app.orders_page.search_entry.delete(0, tk.END)
            self.app.orders_page.search_entry.insert(0, f"{self.customer['l_name']} {self.customer['f_name']}")
            self.app.orders_page.on_search(None)

        ttk.Button(btn_frame, text="Создать заказ", command=create_order, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="История заказов", command=view_orders).pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Закрыть", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)