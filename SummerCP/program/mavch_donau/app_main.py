import tkinter as tk
from tkinter import ttk, messagebox
from pages.orders_page import OrdersPage
from pages.customers_page import CustomersPage
from pages.instruments_page import InstrumentsPage
from pages.statistics_page import StatisticsPage
from pages.admin_page import AdminPage
from utils.styles import setup_styles
from dialogs.auth_dialog import AuthDialog
from api_client import APIClient


class ToolRentalApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Система проката инструментов")
        self.root.geometry("1400x800")
        self.root.configure(bg='#e0e0e0')

        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        x = (screen_width - 1400) // 2
        y = (screen_height - 800) // 2
        self.root.geometry(f"1400x800+{x}+{y}")

        setup_styles()

        self.token = None
        self.current_user = None

        self.show_auth()

    def show_auth(self):
        self.auth_dialog = AuthDialog(self.root, self.on_login_success)

    def on_login_success(self, user_data):
        self.token = user_data.get('token')
        self.current_user = user_data
        APIClient.set_token(self.token)
        print(f"DEBUG: Токен установлен: {self.token}")  # отладка

        self.root.title(
            f"Система проката инструментов - {self.current_user.get('username')} ({self.current_user.get('role')})")

        self.create_notebook()
        self.create_menu()

    def create_notebook(self):
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        user_role = self.current_user.get('role', 'сотрудник')

        self.orders_page = OrdersPage(self.notebook, self)
        self.customers_page = CustomersPage(self.notebook, self)
        self.instruments_page = InstrumentsPage(self.notebook, self)

        self.notebook.add(self.orders_page.frame, text="📋 Заказы")
        self.notebook.add(self.customers_page.frame, text="👥 Клиенты")
        self.notebook.add(self.instruments_page.frame, text="🔧 Инструменты")

        if user_role in ['старший сотрудник', 'администратор']:
            self.statistics_page = StatisticsPage(self.notebook, self)
            self.notebook.add(self.statistics_page.frame, text="📊 Статистика")

        if user_role == 'администратор':
            self.admin_page = AdminPage(self.notebook, self)
            self.notebook.add(self.admin_page.frame, text="Администратор")

    def create_menu(self):
        menubar = tk.Menu(self.root)
        user_menu = tk.Menu(menubar, tearoff=0)
        user_menu.add_command(label=f"{self.current_user.get('username')}", state='disabled')
        user_menu.add_separator()
        user_menu.add_command(label="Выход", command=self.logout)
        menubar.add_cascade(label="Пользователь", menu=user_menu)
        self.root.config(menu=menubar)

    def logout(self):
        if messagebox.askyesno("Выход", "Вы уверены, что хотите выйти?"):
            APIClient.logout(self.token)
            # oчищаем гуи
            for widget in self.root.winfo_children():
                if isinstance(widget, ttk.Notebook):
                    widget.destroy()
            self.show_auth()


if __name__ == "__main__":
    root = tk.Tk()
    app = ToolRentalApp(root)
    root.mainloop()