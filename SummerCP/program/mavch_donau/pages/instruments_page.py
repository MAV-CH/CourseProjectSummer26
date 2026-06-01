import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from api_client import APIClient
from pages.base_page import BasePage
from dialogs.instrument_dialogs import AddInstrumentDialog, EditInstrumentDialog


class InstrumentsPage(BasePage):
    def __init__(self, notebook, app):
        super().__init__(notebook, app)
        self.current_user = app.current_user
        self.init_page()

    def init_page(self):
        title_frame = ttk.Frame(self.frame)
        title_frame.pack(fill=tk.X, pady=10)
        ttk.Label(title_frame, text="Управление инструментами", style='Title.TLabel').pack()

        # кнопки только для старшего и админа
        user_role = self.current_user.get('role', 'сотрудник')

        if user_role in ['старший сотрудник', 'администратор']:
            btn_frame = ttk.Frame(self.frame)
            btn_frame.pack(pady=10)

            ttk.Button(btn_frame, text="Добавить инструмент", command=self.add_instrument,
                       style='Success.TButton', width=18).pack(side=tk.LEFT, padx=5)
            ttk.Button(btn_frame, text="Редактировать", command=self.edit_instrument,
                       width=18).pack(side=tk.LEFT, padx=5)
            ttk.Button(btn_frame, text="Сменить статус", command=self.change_status,
                       width=18).pack(side=tk.LEFT, padx=5)
            ttk.Button(btn_frame, text="Удалить", command=self.delete_instrument,
                       style='Danger.TButton', width=18).pack(side=tk.LEFT, padx=5)
        else:
            info_frame = ttk.Frame(self.frame)
            info_frame.pack(pady=10)
            ttk.Label(info_frame,
                      text="",
                      foreground='blue', font=('Arial', 14)).pack()

        columns = ('ID', 'Наименование', 'Цена за сутки', 'Статус', 'Примечание')
        col_widths = {'ID': 50, 'Наименование': 350, 'Цена за сутки': 120,
                      'Статус': 120, 'Примечание': 500}

        self.create_table(columns, col_widths)

        self.create_search_frame("Поиск по наименованию:")

        self.load_instruments()

    def load_instruments(self, search_text=""):
        for item in self.tree.get_children():
            self.tree.delete(item)

        instruments = APIClient.get_instruments()

        if search_text:
            search_lower = search_text.lower()
            instruments = [i for i in instruments if search_lower in i['i_name'].lower()]

        for instrument in instruments:
            status = instrument.get('i_status', 'доступен')
            status_text = "Доступен" if status == 'доступен' else "Недоступен"

            self.tree.insert('', tk.END, values=(
                instrument['id'],
                instrument['i_name'],
                f"{instrument['price']:.2f} ₽",
                status_text,
                instrument.get('i_more', '-')
            ))

    def on_search(self, event):
        self.load_instruments(self.search_entry.get())

    def add_instrument(self):
        dialog = AddInstrumentDialog(self.app.root, self.load_instruments)

    def edit_instrument(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите инструмент")
            return
        instrument_id = self.tree.item(selected[0])['values'][0]
        dialog = EditInstrumentDialog(self.app.root, instrument_id, self.load_instruments)

    def change_status(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите инструмент")
            return

        instrument_id = self.tree.item(selected[0])['values'][0]
        instrument_name = self.tree.item(selected[0])['values'][1]
        current_status_text = self.tree.item(selected[0])['values'][3]

        current_status = 'доступен' if current_status_text == 'Доступен' else 'недоступен'
        new_status = 'недоступен' if current_status == 'доступен' else 'доступен'
        new_status_text = "Недоступен" if new_status == 'недоступен' else "Доступен"

        if messagebox.askyesno("Подтверждение",
                               f"Изменить статус инструмента '{instrument_name}' на '{new_status_text}'?"):
            if APIClient.update_instrument_status(instrument_id, new_status):
                messagebox.showinfo("Успех", f"Статус инструмента изменен на '{new_status_text}'")
                self.load_instruments()
            else:
                messagebox.showerror("Ошибка", "Не удалось изменить статус инструмента")

    def delete_instrument(self):
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Внимание", "Выберите инструмент")
            return
        instrument_id = self.tree.item(selected[0])['values'][0]
        instrument_name = self.tree.item(selected[0])['values'][1]

        if messagebox.askyesno("Подтверждение", f"Удалить инструмент '{instrument_name}'?"):
            if APIClient.delete_instrument(instrument_id):
                messagebox.showinfo("Успех", "Инструмент удален")
                self.load_instruments()
            else:
                messagebox.showerror("Ошибка", "Не удалось удалить инструмент\nВозможно он используется в заказах")

    def export_csv(self):
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv")],
            initialfile="instruments.csv"
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
            initialfile="instruments.xlsx"
        )
        if file_path:
            data = APIClient.export_instruments_to_excel()
            if data:
                with open(file_path, 'wb') as f:
                    f.write(data)
                messagebox.showinfo("Успех", f"Экспортировано в {file_path}")