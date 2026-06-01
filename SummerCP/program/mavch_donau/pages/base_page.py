# SummerCP/pages/base_page.py
import tkinter as tk
from tkinter import ttk


class BasePage:
    def __init__(self, notebook, app):
        self.notebook = notebook
        self.app = app
        self.frame = ttk.Frame(notebook)
        self.tree = None
        self.search_entry = None

    def setup_styles(self):
        style = ttk.Style()
        style.configure('Treeview', rowheight=25)

    def create_search_frame(self, label_text):
        search_frame = ttk.Frame(self.frame)
        search_frame.pack(pady=10, fill=tk.X, padx=20)
        ttk.Label(search_frame, text=label_text).pack(side=tk.LEFT, padx=5)
        self.search_entry = ttk.Entry(search_frame, width=50)
        self.search_entry.pack(side=tk.LEFT, padx=5)
        self.search_entry.bind('<KeyRelease>', self.on_search)

        ttk.Label(search_frame, text="Экспорт:").pack(side=tk.LEFT, padx=5)
        ttk.Button(search_frame, text="CSV", width=5, command=self.export_csv).pack(side=tk.LEFT, padx=2)
        ttk.Button(search_frame, text="Excel", width=5, command=self.export_excel).pack(side=tk.LEFT, padx=2)

        return search_frame

    def export_csv(self):
        pass

    def export_excel(self):
        pass

    def on_search(self, event):
        pass

    def create_table(self, columns, col_widths):
        # фрейм для таблицы и скролла
        table_frame = ttk.Frame(self.frame)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)

        scroll_y = ttk.Scrollbar(table_frame)
        scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_x = ttk.Scrollbar(table_frame, orient=tk.HORIZONTAL)
        scroll_x.pack(side=tk.BOTTOM, fill=tk.X)

        self.tree = ttk.Treeview(table_frame, columns=columns, show='headings', yscrollcommand=scroll_y.set, xscrollcommand=scroll_x.set)
        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=col_widths.get(col, 100))

        self.tree.pack(fill=tk.BOTH, expand=True)
        scroll_y.config(command=self.tree.yview)
        scroll_x.config(command=self.tree.xview)

        return self.tree

