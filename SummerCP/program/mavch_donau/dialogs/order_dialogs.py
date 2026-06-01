import tkinter as tk
from tkinter import ttk, messagebox
from api_client import APIClient

class AddOrderDialog:
    def __init__(self, parent, refresh_callback, pre_customer_id=None, pre_customer_name=None):
        self.parent = parent
        self.refresh_callback = refresh_callback

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Новый заказ")
        self.dialog.geometry("860x450")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()
        self.load_data()

        if pre_customer_id and pre_customer_name:
            self.select_customer(pre_customer_id, pre_customer_name)

    def create_widgets(self):
        ttk.Label(self.dialog, text="Новый заказ", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        ttk.Label(frame, text="Клиент:", font=('Arial', 14, 'bold')).grid(row=0, column=0, sticky=tk.W, pady=10)
        customer_frame = ttk.Frame(frame)
        customer_frame.grid(row=0, column=1, pady=10, sticky=tk.W)

        self.customer_search = ttk.Entry(customer_frame, width=35)
        self.customer_search.pack(side=tk.LEFT, padx=(0, 5))
        self.customer_search.bind('<KeyRelease>', self.search_customers)

        self.customer_combo = ttk.Combobox(customer_frame, width=35, state='readonly')
        self.customer_combo.pack(side=tk.LEFT)

        ttk.Label(frame, text="Инструмент:", font=('Arial', 14, 'bold')).grid(row=1, column=0, sticky=tk.W, pady=10)
        instrument_frame = ttk.Frame(frame)
        instrument_frame.grid(row=1, column=1, pady=10, sticky=tk.W)

        self.instrument_search = ttk.Entry(instrument_frame, width=35)
        self.instrument_search.pack(side=tk.LEFT, padx=(0, 5))
        self.instrument_search.bind('<KeyRelease>', self.search_instruments)

        self.instrument_combo = ttk.Combobox(instrument_frame, width=35, state='readonly')
        self.instrument_combo.pack(side=tk.LEFT)

        ttk.Label(frame, text="Сотрудник:", font=('Arial', 14, 'bold')).grid(row=2, column=0, sticky=tk.W, pady=10)
        self.user_combo = ttk.Combobox(frame, width=40, state='readonly')
        self.user_combo.grid(row=2, column=1, pady=10)

        ttk.Label(frame, text="Количество суток:", font=('Arial', 14, 'bold')).grid(row=3, column=0, sticky=tk.W,
                                                                                    pady=10)
        self.days_entry = ttk.Entry(frame, width=42)
        self.days_entry.grid(row=3, column=1, pady=10)
        self.days_entry.insert(0, "1")

        ttk.Label(frame, text="Примечание:", font=('Arial', 14, 'bold')).grid(row=4, column=0, sticky=tk.W, pady=10)
        self.note_entry = ttk.Entry(frame, width=42)
        self.note_entry.grid(row=4, column=1, pady=10)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Сохранить", command=self.save, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def load_data(self):
        customers = APIClient.get_customers()
        self.all_customers = customers
        self.update_customer_list()

        instruments = APIClient.get_instruments()
        self.all_instruments = instruments
        self.update_instrument_list()

        users = APIClient.get_users()
        self.user_combo['values'] = [f"{u['id']} - {u['u_name']} ({u['u_role']})" for u in users]
        if users:
            self.user_combo.current(0)

    def update_customer_list(self, search_text=""):
        customers = self.all_customers
        if search_text:
            search_lower = search_text.lower()
            customers = [c for c in customers if search_lower in f"{c['l_name']} {c['f_name']}".lower()]

        customer_list = [f"{c['id']} - {c['l_name']} {c['f_name']} {c.get('v_name', '')} (тел: {c['phone']})" for c in
                         customers]
        self.customer_combo['values'] = customer_list
        if customer_list:
            self.customer_combo.current(0)

    def update_instrument_list(self, search_text=""):
        instruments = self.all_instruments
        if search_text:
            search_lower = search_text.lower()
            instruments = [i for i in instruments if search_lower in i['i_name'].lower()]

        instrument_list = [f"{i['id']} - {i['i_name']} ({i['price']:.2f} ₽/сутки)" for i in instruments]
        self.instrument_combo['values'] = instrument_list
        if instrument_list:
            self.instrument_combo.current(0)

    def search_customers(self, event):
        self.update_customer_list(self.customer_search.get())

    def search_instruments(self, event):
        self.update_instrument_list(self.instrument_search.get())

    def select_customer(self, customer_id, customer_name):
        for i, value in enumerate(self.customer_combo['values']):
            if str(customer_id) in value:
                self.customer_combo.current(i)
                break

    def save(self):
        try:
            if not self.customer_combo.get():
                messagebox.showwarning("Внимание", "Выберите клиента")
                return
            if not self.instrument_combo.get():
                messagebox.showwarning("Внимание", "Выберите инструмент")
                return
            if not self.user_combo.get():
                messagebox.showwarning("Внимание", "Выберите сотрудника")
                return

            customer_id = int(self.customer_combo.get().split(' - ')[0])
            instrument_id = int(self.instrument_combo.get().split(' - ')[0])
            user_id = int(self.user_combo.get().split(' - ')[0])
            days = int(self.days_entry.get())

            data = {
                "id_customer": customer_id,
                "id_instrument": instrument_id,
                "id_user": user_id,
                "count_days": days,
                "o_more": self.note_entry.get() if self.note_entry.get() else "-"
            }

            success, _ = APIClient.create_order(data)
            if success:
                messagebox.showinfo("Успех", "Заказ создан")
                self.dialog.destroy()
                self.refresh_callback()
            else:
                messagebox.showerror("Ошибка", "Не удалось создать заказ")
        except ValueError:
            messagebox.showerror("Ошибка", "Проверьте правильность ввода данных")


class EditOrderDialog:
    def __init__(self, parent, order_id, refresh_callback):
        self.parent = parent
        self.order_id = order_id
        self.refresh_callback = refresh_callback

        self.order = APIClient.get_order(order_id)
        if not self.order:
            messagebox.showerror("Ошибка", "Заказ не найден")
            return

        self.dialog = tk.Toplevel(parent)
        self.dialog.title(f"Редактирование заказа #{order_id}")
        self.dialog.geometry("500x400")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text=f"Редактирование заказа #{self.order_id}", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        ttk.Label(frame, text="Количество суток:", font=('Arial', 14, 'bold')).grid(row=0, column=0, sticky=tk.W, pady=10)
        self.days_entry = ttk.Entry(frame, width=30)
        self.days_entry.grid(row=0, column=1, pady=10, padx=10)
        self.days_entry.insert(0, str(self.order['count_days']))

        ttk.Label(frame, text="Примечание:", font=('Arial', 14, 'bold')).grid(row=1, column=0, sticky=tk.W, pady=10)
        self.note_entry = ttk.Entry(frame, width=30)
        self.note_entry.grid(row=1, column=1, pady=10, padx=10)
        self.note_entry.insert(0, self.order.get('o_more', '-'))

        ttk.Label(frame, text=f"Клиент: {self.order['customer_name']}", font=('Arial', 14)).grid(row=2, column=0, columnspan=2, pady=5)
        ttk.Label(frame, text=f"Инструмент: {self.order['instrument_name']}", font=('Arial', 14)).grid(row=3, column=0,columnspan=2, pady=5)
        ttk.Label(frame, text=f"Цена за сутки: {self.order['price_per_day']:.2f} ₽", font=('Arial', 14)).grid(row=4,column=0,columnspan=2, pady=5)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Сохранить", command=self.save, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def save(self):
        try:
            new_days = int(self.days_entry.get())
            if new_days <= 0:
                messagebox.showwarning("Внимание", "Количество дней должно быть больше 0")
                return

            data = {"count_days": new_days, "o_more": self.note_entry.get() if self.note_entry.get() else "-"}

            if APIClient.update_order(self.order_id, data):
                messagebox.showinfo("Успех", "Заказ обновлен")
                self.dialog.destroy()
                self.refresh_callback()
            else:
                messagebox.showerror("Ошибка", "Не удалось обновить заказ")
        except ValueError:
            messagebox.showerror("Ошибка", "Введите корректное число")


class ExtendOrderDialog:
    def __init__(self, parent, order_id, refresh_callback):
        self.parent = parent
        self.order_id = order_id
        self.refresh_callback = refresh_callback

        self.order = APIClient.get_order(order_id)
        if not self.order:
            messagebox.showerror("Ошибка", "Заказ не найден")
            return

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Добавление суток")
        self.dialog.geometry("400x300")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Добавление суток за просрочку", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(pady=20)

        ttk.Label(frame, text="Количество дополнительных суток:", font=('Arial', 14)).pack()
        self.days_entry = ttk.Entry(frame, width=20, font=('Arial', 14))
        self.days_entry.pack(pady=10)
        self.days_entry.insert(0, "1")

        ttk.Button(self.dialog, text="Добавить", command=self.extend, style='Success.TButton').pack(pady=10)

    def extend(self):
        try:
            extra_days = int(self.days_entry.get())
            if extra_days <= 0:
                messagebox.showwarning("Внимание", "Количество дней должно быть больше 0")
                return

            success, result = APIClient.extend_order(self.order_id, extra_days)
            if success:
                messagebox.showinfo("Успех",
                                    f"Добавлено {extra_days} суток\nНовая сумма: {result['full_price']:.2f} ₽\nНовая дата возврата: {result['finish_date'][:10]}")
                self.dialog.destroy()
                self.refresh_callback()
            else:
                messagebox.showerror("Ошибка", "Не удалось добавить сутки")
        except ValueError:
            messagebox.showerror("Ошибка", "Введите корректное число")