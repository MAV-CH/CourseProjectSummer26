import tkinter as tk
from tkinter import ttk, messagebox
from api_client import APIClient
from pages.base_page import BasePage
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import matplotlib

matplotlib.use('TkAgg')
matplotlib.rcParams['font.family'] = 'DejaVu Sans'


class StatisticsPage(BasePage):
    def __init__(self, notebook, app):
        super().__init__(notebook, app)
        self.init_page()
        self.current_period = "all"

    def init_page(self):
        title_frame = ttk.Frame(self.frame)
        title_frame.pack(fill=tk.X, pady=10)
        ttk.Label(title_frame, text="Статистика и аналитика", style='Title.TLabel').pack()

        self.stats_notebook = ttk.Notebook(self.frame)
        self.stats_notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        self.instruments_frame = ttk.Frame(self.stats_notebook)
        self.stats_notebook.add(self.instruments_frame, text="🔧 Топ инструментов")
        self.setup_instruments_tab()

        self.customers_frame = ttk.Frame(self.stats_notebook)
        self.stats_notebook.add(self.customers_frame, text="👥 Топ клиентов")
        self.setup_customers_tab()

        self.revenue_frame = ttk.Frame(self.stats_notebook)
        self.stats_notebook.add(self.revenue_frame, text="💰 Прибыль")
        self.setup_revenue_tab()

    def setup_instruments_tab(self):
        period_frame = ttk.Frame(self.instruments_frame)
        period_frame.pack(pady=10)

        periods = [
            ("Все время", "all"),
            ("Месяц", "month"),
            ("Квартал", "quarter"),
            ("Полгода", "half_year"),
            ("Год", "year")
        ]

        for text, period in periods:
            btn = ttk.Button(period_frame, text=text, width=12, command=lambda p=period: self.load_instruments_stats(p))
            btn.pack(side=tk.LEFT, padx=5)

        columns = ('Позиция', 'ID', 'Наименование', 'Кол-во аренд', 'Выручка (₽)')
        col_widths = {'Позиция': 60, 'ID': 50, 'Наименование': 300, 'Кол-во аренд': 120, 'Выручка (₽)': 150}

        table_frame = ttk.Frame(self.instruments_frame)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        scroll_y = ttk.Scrollbar(table_frame)
        scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_x = ttk.Scrollbar(table_frame, orient=tk.HORIZONTAL)
        scroll_x.pack(side=tk.BOTTOM, fill=tk.X)

        self.instruments_tree = ttk.Treeview(table_frame, columns=columns, show='headings', yscrollcommand=scroll_y.set, xscrollcommand=scroll_x.set)
        for col in columns:
            self.instruments_tree.heading(col, text=col)
            self.instruments_tree.column(col, width=col_widths.get(col, 100))
        self.instruments_tree.pack(fill=tk.BOTH, expand=True)
        scroll_y.config(command=self.instruments_tree.yview)
        scroll_x.config(command=self.instruments_tree.xview)

        self.instruments_figure = plt.Figure(figsize=(6, 4), dpi=100)
        self.instruments_ax = self.instruments_figure.add_subplot(111)
        self.instruments_canvas = FigureCanvasTkAgg(self.instruments_figure, self.instruments_frame)
        self.instruments_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        self.load_instruments_stats("all")

    def setup_customers_tab(self):
        period_frame = ttk.Frame(self.customers_frame)
        period_frame.pack(pady=10)

        periods = [
            ("Все время", "all"),
            ("Месяц", "month"),
            ("Сезон", "season"),
            ("Полгода", "half_year"),
            ("Год", "year")
        ]

        for text, period in periods:
            btn = ttk.Button(period_frame, text=text, width=12, command=lambda p=period: self.load_customers_stats(p))
            btn.pack(side=tk.LEFT, padx=5)

        columns = ('Позиция', 'ID', 'ФИО', 'Телефон', 'Кол-во аренд', 'Потрачено (₽)')
        col_widths = {'Позиция': 60, 'ID': 50, 'ФИО': 250, 'Телефон': 120, 'Кол-во аренд': 120, 'Потрачено (₽)': 150}

        table_frame = ttk.Frame(self.customers_frame)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        scroll_y = ttk.Scrollbar(table_frame)
        scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_x = ttk.Scrollbar(table_frame, orient=tk.HORIZONTAL)
        scroll_x.pack(side=tk.BOTTOM, fill=tk.X)

        self.customers_tree = ttk.Treeview(table_frame, columns=columns, show='headings', yscrollcommand=scroll_y.set, xscrollcommand=scroll_x.set)
        for col in columns:
            self.customers_tree.heading(col, text=col)
            self.customers_tree.column(col, width=col_widths.get(col, 100))
        self.customers_tree.pack(fill=tk.BOTH, expand=True)
        scroll_y.config(command=self.customers_tree.yview)
        scroll_x.config(command=self.customers_tree.xview)

        self.customers_figure = plt.Figure(figsize=(6, 4), dpi=100)
        self.customers_ax = self.customers_figure.add_subplot(111)
        self.customers_canvas = FigureCanvasTkAgg(self.customers_figure, self.customers_frame)
        self.customers_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        self.load_customers_stats("all")

    def setup_revenue_tab(self):
        period_frame = ttk.Frame(self.revenue_frame)
        period_frame.pack(pady=10)

        periods = [
            ("Все время", "all"),
            ("По месяцам", "month"),
            ("Полгода", "half_year"),
            ("Год", "year")
        ]

        for text, period in periods:
            btn = ttk.Button(period_frame, text=text, width=12, command=lambda p=period: self.load_revenue_stats(p))
            btn.pack(side=tk.LEFT, padx=5)

        self.stats_frame = ttk.Frame(self.revenue_frame)
        self.stats_frame.pack(fill=tk.X, padx=20, pady=10)

        self.total_revenue_label = ttk.Label(self.stats_frame, text="Общая выручка: -- ₽", font=('Arial', 14, 'bold'))
        self.total_revenue_label.pack(side=tk.LEFT, padx=20)

        self.total_orders_label = ttk.Label(self.stats_frame, text="Всего заказов: --", font=('Arial', 14, 'bold'))
        self.total_orders_label.pack(side=tk.LEFT, padx=20)

        self.avg_order_label = ttk.Label(self.stats_frame, text="Средний чек: -- ₽", font=('Arial', 14, 'bold'))
        self.avg_order_label.pack(side=tk.LEFT, padx=20)

        columns = ('Период', 'Выручка (₽)', 'Кол-во заказов', 'Накоплено (₽)')
        col_widths = {'Период': 150, 'Выручка (₽)': 150, 'Кол-во заказов': 150, 'Накоплено (₽)': 200}

        table_frame = ttk.Frame(self.revenue_frame)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        scroll_y = ttk.Scrollbar(table_frame)
        scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_x = ttk.Scrollbar(table_frame, orient=tk.HORIZONTAL)
        scroll_x.pack(side=tk.BOTTOM, fill=tk.X)

        self.revenue_tree = ttk.Treeview(table_frame, columns=columns, show='headings', yscrollcommand=scroll_y.set, xscrollcommand=scroll_x.set)
        for col in columns:
            self.revenue_tree.heading(col, text=col)
            self.revenue_tree.column(col, width=col_widths.get(col, 100))
        self.revenue_tree.pack(fill=tk.BOTH, expand=True)
        scroll_y.config(command=self.revenue_tree.yview)
        scroll_x.config(command=self.revenue_tree.xview)

        self.revenue_figure = plt.Figure(figsize=(8, 5), dpi=100)
        self.revenue_ax = self.revenue_figure.add_subplot(111)
        self.revenue_canvas = FigureCanvasTkAgg(self.revenue_figure, self.revenue_frame)
        self.revenue_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        self.load_revenue_stats("all")
        self.load_dashboard_stats()

    def load_dashboard_stats(self):
        try:
            stats = APIClient.get_dashboard_stats()
            if stats:
                self.total_revenue_label.config(text=f"Общая выручка: {stats.get('total_revenue', 0):,.2f} ₽")
                self.total_orders_label.config(text=f"Всего заказов: {stats.get('total_orders', 0)}")
                self.avg_order_label.config(text=f"Средний чек: {stats.get('avg_order_value', 0):,.2f} ₽")
        except Exception as e:
            print(f"Ошибка загрузки дашборда: {e}")

    def load_instruments_stats(self, period):
        self.current_period = period
        try:
            data = APIClient.get_top_instruments(period)

            # очистка таблицы
            for item in self.instruments_tree.get_children():
                self.instruments_tree.delete(item)

            # заполнение таблицы
            for i, row in enumerate(data, 1):
                self.instruments_tree.insert('', tk.END, values=(
                    i, row.get('id', '-'), row.get('i_name', '-'),
                    row.get('rental_count', 0), f"{row.get('total_revenue', 0):,.2f}"
                ))

            # построение графика
            self.instruments_ax.clear()
            names = [row.get('i_name', '-')[:20] for row in data[:10]]
            counts = [row.get('rental_count', 0) for row in data[:10]]

            if names:
                bars = self.instruments_ax.barh(names[::-1], counts[::-1], color='#ffd700')
                self.instruments_ax.set_xlabel('Количество аренд')
                self.instruments_ax.set_title('Топ инструментов по популярности')
                self.instruments_ax.tick_params(axis='y', labelsize=8)
                self.instruments_canvas.draw()

        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось загрузить статистику инструментов: {e}")

    def load_customers_stats(self, period):
        self.current_period = period
        try:
            data = APIClient.get_top_customers(period)

            # очистка таблицы
            for item in self.customers_tree.get_children():
                self.customers_tree.delete(item)

            # заполнение таблицы
            for i, row in enumerate(data, 1):
                full_name = row.get('full_name', '-')
                # убираем None значения
                if full_name is None:
                    full_name = '-'
                self.customers_tree.insert('', tk.END, values=(
                    i, row.get('id', '-'), full_name,
                    row.get('phone', '-'), row.get('rental_count', 0),
                    f"{row.get('total_spent', 0):,.2f}"
                ))

            # построение графика
            self.customers_ax.clear()
            names = [row.get('full_name', '-')[:15] for row in data[:10]]
            spent = [row.get('total_spent', 0) for row in data[:10]]

            if names:
                bars = self.customers_ax.barh(names[::-1], spent[::-1], color='#4CAF50')
                self.customers_ax.set_xlabel('Потрачено (₽)')
                self.customers_ax.set_title('Топ клиентов по затратам')
                self.customers_ax.tick_params(axis='y', labelsize=8)
                self.customers_canvas.draw()

        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось загрузить статистику клиентов: {e}")

    def load_revenue_stats(self, period):
        self.current_period = period
        try:
            data = APIClient.get_revenue_stats(period)

            # очистка таблицы
            for item in self.revenue_tree.get_children():
                self.revenue_tree.delete(item)

            if period == "all":
                if data:
                    row = data[0]
                    self.revenue_tree.insert('', tk.END, values=(
                        "Все время",
                        f"{row.get('total_revenue', 0):,.2f}",
                        row.get('total_orders', 0),
                        "-"
                    ))
            elif period == "season":
                for row in data:
                    self.revenue_tree.insert('', tk.END, values=(
                        row.get('season', '-'),
                        f"{row.get('revenue', 0):,.2f}",
                        row.get('orders_count', 0),
                        "-"
                    ))
            else:
                for row in data:
                    cumulative = row.get('cumulative_revenue', row.get('revenue', 0))
                    self.revenue_tree.insert('', tk.END, values=(
                        row.get('month', row.get('season', '-')),
                        f"{row.get('revenue', 0):,.2f}",
                        row.get('orders_count', '-'),
                        f"{cumulative:,.2f}" if cumulative else "-"
                    ))

            self.revenue_ax.clear()

            if period == "season":
                seasons = [row.get('season', '-') for row in data]
                revenues = [float(row.get('revenue', 0)) for row in data]
                if seasons and sum(revenues) > 0:
                    colors = ['#ffd700', '#4CAF50', '#2196F3', '#f44336']
                    self.revenue_ax.pie(revenues, labels=seasons, autopct='%1.1f%%', colors=colors[:len(seasons)])
                    self.revenue_ax.set_title('Распределение выручки по сезонам')
            elif period == "month" or period == "half_year" or period == "year":
                months = [row.get('month', '-') for row in data]
                revenues = [float(row.get('revenue', 0)) for row in data]
                if months:
                    self.revenue_ax.plot(months, revenues, marker='o', color='#ffd700', linewidth=2, markersize=6)
                    self.revenue_ax.fill_between(range(len(months)), revenues, alpha=0.3, color='#ffd700')
                    self.revenue_ax.set_xlabel('Период')
                    self.revenue_ax.set_ylabel('Выручка (₽)')
                    self.revenue_ax.set_title('Динамика выручки')
                    self.revenue_ax.tick_params(axis='x', rotation=45, labelsize=8)
                    self.revenue_ax.grid(True, alpha=0.3)
            else:
                if data:
                    row = data[0]
                    categories = ['Выручка']
                    values = [row.get('total_revenue', 0)]
                    self.revenue_ax.bar(categories, values, color='#ffd700')
                    self.revenue_ax.set_ylabel('₽')
                    self.revenue_ax.set_title('Общая выручка')

            self.revenue_figure.tight_layout()
            self.revenue_canvas.draw()

        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось загрузить статистику прибыли: {e}")