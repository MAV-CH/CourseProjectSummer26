def format_price(price):
    return f"{price:.2f} ₽"

def format_date(date_str):
    if date_str:
        return date_str[:10]
    return "-"

def format_datetime(dt_str):
    if dt_str:
        return dt_str[:10], dt_str[11:16]
    return "-", "-"

def escape_html(text):
    if not text:
        return ""
    return str(text).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def center_window(window, width, height):
    screen_width = window.winfo_screenwidth()
    screen_height = window.winfo_screenheight()
    x = (screen_width - width) // 2
    y = (screen_height - height) // 2
    window.geometry(f"{width}x{height}+{x}+{y}")