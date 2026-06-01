# SummerCP/dialogs/auth_dialog.py
import tkinter as tk
from tkinter import ttk, messagebox
import json
import os
from api_client import APIClient


def center_window(window, width, height):
    screen_width = window.winfo_screenwidth()
    screen_height = window.winfo_screenheight()
    x = (screen_width - width) // 2
    y = (screen_height - height) // 2
    window.geometry(f"{width}x{height}+{x}+{y}")


class AuthDialog:
    def __init__(self, parent, login_callback):
        self.parent = parent
        self.login_callback = login_callback
        self.token = None

        self.config_file = os.path.join(os.path.dirname(__file__), "..", "config.json")

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Авторизация")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.resizable(False, False)

        center_window(self.dialog, 400, 350)

        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()
        self.load_saved_login()
        self.dialog.protocol("WM_DELETE_WINDOW", self.on_close)

    def create_widgets(self):
        title_frame = tk.Frame(self.dialog, bg='#ffd700', height=80)
        title_frame.pack(fill=tk.X)
        title_frame.pack_propagate(False)

        tk.Label(title_frame, text="Система проката инструментов",
                 font=('Arial', 14, 'bold'), bg='#ffd700', fg='#333').pack(expand=True)

        main_frame = ttk.Frame(self.dialog, padding="30 20 30 20")
        main_frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(main_frame, text="Логин:", font=('Arial', 14)).grid(row=0, column=0, sticky=tk.W, pady=10)
        self.login_entry = ttk.Entry(main_frame, width=25, font=('Arial', 14))
        self.login_entry.grid(row=0, column=1, pady=10, padx=10)
        self.login_entry.focus()

        ttk.Label(main_frame, text="Пароль:", font=('Arial', 14)).grid(row=1, column=0, sticky=tk.W, pady=10)
        self.password_entry = ttk.Entry(main_frame, width=25, font=('Arial', 14), show="•")
        self.password_entry.grid(row=1, column=1, pady=10, padx=10)

        self.remember_var = tk.BooleanVar(value=False)
        self.remember_check = ttk.Checkbutton(main_frame, text="Запомнить логин",
                                              variable=self.remember_var)
        self.remember_check.grid(row=2, column=0, columnspan=2, pady=10)

        btn_frame = ttk.Frame(main_frame)
        btn_frame.grid(row=3, column=0, columnspan=2, pady=20)

        self.login_btn = ttk.Button(btn_frame, text="Войти", command=self.do_login,
                                    style='Success.TButton', width=12)
        self.login_btn.pack(side=tk.LEFT, padx=5)

        self.exit_btn = ttk.Button(btn_frame, text="Выход", command=self.on_close, width=12)
        self.exit_btn.pack(side=tk.LEFT, padx=5)

        self.status_label = ttk.Label(main_frame, text="", font=('Arial', 14))
        self.status_label.grid(row=4, column=0, columnspan=2, pady=5)

        self.dialog.bind('<Return>', lambda e: self.do_login())

    def load_saved_login(self):
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    if config.get('remember_me'):
                        self.login_entry.insert(0, config.get('username', ''))
                        self.remember_var.set(True)
        except Exception as e:
            print(f"Ошибка загрузки настроек: {e}")

    def save_login(self):
        try:
            config = {}
            if self.remember_var.get():
                config = {
                    'remember_me': True,
                    'username': self.login_entry.get().strip()
                }
            else:
                config = {'remember_me': False}
            with open(self.config_file, 'w') as f:
                json.dump(config, f)
        except Exception as e:
            print(f"Ошибка сохранения настроек: {e}")

    def do_login(self):
        login = self.login_entry.get().strip()
        password = self.password_entry.get()

        if not login or not password:
            self.status_label.config(text="Заполните все поля", foreground='red')
            return

        self.login_btn.config(state='disabled', text="Вход...")
        self.status_label.config(text="Проверка...", foreground='blue')

        self.dialog.after(100, lambda: self._login_request(login, password))

    def _login_request(self, login, password):
        try:
            result = APIClient.login(login, password)
            if result and result.get('success'):
                self.save_login()
                self.token = result.get('token')
                self.dialog.destroy()
                self.login_callback(result)
            else:
                error = result.get('detail', 'Неверный логин или пароль') if result else 'Ошибка соединения'
                self.status_label.config(text=f"{error}", foreground='red')
                self.login_btn.config(state='normal', text="Войти")
                self.password_entry.delete(0, tk.END)
                self.password_entry.focus()
        except Exception as e:
            self.status_label.config(text=f"Ошибка: {e}", foreground='red')
            self.login_btn.config(state='normal', text="Войти")

    def on_close(self):
        if messagebox.askyesno("Выход", "Вы уверены, что хотите выйти?"):
            self.dialog.destroy()
            self.parent.quit()