# SummerCP/dialogs/user_dialogs.py
import tkinter as tk
from tkinter import ttk, messagebox
from api_client import APIClient
from utils.helpers import center_window


class AddUserDialog:
    def __init__(self, parent, refresh_callback):
        self.parent = parent
        self.refresh_callback = refresh_callback

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Новый пользователь")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        center_window(self.dialog, 700, 400)
        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Новый пользователь", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        ttk.Label(frame, text="Логин:*", font=('Arial', 14)).grid(row=0, column=0, sticky=tk.W, pady=8)
        self.login_entry = ttk.Entry(frame, width=35)
        self.login_entry.grid(row=0, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Пароль:*", font=('Arial', 14)).grid(row=1, column=0, sticky=tk.W, pady=8)
        self.password_entry = ttk.Entry(frame, width=35, show="*")
        self.password_entry.grid(row=1, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Подтверждение:*", font=('Arial', 14)).grid(row=2, column=0, sticky=tk.W, pady=8)
        self.confirm_entry = ttk.Entry(frame, width=35, show="*")
        self.confirm_entry.grid(row=2, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Роль:*", font=('Arial', 14)).grid(row=3, column=0, sticky=tk.W, pady=8)
        self.role_combo = ttk.Combobox(frame, width=33, state='readonly')
        self.role_combo['values'] = ('сотрудник', 'старший сотрудник', 'администратор')
        self.role_combo.current(0)
        self.role_combo.grid(row=3, column=1, pady=8, padx=10)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Сохранить", command=self.save, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def save(self):
        login = self.login_entry.get().strip()
        password = self.password_entry.get()
        confirm = self.confirm_entry.get()
        role = self.role_combo.get()

        if not login or not password:
            messagebox.showwarning("Внимание", "Заполните логин и пароль")
            return

        if password != confirm:
            messagebox.showwarning("Внимание", "Пароли не совпадают")
            return

        if len(password) < 3:
            messagebox.showwarning("Внимание", "Пароль должен содержать минимум 3 символа")
            return

        data = {
            "u_name": login,
            "u_password": password,
            "u_role": role
        }

        success, _ = APIClient.create_admin_user(data)
        if success:
            messagebox.showinfo("Успех", "Пользователь добавлен")
            self.dialog.destroy()
            self.refresh_callback()
        else:
            messagebox.showerror("Ошибка", "Не удалось добавить пользователя\nВозможно, логин уже существует")


class EditUserDialog:
    def __init__(self, parent, user_id, refresh_callback):
        self.parent = parent
        self.user_id = user_id
        self.refresh_callback = refresh_callback

        self.user = APIClient.get_admin_user(user_id)
        if not self.user:
            messagebox.showerror("Ошибка", "Пользователь не найден")
            return

        self.dialog = tk.Toplevel(parent)
        self.dialog.title(f"Редактирование пользователя: {self.user['u_name']}")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        center_window(self.dialog, 700, 400)
        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text=f"Редактирование пользователя", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        ttk.Label(frame, text="Логин:*", font=('Arial', 14)).grid(row=0, column=0, sticky=tk.W, pady=8)
        self.login_entry = ttk.Entry(frame, width=35)
        self.login_entry.grid(row=0, column=1, pady=8, padx=10)
        self.login_entry.insert(0, self.user['u_name'])

        ttk.Label(frame, text="Новый пароль:", font=('Arial', 14)).grid(row=1, column=0, sticky=tk.W, pady=8)
        self.password_entry = ttk.Entry(frame, width=35, show="*")
        self.password_entry.grid(row=1, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Подтверждение:", font=('Arial', 14)).grid(row=2, column=0, sticky=tk.W, pady=8)
        self.confirm_entry = ttk.Entry(frame, width=35, show="*")
        self.confirm_entry.grid(row=2, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Роль:*", font=('Arial', 14)).grid(row=3, column=0, sticky=tk.W, pady=8)
        self.role_combo = ttk.Combobox(frame, width=33, state='readonly')
        self.role_combo['values'] = ('сотрудник', 'старший сотрудник', 'администратор')
        self.role_combo.current(['сотрудник', 'старший сотрудник', 'администратор'].index(self.user['u_role']))
        self.role_combo.grid(row=3, column=1, pady=8, padx=10)

        ttk.Label(frame, text="* Поля, обязательные для заполнения", font=('Arial', 12)).grid(row=4, column=0, columnspan=2, pady=15)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Обновить", command=self.update, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def update(self):
        login = self.login_entry.get().strip()
        password = self.password_entry.get()
        confirm = self.confirm_entry.get()
        role = self.role_combo.get()

        if not login:
            messagebox.showwarning("Внимание", "Заполните логин")
            return

        if password and password != confirm:
            messagebox.showwarning("Внимание", "Пароли не совпадают")
            return

        if password and len(password) < 3:
            messagebox.showwarning("Внимание", "Пароль должен содержать минимум 3 символа")
            return

        data = {
            "u_name": login,
            "u_role": role
        }
        if password:
            data["u_password"] = password

        if APIClient.update_admin_user(self.user_id, data):  # изменено
            messagebox.showinfo("Успех", "Пользователь обновлен")
            self.dialog.destroy()
            self.refresh_callback()
        else:
            messagebox.showerror("Ошибка", "Не удалось обновить пользователя\nВозможно, логин уже существует")