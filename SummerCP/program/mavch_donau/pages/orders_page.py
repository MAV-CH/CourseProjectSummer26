# SummerCP/pages/orders_page.py
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from api_client import APIClient
from pages.base_page import BasePage
from dialogs.order_dialogs import AddOrderDialog, EditOrderDialog, ExtendOrderDialog
from dialogs.discount_dialog import DiscountDialog


class OrdersPage(BasePage):
    def __init__(self, notebook, app):
        super().__init__(notebook, app)
        self.init_page()

    def init_page(self):
        title_frame = ttk.Frame(self.frame)
        title_frame.pack(fill=tk.X, pady=10)
        ttk.Label(title_frame, text="Управление заказами", style='Title.TLabel').pack()

        btn_frame = ttk.Frame(self.frame)
        btn_frame.pack(pady=10)

        ttk.Button(btn_frame, text="Добавить заказ", command=self.add_order,
                   style='Success.TButton', width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Редактировать", command=self.edit_order,
                   width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Завершить заказ", command=self.complete_order,
                   width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Сменить оплату", command=self.change_payment,
                   width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Добавить сутки", command=self.extend_order,
                   width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Скидка", command=self.apply_discount,
                   width=15).pack(side=tk.LEFT, padx=5)

        columns = ('ID', 'Дата', 'Время', 'Наименование', 'Дата возврата',
                   'Суток', 'Цена за сутки', 'Цена за все время',
                   'ФИО клиента', 'Скидка', 'Статус оплаты', 'Примечание')
        col_widths = {'ID': 40, 'Дата': 100, 'Время': 40, 'Наименование': 200,
                      'Дата возврата': 100, 'Суток': 40, 'Цена за сутки': 90,
                      'Цена за все время': 110, 'ФИО клиента': 180,
                      'Скидка': 60, 'Статус оплаты': 120, 'Примечание': 180}

        self.create_table(columns, col_widths)

        self.tree.tag_configure('not_paid', background='#ffcccc')
        self.tree.tag_configure('paid', background='#ffe0b3')
        self.tree.tag_configure('returned', background='#ffffff')

        self.create_search_frame("🔍 Поиск по клиенту или инструменту:")

        self.tree.bind('<Double-Button-1>', self.view_customer)

        self.load_orders()

    def load_orders(self, search_text=""):
        for item in self.tree.get_children():
            self.tree.delete(item)

        orders = APIClient.get_orders()

        if search_text:
            search_lower = search_text.lower()
            orders = [o for o in orders if search_lower in o['customer_name'].lower() or
                      search_lower in o['instrument_name'].lower()]

        for order in reversed(orders):
            start_date = order['start_date'][:10] if order['start_date'] else '-'
            start_time = order['start_date'][11:16] if order['start_date'] else '-'
            finish_date = order['finish_date'][:10] if order['finish_date'] else '-'

            if order['status'] == 'возвращено':
                payment_status = "Возвращено"
                tag = 'returned'
            elif order['status'] == 'оплачено':
                payment_status = "Оплачено"
                tag = 'paid'
            else:
                payment_status = "Не оплачено"
                tag = 'not_paid'

            full_price = order.get('full_price', 0) or 0
            discounted_price = order.get('discounted_price', full_price) or full_price
            discount = order.get('discount', 0) or 0

            if discount > 0:
                final_price = discounted_price
                discount_display = f"-{discount:.0f}%"
            else:
                final_price = full_price
                discount_display = "-"

            order_note = order.get('o_more', '-')
            if order_note == '-' or not order_note.strip():
                order_note = '-'

            self.tree.insert('', tk.END, values=(
                order['id'],
                start_date,
                start_time,
                order['instrument_name'],
                finish_date,
                order['count_days'],
                f"{order['price_per_day']:.2f} ₽",
                f"{final_price:.2f} ₽",
                order['customer_name'],
                discount_display,
                payment_status,
                order_note
            ), tags=(tag,))

        self.tree.yview_moveto(1.0)

    def on_search(self, event):
        self.load_orders(self.search_entry.get())

    def add_order(self):
        dialog = AddOrderDialog(self.app.root, self.load_orders)

    def edit_order(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите заказ для редактирования")
            return
        order_id = self.tree.item(selected[0])['values'][0]
        dialog = EditOrderDialog(self.app.root, order_id, self.load_orders)

    def complete_order(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите заказ")
            return
        order_id = self.tree.item(selected[0])['values'][0]
        if messagebox.askyesno("Подтверждение", f"Завершить заказ #{order_id}?"):
            if APIClient.complete_order(order_id):
                messagebox.showinfo("Успех", "Заказ завершен")
                self.load_orders()
            else:
                messagebox.showerror("Ошибка", "Не удалось завершить заказ")

    def apply_discount(self):
        selected = self.tree.selection()
        if not selected:
            return

        order_id = self.tree.item(selected[0])['values'][0]

        order = APIClient.get_order(order_id)
        if not order:
            return

        if order.get('status') != 'неоплачено':
            return

        full_price = 0
        all_orders = APIClient.get_orders()
        for o in all_orders:
            if o['id'] == order_id:
                full_price = o.get('full_price', 0)
                break

        order_info = {
            'customer_name': order.get('customer_name', '-'),
            'instrument_name': order.get('instrument_name', '-'),
            'full_price': full_price
        }
        DiscountDialog(self.app.root, order_id, order_info, self.load_orders)

    def change_payment(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите заказ")
            return
        order_id = self.tree.item(selected[0])['values'][0]

        order = APIClient.get_order(order_id)
        if order and order['status'] != 'возвращено':
            new_status = "оплачено" if order['status'] == "неоплачено" else "неоплачено"
            new_status_text = "Оплачен" if new_status == "оплачено" else "Не оплачен"
            if messagebox.askyesno("Подтверждение", f"Сменить статус оплаты на '{new_status_text}'?"):
                if APIClient.change_payment_status(order_id, new_status):
                    messagebox.showinfo("Успех", "Статус оплаты изменен")
                    self.load_orders()
                else:
                    messagebox.showerror("Ошибка", "Не удалось изменить статус оплаты")

    def extend_order(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите заказ")
            return
        order_id = self.tree.item(selected[0])['values'][0]
        dialog = ExtendOrderDialog(self.app.root, order_id, self.load_orders)

    def view_customer(self, event):
        selected = self.tree.selection()
        if not selected:
            return
        customer_name = self.tree.item(selected[0])['values'][8]

        customers = APIClient.get_customers()
        for customer in customers:
            full_name = f"{customer['l_name']} {customer['f_name']}"
            if full_name == customer_name or full_name in customer_name:
                from dialogs.customer_dialogs import CustomerDetailsDialog
                CustomerDetailsDialog(self.app.root, customer, self.app)
                break

    def export_csv(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv")],
            initialfile="orders.csv"
        )
        if file_path:
            data = APIClient.export_orders_to_csv()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")

    def export_excel(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".xlsx",
            filetypes=[("Excel files", "*.xlsx")],
            initialfile="orders.xlsx"
        )
        if file_path:
            data = APIClient.export_orders_to_excel()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")