# SummerCP/dialogs/discount_dialog.py
import tkinter as tk
from tkinter import ttk
from api_client import APIClient


class DiscountDialog:
    def __init__(self, parent, order_id, order_info, refresh_callback):
        self.parent = parent
        self.order_id = order_id
        self.order_info = order_info
        self.refresh_callback = refresh_callback
        self.current_discount = 0

        discount_data = APIClient.get_order_discount(order_id)
        if discount_data:
            self.current_discount = discount_data.get('discount_percent', 0)

        self.dialog = tk.Toplevel(parent)
        self.dialog.title(f"Скидка на заказ #{order_id}")
        self.dialog.geometry("500x450")
        self.dialog.configure(bg='#e0e0e0')
        self.dialog.transient(parent)
        self.dialog.grab_set()

        self.create_widgets()

    def create_widgets(self):
        ttk.Label(self.dialog, text="Применить скидку", style='Heading.TLabel').pack(pady=15)

        info_frame = ttk.Frame(self.dialog)
        info_frame.pack(pady=10, padx=20, fill=tk.X)
        ttk.Label(info_frame, text=f"Заказ №{self.order_id} | {self.order_info.get('customer_name', '-')}", font=('Arial', 14)).pack()
        ttk.Label(info_frame, text=self.order_info.get('instrument_name', '-'), font=('Arial', 14)).pack()
        ttk.Label(info_frame, text=f"Сумма: {self.order_info.get('full_price', 0):,.2f} ₽", font=('Arial', 14, 'bold')).pack()

        ttk.Separator(self.dialog, orient='horizontal').pack(fill=tk.X, padx=20, pady=10)

        ttk.Label(self.dialog, text=f"Текущая скидка: {self.current_discount}%", font=('Arial', 14)).pack()

        slider_frame = ttk.Frame(self.dialog)
        slider_frame.pack(pady=20, padx=30, fill=tk.X)

        self.discount_var = tk.IntVar(value=self.current_discount)
        self.slider = ttk.Scale(slider_frame, from_=0, to=100, orient=tk.HORIZONTAL,
                                 variable=self.discount_var, command=self.on_slider_change)
        self.slider.pack(fill=tk.X, pady=10)

        self.value_label = ttk.Label(self.dialog, text=f"{self.current_discount}%", font=('Arial', 24, 'bold'), foreground='#f0a500')
        self.value_label.pack()

        quick_frame = ttk.Frame(self.dialog)
        quick_frame.pack(pady=10)
        for percent in [5, 10, 15, 20, 25, 30, 50]:
            ttk.Button(quick_frame, text=f"{percent}%", width=5,
                       command=lambda p=percent: self.set_discount(p)).pack(side=tk.LEFT, padx=2)

        self.calc_label = ttk.Label(self.dialog, text="", font=('Arial', 14))
        self.calc_label.pack(pady=10)

        btn_frame = ttk.Frame(self.dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="Применить", command=self.apply_discount, style='Success.TButton', width=12).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Сбросить", command=self.reset_discount, width=12).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Отмена", command=self.dialog.destroy, width=12).pack(side=tk.LEFT, padx=5)

        self.on_slider_change()

    def on_slider_change(self, event=None):
        discount = self.discount_var.get()
        self.value_label.config(text=f"{discount}%")
        full_price = self.order_info.get('full_price', 0)
        discounted = full_price * (1 - discount / 100)
        self.calc_label.config(text=f"Сумма со скидкой: {discounted:,.2f} ₽")

    def set_discount(self, percent):
        self.discount_var.set(percent)
        self.on_slider_change()

    def apply_discount(self):
        discount = self.discount_var.get()
        result = APIClient.apply_discount(self.order_id, discount)
        if result and result.get('success'):
            self.dialog.destroy()
            self.refresh_callback()

    def reset_discount(self):
        self.discount_var.set(0)
        self.on_slider_change()
        self.apply_discount()