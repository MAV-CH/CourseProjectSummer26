# SummerCP/dialogs/instrument_dialogs.py
import tkinter as tk
from tkinter import ttk, messagebox
from api_client import APIClient


class AddInstrumentDialog:
    def __init__(self, parent, refresh_callback):
        self.parent = parent
        self.refresh_callback = refresh_callback

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Новый инструмент")
        self.dialog.geometry("700x300")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Новый инструмент", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        ttk.Label(frame, text="Наименование:*", font=('Arial', 14)).grid(row=0, column=0, sticky=tk.W, pady=8)
        self.name_entry = ttk.Entry(frame, width=40)
        self.name_entry.grid(row=0, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Цена за сутки (₽):*", font=('Arial', 14)).grid(row=1, column=0, sticky=tk.W, pady=8)
        self.price_entry = ttk.Entry(frame, width=40)
        self.price_entry.grid(row=1, column=1, pady=8, padx=10)

        ttk.Label(frame, text="Примечание:", font=('Arial', 14)).grid(row=2, column=0, sticky=tk.W, pady=8)
        self.note_entry = ttk.Entry(frame, width=40)
        self.note_entry.grid(row=2, column=1, pady=8, padx=10)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Сохранить", command=self.save, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def save(self):
        try:
            name = self.name_entry.get().strip()
            price_str = self.price_entry.get().strip()

            if not name or not price_str:
                messagebox.showwarning("Внимание", "Заполните наименование и цену")
                return

            price = float(price_str)
            if price <= 0:
                messagebox.showwarning("Внимание", "Цена должна быть больше 0")
                return

            data = {
                "i_name": name,
                "price": price,
                "i_more": self.note_entry.get().strip() if self.note_entry.get().strip() else "-"
            }

            if APIClient.create_instrument(data):
                messagebox.showinfo("Успех", "Инструмент добавлен")
                self.dialog.destroy()
                self.refresh_callback()
            else:
                messagebox.showerror("Ошибка", "Не удалось добавить инструмент")
        except ValueError:
            messagebox.showerror("Ошибка", "Цена должна быть числом")


class EditInstrumentDialog:
    def __init__(self, parent, instrument_id, refresh_callback):
        self.parent = parent
        self.instrument_id = instrument_id
        self.refresh_callback = refresh_callback
        #получам с апишки данные
        instruments = APIClient.get_instruments()
        self.instrument = None
        for i in instruments:
            if i['id'] == instrument_id:
                self.instrument = i
                break

        if not self.instrument:
            messagebox.showerror("Ошибка", "Инструмент не найден")
            return

        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Редактирование инструмента")
        self.dialog.geometry("700x300")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Редактирование инструмента", style='Heading.TLabel').pack(pady=15)

        frame = ttk.Frame(self.dialog)
        frame.pack(padx=30, pady=10)

        ttk.Label(frame, text="Наименование:*", font=('Arial', 14)).grid(row=0, column=0, sticky=tk.W, pady=8)
        self.name_entry = ttk.Entry(frame, width=40)
        self.name_entry.grid(row=0, column=1, pady=8, padx=10)
        self.name_entry.insert(0, self.instrument['i_name'])

        ttk.Label(frame, text="Цена за сутки (₽):*", font=('Arial', 14)).grid(row=1, column=0, sticky=tk.W, pady=8)
        self.price_entry = ttk.Entry(frame, width=40)
        self.price_entry.grid(row=1, column=1, pady=8, padx=10)
        self.price_entry.insert(0, str(self.instrument['price']))

        ttk.Label(frame, text="Примечание:", font=('Arial', 14)).grid(row=2, column=0, sticky=tk.W, pady=8)
        self.note_entry = ttk.Entry(frame, width=40)
        self.note_entry.grid(row=2, column=1, pady=8, padx=10)
        self.note_entry.insert(0, self.instrument['i_more'] if self.instrument['i_more'] != "-" else "")

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Обновить", command=self.update, style='Success.TButton').pack(side=tk.LEFT, padx=10)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy).pack(side=tk.LEFT, padx=10)

    def update(self):
        try:
            name = self.name_entry.get().strip()
            price_str = self.price_entry.get().strip()

            if not name or not price_str:
                messagebox.showwarning("Внимание", "Заполните наименование и цену")
                return

            price = float(price_str)
            if price <= 0:
                messagebox.showwarning("Внимание", "Цена должна быть больше 0")
                return

            data = {
                "i_name": name,
                "price": price,
                "i_more": self.note_entry.get().strip() if self.note_entry.get().strip() else "-"
            }

            if APIClient.update_instrument(self.instrument_id, data):
                messagebox.showinfo("Успех", "Инструмент обновлен")
                self.dialog.destroy()
                self.refresh_callback()
            else:
                messagebox.showerror("Ошибка", "Не удалось обновить инструмент")
        except ValueError:
            messagebox.showerror("Ошибка", "Цена должна быть числом")