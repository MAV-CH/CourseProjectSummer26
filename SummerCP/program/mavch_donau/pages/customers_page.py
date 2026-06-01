import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from api_client import APIClient
from pages.base_page import BasePage
from dialogs.customer_dialogs import AddCustomerDialog, EditCustomerDialog, CustomerDetailsDialog

class CustomersPage(BasePage):
    def __init__(self, notebook, app):
        super().__init__(notebook, app)
        self.init_page()

    def init_page(self):
        title_frame = ttk.Frame(self.frame)
        title_frame.pack(fill=tk.X, pady=10)
        ttk.Label(title_frame, text="Управление клиентами", style='Title.TLabel').pack()

        btn_frame = ttk.Frame(self.frame)
        btn_frame.pack(pady=10)

        ttk.Button(btn_frame, text="Добавить клиента", command=self.add_customer,
                   style='Success.TButton', width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Редактировать", command=self.edit_customer,
                   width=18).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Удалить", command=self.delete_customer,
                   style='Danger.TButton', width=18).pack(side=tk.LEFT, padx=5)

        columns = ('ID', 'ФИО', 'Телефон', 'Паспорт', 'Адрес')
        col_widths = {'ID': 50, 'ФИО': 200, 'Телефон': 120, 'Паспорт': 150, 'Адрес': 500}

        self.create_table(columns, col_widths)

        self.create_search_frame("🔍 Поиск по ФИО или телефону:")

        self.tree.bind('<Double-Button-1>', self.create_order)

        self.load_customers()

    def load_customers(self, search_text=""):
        for item in self.tree.get_children():
            self.tree.delete(item)

        customers = APIClient.get_customers()

        if search_text:
            search_lower = search_text.lower()
            customers = [c for c in customers if search_lower in f"{c['l_name']} {c['f_name']}".lower() or
                         search_lower in c['phone']]

        for customer in customers:
            self.tree.insert('', tk.END, values=(
                customer['id'],
                f"{customer['l_name']} {customer['f_name']} {customer.get('v_name', '')}",
                customer['phone'],
                customer['passport_number'],
                customer['passport_home'][:60] + "..." if len(customer['passport_home']) > 60 else customer[
                    'passport_home']
            ))

    def on_search(self, event):
        self.load_customers(self.search_entry.get())

    def add_customer(self):
        dialog = AddCustomerDialog(self.app.root, self.load_customers)

    def edit_customer(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите клиента")
            return
        customer_id = self.tree.item(selected[0])['values'][0]

        print(f"DEBUG: Редактирование клиента с ID: {customer_id}")

        customer = APIClient.get_customer(customer_id)
        if not customer:
            messagebox.showerror("Ошибка", f"Клиент с ID {customer_id} не найден")
            return

        print(f"DEBUG: Получен клиент: {customer}")

        dialog = EditCustomerDialog(self.app.root, customer_id, self.load_customers)

    def delete_customer(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите клиента")
            return
        customer_id = self.tree.item(selected[0])['values'][0]
        customer_name = self.tree.item(selected[0])['values'][1]

        if messagebox.askyesno("Подтверждение", f"Удалить клиента '{customer_name}'?"):
            if APIClient.delete_customer(customer_id):
                messagebox.showinfo("Успех", "Клиент удален")
                self.load_customers()
            else:
                messagebox.showerror("Ошибка", "Не удалось удалить клиента")

    def create_order(self, event):
        selected = self.tree.selection()
        if not selected:
            return
        customer_id = self.tree.item(selected[0])['values'][0]
        customer_name = self.tree.item(selected[0])['values'][1]

        self.app.notebook.select(0)
        from dialogs.order_dialogs import AddOrderDialog
        AddOrderDialog(self.app.root, self.app.orders_page.load_orders, customer_id, customer_name)

    def export_csv(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv")],
            initialfile="customers.csv"
        )
        if file_path:
            data = APIClient.export_customers_to_csv()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")

    def export_excel(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".xlsx",
            filetypes=[("Excel files", "*.xlsx")],
            initialfile="customers.xlsx"
        )
        if file_path:
            data = APIClient.export_customers_to_excel()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")