import tkinter as tk
from tkinter import ttk, messagebox
from api_client import APIClient
import threading


class BackupDialog:
    def __init__(self, parent, refresh_callback=None):
        self.parent = parent
        self.refresh_callback = refresh_callback

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Управление резервными копиями")
        self.dialog.geometry("700x500")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()
        self.load_backups()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Резервное копирование базы данных", style='Heading.TLabel').pack(pady=15)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=10)

        self.create_btn = ttk.Button(btn_frame, text="Создать бэкап", command=self.create_backup,
                                      style='Success.TButton', width=15)
        self.create_btn.pack(side=tk.LEFT, padx=5)

        self.restore_btn = ttk.Button(btn_frame, text="Восстановить", command=self.restore_backup,
                                       width=15, state='disabled')
        self.restore_btn.pack(side=tk.LEFT, padx=5)

        self.delete_btn = ttk.Button(btn_frame, text="Удалить", command=self.delete_backup,
                                      style='Danger.TButton', width=15, state='disabled')
        self.delete_btn.pack(side=tk.LEFT, padx=5)

        # информация
        info_frame = ttk.Frame(self.dialog)
        info_frame.pack(fill=tk.X, padx=20, pady=5)
        ttk.Label(info_frame, text="💡 Восстановление заменит ВСЕ текущие данные! Будьте осторожны.",
                  foreground='orange', font=('Arial', 14)).pack()

        # таблица бэкапов
        columns = ('Имя файла', 'Размер', 'Дата создания')
        col_widths = {'Имя файла': 350, 'Размер': 100, 'Дата создания': 180}

        table_frame = ttk.Frame(self.dialog)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)

        scroll_y = ttk.Scrollbar(table_frame)
        scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_x = ttk.Scrollbar(table_frame, orient=tk.HORIZONTAL)
        scroll_x.pack(side=tk.BOTTOM, fill=tk.X)

        self.tree = ttk.Treeview(table_frame, columns=columns, show='headings',
                                  yscrollcommand=scroll_y.set, xscrollcommand=scroll_x.set)
        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=col_widths.get(col, 100))

        self.tree.pack(fill=tk.BOTH, expand=True)
        scroll_y.config(command=self.tree.yview)
        scroll_x.config(command=self.tree.xview)

        self.tree.bind('<<TreeviewSelect>>', self.on_select)

        self.status_var = tk.StringVar(value="Готов")
        status_bar = ttk.Label(self.dialog, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W)
        status_bar.pack(fill=tk.X, side=tk.BOTTOM, padx=5, pady=5)

    def on_select(self, event):
        selected = self.tree.selection()
        if selected:
            self.restore_btn.config(state='normal')
            self.delete_btn.config(state='normal')
        else:
            self.restore_btn.config(state='disabled')
            self.delete_btn.config(state='disabled')

    def load_backups(self):
        for item in self.tree.get_children():
            self.tree.delete(item)

        backups = APIClient.get_backup_list()
        for backup in backups:
            size_kb = backup['size'] / 1024
            if size_kb < 1024:
                size_str = f"{size_kb:.1f} KB"
            else:
                size_str = f"{size_kb/1024:.1f} MB"

            self.tree.insert('', tk.END, values=(
                backup['name'],
                size_str,
                backup['created']
            ))

    def create_backup(self):
        self.create_btn.config(state='disabled', text="Создание...")
        self.status_var.set("Создание резервной копии...")

        def do_backup():
            result = APIClient.create_backup()
            self.dialog.after(0, lambda: self.backup_done(result))

        thread = threading.Thread(target=do_backup)
        thread.start()

    def backup_done(self, result):
        self.create_btn.config(state='normal', text="Создать бэкап")
        if result.get('success'):
            messagebox.showinfo("Успех", f"Бэкап создан: {result.get('file')}")
            self.load_backups()
            self.status_var.set(f"Бэкап создан: {result.get('file')}")
            if self.refresh_callback:
                self.refresh_callback()
        else:
            messagebox.showerror("Ошибка", f"Не удалось создать бэкап:\n{result.get('message')}")
            self.status_var.set("Ошибка создания бэкапа")

    def restore_backup(self):
        selected = self.tree.selection()
        if not selected:
            return

        backup_name = self.tree.item(selected[0])['values'][0]

        if not messagebox.askyesno("Подтверждение",
                                    f"Восстановление из бэкапа '{backup_name}'?\n\n"
                                    "ВНИМАНИЕ! Все текущие данные будут ЗАМЕНЕНЫ данными из бэкапа!\n"
                                    "Это действие необратимо.\n\n"
                                    "Продолжить?"):
            return

        self.restore_btn.config(state='disabled', text="Восстановление...")
        self.status_var.set("Восстановление базы данных...")

        def do_restore():
            result = APIClient.restore_backup(backup_name)
            self.dialog.after(0, lambda: self.restore_done(result))

        thread = threading.Thread(target=do_restore)
        thread.start()

    def restore_done(self, result):
        self.restore_btn.config(state='normal', text="Восстановить")
        if result.get('success'):
            messagebox.showinfo("Успех", "База данных восстановлена из бэкапа")
            self.status_var.set("База данных восстановлена")
            if self.refresh_callback:
                self.refresh_callback()
        else:
            messagebox.showerror("Ошибка", f"Не удалось восстановить:\n{result.get('message')}")
            self.status_var.set("Ошибка восстановления")

    def delete_backup(self):
        selected = self.tree.selection()
        if not selected:
            return

        backup_name = self.tree.item(selected[0])['values'][0]

        if messagebox.askyesno("Подтверждение", f"Удалить бэкап '{backup_name}'?"):
            result = APIClient.delete_backup(backup_name)
            if result.get('success'):
                messagebox.showinfo("Успех", "Бэкап удален")
                self.load_backups()
                self.status_var.set(f"Бэкап удален: {backup_name}")
            else:
                messagebox.showerror("Ошибка", f"Не удалось удалить:\n{result.get('message')}")