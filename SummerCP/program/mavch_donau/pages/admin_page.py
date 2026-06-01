import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from api_client import APIClient
from pages.base_page import BasePage
from dialogs.user_dialogs import AddUserDialog, EditUserDialog
from dialogs.backup_dialog import BackupDialog


class AdminPage(BasePage):
    def __init__(self, notebook, app):
        super().__init__(notebook, app)
        self.current_user = app.current_user
        self.init_page()

    def init_page(self):
        title_frame = ttk.Frame(self.frame)
        title_frame.pack(fill=tk.X, pady=10)
        ttk.Label(title_frame, text="Управление пользователями", style='Title.TLabel').pack()
        ttk.Label(title_frame, text="Административная панель", font=('Arial', 14), foreground='gray').pack()

        btn_frame = ttk.Frame(self.frame)
        btn_frame.pack(pady=10)

        ttk.Button(btn_frame, text="Добавить пользователя", command=self.add_user,
                   style='Success.TButton', width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Редактировать", command=self.edit_user,
                   width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Удалить", command=self.delete_user,
                   style='Danger.TButton', width=20).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Резервное копирование", command=self.open_backup,
                   width=22).pack(side=tk.LEFT, padx=5)

        columns = ('ID', 'Логин', 'Роль')
        col_widths = {'ID': 80, 'Логин': 300, 'Роль': 200}

        self.create_table(columns, col_widths)

        self.tree.tag_configure('admin', background='#ffe0b3')
        self.tree.tag_configure('senior', background='#e0f0ff')
        self.tree.tag_configure('staff', background='#ffffff')

        self.create_search_frame("🔍 Поиск по логину:")
        self.load_users()

    def load_users(self, search_text=""):
        for item in self.tree.get_children():
            self.tree.delete(item)

        users = APIClient.get_admin_users()

        if search_text:
            search_lower = search_text.lower()
            users = [u for u in users if search_lower in u['u_name'].lower()]

        for user in users:
            if user['u_role'] == 'администратор':
                tag = 'admin'
            elif user['u_role'] == 'старший сотрудник':
                tag = 'senior'
            else:
                tag = 'staff'

            role_display = {
                'администратор': 'Администратор',
                'старший сотрудник': 'Старший сотрудник',
                'сотрудник': 'Сотрудник'
            }.get(user['u_role'], user['u_role'])

            self.tree.insert('', tk.END, values=(
                user['id'],
                user['u_name'],
                role_display
            ), tags=(tag,))

    def on_search(self, event):
        self.load_users(self.search_entry.get())

    def add_user(self):
        dialog = AddUserDialog(self.app.root, self.load_users)

    def edit_user(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите пользователя")
            return
        user_id = self.tree.item(selected[0])['values'][0]
        dialog = EditUserDialog(self.app.root, user_id, self.load_users)

    def delete_user(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите пользователя")
            return
        user_id = self.tree.item(selected[0])['values'][0]
        username = self.tree.item(selected[0])['values'][1]
        role = self.tree.item(selected[0])['values'][2]

        warning = ""
        if "Администратор" in role:
            warning = "\n\nВНИМАНИЕ! Это администратор. Удаление может быть ограничено."

        if messagebox.askyesno("Подтверждение", f"Удалить пользователя '{username}'?{warning}"):
            if APIClient.delete_admin_user(user_id):  # изменено
                messagebox.showinfo("Успех", "Пользователь удален")
                self.load_users()
            else:
                messagebox.showerror("Ошибка", "Не удалось удалить пользователя\nВозможно, это последний администратор")

    def open_backup(self):
        dialog = BackupDialog(self.app.root, self.load_users)

    def export_csv(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv")],
            initialfile="users.csv"
        )
        if file_path:
            data = APIClient.export_instruments_to_csv()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")

    def export_excel(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".xlsx",
            filetypes=[("Excel files", "*.xlsx")],
            initialfile="users.xlsx"
        )
        if file_path:
            data = APIClient.export_instruments_to_excel()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")