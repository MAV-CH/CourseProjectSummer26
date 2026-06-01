create type order_status as enum ('неоплачено', 'оплачено', 'возвращено', 'невозвращено');

create type instrument_status as enum ('доступен', 'недоступен');

create type user_role as enum ('сотрудник', 'старший сотрудник', 'администратор');

create table passport (
    id serial primary key,
    p_number varchar(20) unique not null,
    p_home varchar(256) not null
);

create table customer (
    id serial primary key,
    id_passport int unique not null,
    f_name varchar(50) not null,
    l_name varchar(50) not null,
    v_name varchar(50),
    phone varchar(20) not null,
    
    foreign key (id_passport) references passport(id) on delete cascade
);

create table instrument (
    id serial primary key,
    i_name varchar(100) not null,
    i_category varchar(50),
    price decimal(10, 2) not null,
    i_more varchar(256) default '-',
    i_status instrument_status default 'доступен'
);

create table price_history (
    id serial primary key,
    id_instrument int not null,
    old_price decimal(10, 2) not null,
    new_price decimal(10, 2) not null,
    change_date timestamp default current_timestamp,
    changed_by int,
    
    foreign key (id_instrument) references instrument(id),
    foreign key (changed_by) references users(id)
);


create table users (
    id serial primary key,
    u_name varchar(50) unique not null,
    u_password varchar(100) not null,
    u_role user_role default 'сотрудник' 
);

create table orders (
    id serial primary key,
    id_customer int not null,
    id_instrument int not null,
    id_user int not null,
    
    start_date timestamp not null default current_timestamp,
    count_days int not null check (count_days > 0),
    finish_date timestamp,
    full_price decimal(10, 2),
    discount decimal(10, 2) default 0,
    discounted_price decimal(10, 2),
    status order_status default 'неоплачено',
    o_more varchar(256) default '-',
    
    foreign key (id_customer) references customer(id),
    foreign key (id_instrument) references instrument(id),
    foreign key (id_user) references users(id)
);