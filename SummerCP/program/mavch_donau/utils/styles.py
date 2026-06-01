from tkinter import ttk

def setup_styles():
    style = ttk.Style()
    style.theme_use('clam')

    bg_color = '#e0e0e0'
    treeview_bg = '#ffffff'
    treeview_fg = '#333333'
    treeview_selected = '#2196F3'
    treeview_heading_bg = '#d0d0d0'
    treeview_heading_fg = '#333333'

    style.configure('TFrame', background=bg_color)
    style.configure('TLabel', background=bg_color, foreground='#333')
    style.configure('TButton', background='#d0d0d0', foreground='#333', padding=5)
    style.configure('Success.TButton', background='#4CAF50', foreground='white')
    style.configure('Danger.TButton', background='#f44336', foreground='white')
    style.configure('Title.TLabel', font=('Arial', 20, 'bold'), foreground='#2196F3', background=bg_color)
    style.configure('Heading.TLabel', font=('Arial', 14, 'bold'), background=bg_color)

    style.configure('Treeview',
                    background=treeview_bg,
                    foreground=treeview_fg,
                    fieldbackground=treeview_bg,
                    rowheight=25)

    style.configure('Treeview.Heading',
                    background=treeview_heading_bg,
                    foreground=treeview_heading_fg,
                    font=('Arial', 12, 'bold'))

    style.map('Treeview',
              background=[('selected', treeview_selected)],
              foreground=[('selected', 'white')])

    style.map('Treeview.Heading',
              background=[('active', '#c0c0c0')])