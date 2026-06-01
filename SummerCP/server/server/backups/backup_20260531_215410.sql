--
-- PostgreSQL database dump
--

\restrict HhLEzUeVpaLu1OrM8ynpssId7kDruKyAiXdAgFhJaRc5AxVYFFcbklQU82NpoJ8

-- Dumped from database version 18.0 (Postgres.app)
-- Dumped by pg_dump version 18.0 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: summer_cp; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA summer_cp;


ALTER SCHEMA summer_cp OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA summer_cp;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: order_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.order_status AS ENUM (
    'неоплачено',
    'оплачено',
    'возвращено',
    'невозвращено'
);


ALTER TYPE public.order_status OWNER TO postgres;

--
-- Name: instrument_status; Type: TYPE; Schema: summer_cp; Owner: postgres
--

CREATE TYPE summer_cp.instrument_status AS ENUM (
    'доступен',
    'недоступен'
);


ALTER TYPE summer_cp.instrument_status OWNER TO postgres;

--
-- Name: instrument_visibility; Type: TYPE; Schema: summer_cp; Owner: postgres
--

CREATE TYPE summer_cp.instrument_visibility AS ENUM (
    'Показать',
    'Убрать'
);


ALTER TYPE summer_cp.instrument_visibility OWNER TO postgres;

--
-- Name: order_status; Type: TYPE; Schema: summer_cp; Owner: postgres
--

CREATE TYPE summer_cp.order_status AS ENUM (
    'неоплачено',
    'оплачено',
    'возвращено',
    'невозвращено'
);


ALTER TYPE summer_cp.order_status OWNER TO postgres;

--
-- Name: user_role; Type: TYPE; Schema: summer_cp; Owner: postgres
--

CREATE TYPE summer_cp.user_role AS ENUM (
    'сотрудник',
    'старший сотрудник',
    'администратор'
);


ALTER TYPE summer_cp.user_role OWNER TO postgres;

--
-- Name: calculate_full_price(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_full_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    base_price decimal;
begin
    select price into base_price from instrument where id = new.id_instrument;
    new.full_price := base_price * new.count_days;
    
    if new.discount is null then
        new.discount := 0;
    end if;
    
    new.discounted_price := new.full_price * (1 - new.discount / 100);
    
    return new;
end;
$$;


ALTER FUNCTION public.calculate_full_price() OWNER TO postgres;

--
-- Name: calculate_finish_date(); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.calculate_finish_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    new.finish_date := new.start_date + (new.count_days || ' days')::interval;
    return new;
end;
$$;


ALTER FUNCTION summer_cp.calculate_finish_date() OWNER TO postgres;

--
-- Name: calculate_full_price(); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.calculate_full_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    base_price DECIMAL;
BEGIN
    SELECT price INTO base_price FROM instrument WHERE id = NEW.id_instrument;
    
    NEW.full_price := base_price * NEW.count_days;
    
    IF NEW.discount IS NULL THEN
        NEW.discount := 0;
    END IF;
    
    NEW.discounted_price := NEW.full_price * (1 - NEW.discount / 100);
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION summer_cp.calculate_full_price() OWNER TO postgres;

--
-- Name: current_user_id(); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.current_user_id() RETURNS integer
    LANGUAGE plpgsql
    AS $$
begin
    return null; -- Будет устанавливаться через параметры сессии
end;
$$;


ALTER FUNCTION summer_cp.current_user_id() OWNER TO postgres;

--
-- Name: decrypt_data(bytea); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.decrypt_data(data bytea) RETURNS text
    LANGUAGE plpgsql
    AS $$
begin
    if data is null then
        return null;
    end if;
    return convert_from(
        decrypt(data, digest('my_super_secret_key_2024', 'sha256'), 'aes-cbc/pad:pkcs'),
        'utf8'
    );
end;
$$;


ALTER FUNCTION summer_cp.decrypt_data(data bytea) OWNER TO postgres;

--
-- Name: encrypt_data(text); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.encrypt_data(data text) RETURNS bytea
    LANGUAGE plpgsql
    AS $$
begin
    if data is null or data = '' then
        return null;
    end if;
    return encrypt(
        convert_to(data, 'utf8'),
        digest('my_super_secret_key_2024', 'sha256'),
        'aes-cbc/pad:pkcs'
    );
end;
$$;


ALTER FUNCTION summer_cp.encrypt_data(data text) OWNER TO postgres;

--
-- Name: encrypt_passport_trigger(); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.encrypt_passport_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if new.p_number is not null and pg_typeof(new.p_number) = 'text'::regtype then
        new.p_number := encrypt_data(new.p_number);
    end if;
    if new.p_home is not null and pg_typeof(new.p_home) = 'text'::regtype then
        new.p_home := encrypt_data(new.p_home);
    end if;
    return new;
end;
$$;


ALTER FUNCTION summer_cp.encrypt_passport_trigger() OWNER TO postgres;

--
-- Name: log_price_change(); Type: FUNCTION; Schema: summer_cp; Owner: postgres
--

CREATE FUNCTION summer_cp.log_price_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if old.price != new.price then
        insert into price_history (id_instrument, old_price, new_price, changed_by)
        values (new.id, old.price, new.price, current_user_id());
    end if;
    return new;
end;
$$;


ALTER FUNCTION summer_cp.log_price_change() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: customer; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.customer (
    id integer NOT NULL,
    id_passport integer NOT NULL,
    f_name character varying(50) NOT NULL,
    l_name character varying(50) NOT NULL,
    v_name character varying(50),
    phone character varying(20) NOT NULL
);


ALTER TABLE summer_cp.customer OWNER TO postgres;

--
-- Name: customer_id_seq; Type: SEQUENCE; Schema: summer_cp; Owner: postgres
--

CREATE SEQUENCE summer_cp.customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE summer_cp.customer_id_seq OWNER TO postgres;

--
-- Name: customer_id_seq; Type: SEQUENCE OWNED BY; Schema: summer_cp; Owner: postgres
--

ALTER SEQUENCE summer_cp.customer_id_seq OWNED BY summer_cp.customer.id;


--
-- Name: passport; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.passport (
    id integer NOT NULL,
    p_number bytea,
    p_home bytea
);


ALTER TABLE summer_cp.passport OWNER TO postgres;

--
-- Name: customers_with_passport; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.customers_with_passport AS
 SELECT c.id,
    c.l_name,
    c.f_name,
    c.v_name,
    c.phone,
    summer_cp.decrypt_data(p.p_number) AS passport_number,
    summer_cp.decrypt_data(p.p_home) AS passport_home
   FROM (summer_cp.customer c
     JOIN summer_cp.passport p ON ((c.id_passport = p.id)));


ALTER VIEW summer_cp.customers_with_passport OWNER TO postgres;

--
-- Name: instrument; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.instrument (
    id integer NOT NULL,
    i_name character varying(100) NOT NULL,
    i_category character varying(50),
    price numeric(10,2) NOT NULL,
    i_more character varying(256) DEFAULT '-'::character varying,
    i_status summer_cp.instrument_status DEFAULT 'доступен'::summer_cp.instrument_status
);


ALTER TABLE summer_cp.instrument OWNER TO postgres;

--
-- Name: orders; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.orders (
    id integer NOT NULL,
    id_customer integer NOT NULL,
    id_instrument integer NOT NULL,
    id_user integer NOT NULL,
    start_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    count_days integer NOT NULL,
    finish_date timestamp without time zone,
    full_price numeric(10,2),
    discount numeric(10,2) DEFAULT 0,
    discounted_price numeric(10,2),
    status summer_cp.order_status DEFAULT 'неоплачено'::summer_cp.order_status,
    o_more character varying(256) DEFAULT '-'::character varying,
    CONSTRAINT orders_count_days_check CHECK ((count_days > 0))
);


ALTER TABLE summer_cp.orders OWNER TO postgres;

--
-- Name: dashboard_stats; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.dashboard_stats AS
 SELECT ( SELECT count(*) AS count
           FROM summer_cp.orders
          WHERE (orders.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status]))) AS total_orders,
    ( SELECT count(*) AS count
           FROM summer_cp.orders
          WHERE (orders.status = 'возвращено'::summer_cp.order_status)) AS returned_orders,
    ( SELECT count(*) AS count
           FROM summer_cp.orders
          WHERE (orders.status = 'неоплачено'::summer_cp.order_status)) AS unpaid_orders,
    ( SELECT count(*) AS count
           FROM summer_cp.orders
          WHERE (orders.status = 'оплачено'::summer_cp.order_status)) AS paid_orders,
    ( SELECT count(*) AS count
           FROM summer_cp.customer) AS total_customers,
    ( SELECT count(*) AS count
           FROM summer_cp.instrument) AS total_instruments,
    ( SELECT sum(orders.full_price) AS sum
           FROM summer_cp.orders
          WHERE (orders.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status]))) AS total_revenue,
    ( SELECT avg(orders.full_price) AS avg
           FROM summer_cp.orders
          WHERE (orders.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status]))) AS avg_order_value;


ALTER VIEW summer_cp.dashboard_stats OWNER TO postgres;

--
-- Name: instrument_id_seq; Type: SEQUENCE; Schema: summer_cp; Owner: postgres
--

CREATE SEQUENCE summer_cp.instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE summer_cp.instrument_id_seq OWNER TO postgres;

--
-- Name: instrument_id_seq; Type: SEQUENCE OWNED BY; Schema: summer_cp; Owner: postgres
--

ALTER SEQUENCE summer_cp.instrument_id_seq OWNED BY summer_cp.instrument.id;


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: summer_cp; Owner: postgres
--

CREATE SEQUENCE summer_cp.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE summer_cp.orders_id_seq OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: summer_cp; Owner: postgres
--

ALTER SEQUENCE summer_cp.orders_id_seq OWNED BY summer_cp.orders.id;


--
-- Name: passport_decrypted; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.passport_decrypted AS
 SELECT id,
    summer_cp.decrypt_data(p_number) AS p_number,
    summer_cp.decrypt_data(p_home) AS p_home
   FROM summer_cp.passport;


ALTER VIEW summer_cp.passport_decrypted OWNER TO postgres;

--
-- Name: passport_id_seq; Type: SEQUENCE; Schema: summer_cp; Owner: postgres
--

CREATE SEQUENCE summer_cp.passport_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE summer_cp.passport_id_seq OWNER TO postgres;

--
-- Name: passport_id_seq; Type: SEQUENCE OWNED BY; Schema: summer_cp; Owner: postgres
--

ALTER SEQUENCE summer_cp.passport_id_seq OWNED BY summer_cp.passport.id;


--
-- Name: price_history; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.price_history (
    id integer NOT NULL,
    id_instrument integer NOT NULL,
    old_price numeric(10,2) NOT NULL,
    new_price numeric(10,2) NOT NULL,
    change_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    changed_by integer
);


ALTER TABLE summer_cp.price_history OWNER TO postgres;

--
-- Name: price_history_id_seq; Type: SEQUENCE; Schema: summer_cp; Owner: postgres
--

CREATE SEQUENCE summer_cp.price_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE summer_cp.price_history_id_seq OWNER TO postgres;

--
-- Name: price_history_id_seq; Type: SEQUENCE OWNED BY; Schema: summer_cp; Owner: postgres
--

ALTER SEQUENCE summer_cp.price_history_id_seq OWNED BY summer_cp.price_history.id;


--
-- Name: top_customers_all; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_all AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.full_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_all OWNER TO postgres;

--
-- Name: top_customers_half_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_half_year AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone) - '6 mons'::interval)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.full_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_half_year OWNER TO postgres;

--
-- Name: top_customers_month; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_month AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (date_trunc('month'::text, o.start_date) = date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.full_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_month OWNER TO postgres;

--
-- Name: top_customers_quarter; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_quarter AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (date_trunc('quarter'::text, o.start_date) = date_trunc('quarter'::text, (CURRENT_DATE)::timestamp with time zone)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.full_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_quarter OWNER TO postgres;

--
-- Name: top_customers_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_year AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (EXTRACT(year FROM o.start_date) = EXTRACT(year FROM CURRENT_DATE)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.full_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_year OWNER TO postgres;

--
-- Name: top_instruments_all; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_instruments_all AS
 SELECT i.id,
    i.i_name,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])))))
  GROUP BY i.id, i.i_name
  ORDER BY (count(o.id)) DESC;


ALTER VIEW summer_cp.top_instruments_all OWNER TO postgres;

--
-- Name: top_instruments_half_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_instruments_half_year AS
 SELECT i.id,
    i.i_name,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone) - '6 mons'::interval)))))
  GROUP BY i.id, i.i_name
  ORDER BY (count(o.id)) DESC;


ALTER VIEW summer_cp.top_instruments_half_year OWNER TO postgres;

--
-- Name: top_instruments_month; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_instruments_month AS
 SELECT i.id,
    i.i_name,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (date_trunc('month'::text, o.start_date) = date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)))))
  GROUP BY i.id, i.i_name
  ORDER BY (count(o.id)) DESC;


ALTER VIEW summer_cp.top_instruments_month OWNER TO postgres;

--
-- Name: top_instruments_quarter; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_instruments_quarter AS
 SELECT i.id,
    i.i_name,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (date_trunc('quarter'::text, o.start_date) = date_trunc('quarter'::text, (CURRENT_DATE)::timestamp with time zone)))))
  GROUP BY i.id, i.i_name
  ORDER BY (count(o.id)) DESC;


ALTER VIEW summer_cp.top_instruments_quarter OWNER TO postgres;

--
-- Name: top_instruments_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_instruments_year AS
 SELECT i.id,
    i.i_name,
    count(o.id) AS rental_count,
    COALESCE(sum(o.full_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (EXTRACT(year FROM o.start_date) = EXTRACT(year FROM CURRENT_DATE)))))
  GROUP BY i.id, i.i_name
  ORDER BY (count(o.id)) DESC;


ALTER VIEW summer_cp.top_instruments_year OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.users (
    id integer NOT NULL,
    u_name character varying(50) NOT NULL,
    u_password character varying(100) NOT NULL,
    u_role summer_cp.user_role DEFAULT 'сотрудник'::summer_cp.user_role
);


ALTER TABLE summer_cp.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: summer_cp; Owner: postgres
--

CREATE SEQUENCE summer_cp.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE summer_cp.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: summer_cp; Owner: postgres
--

ALTER SEQUENCE summer_cp.users_id_seq OWNED BY summer_cp.users.id;


--
-- Name: customer id; Type: DEFAULT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.customer ALTER COLUMN id SET DEFAULT nextval('summer_cp.customer_id_seq'::regclass);


--
-- Name: instrument id; Type: DEFAULT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.instrument ALTER COLUMN id SET DEFAULT nextval('summer_cp.instrument_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.orders ALTER COLUMN id SET DEFAULT nextval('summer_cp.orders_id_seq'::regclass);


--
-- Name: passport id; Type: DEFAULT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.passport ALTER COLUMN id SET DEFAULT nextval('summer_cp.passport_id_seq'::regclass);


--
-- Name: price_history id; Type: DEFAULT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.price_history ALTER COLUMN id SET DEFAULT nextval('summer_cp.price_history_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.users ALTER COLUMN id SET DEFAULT nextval('summer_cp.users_id_seq'::regclass);


--
-- Data for Name: customer; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.customer (id, id_passport, f_name, l_name, v_name, phone) FROM stdin;
1	1	Алексей	Иванов	Дмитриевич	+79010000001
2	2	Мария	Иванова	Сергеевна	+79010000002
3	3	Дмитрий	Иванов	Александрович	+79010000003
4	4	Елена	Иванова	Владимировна	+79010000004
5	5	Сергей	Иванов	Петрович	+79010000005
6	6	Анна	Петрова	Игоревна	+79010000006
7	7	Владимир	Петров	Николаевич	+79010000007
8	8	Татьяна	Петрова	Андреевна	+79010000008
9	9	Игорь	Петров	Васильевич	+79010000009
10	10	Ольга	Петрова	Михайловна	+79010000010
11	11	Николай	Сидоров	Алексеевич	+79010000011
12	12	Светлана	Сидорова	Евгеньевна	+79010000012
13	13	Константин	Сидоров	Юрьевич	+79010000013
14	14	Наталья	Сидорова	Викторовна	+79010000014
15	15	Михаил	Сидоров	Андреевич	+79010000015
16	16	Юлия	Смирнова	Дмитриевна	+79010000016
17	17	Роман	Смирнов	Константинович	+79010000017
18	18	Ирина	Смирнова	Вячеславовна	+79010000018
19	19	Григорий	Смирнов	Иванович	+79010000019
20	20	Екатерина	Смирнова	Павловна	+79010000020
21	21	Василий	Кузнецов	Георгиевич	+79010000021
22	22	Анастасия	Кузнецова	Александровна	+79010000022
23	23	Петр	Кузнецов	Сергеевич	+79010000023
24	24	Ксения	Кузнецова	Ильинична	+79010000024
25	25	Станислав	Кузнецов	Валерьевич	+79010000025
26	26	Валентина	Волкова	Анатольевна	+79010000026
27	27	Артем	Волков	Романович	+79010000027
28	28	Лидия	Волкова	Сергеевна	+79010000028
29	29	Евгений	Волков	Максимович	+79010000029
30	30	Зоя	Волкова	Борисовна	+79010000030
31	31	Павел	Морозов	Дмитриевич	+79010000031
32	32	Дарья	Морозова	Алексеевна	+79010000032
33	33	Тимофей	Морозов	Иванович	+79010000033
34	34	Вера	Морозова	Петровна	+79010000034
35	35	Максим	Морозов	Андреевич	+79010000035
36	36	Надежда	Новикова	Владимировна	+79010000036
37	37	Илья	Новиков	Егорович	+79010000037
38	38	Любовь	Новикова	Степановна	+79010000038
39	39	Данила	Новиков	Константинович	+79010000039
40	40	Алина	Новикова	Юрьевна	+79010000040
41	41	Виталий	Козлов	Геннадьевич	+79010000041
42	42	Кристина	Козлова	Даниловна	+79010000042
43	43	Захар	Козлов	Леонидович	+79010000043
44	44	Регина	Козлова	Руслановна	+79010000044
45	45	Андрей	Козлов	Антонович	+79010000045
46	46	Эдуард	Лебедев	Олегович	+79010000046
47	47	Таисия	Лебедева	Кирилловна	+79010000047
48	48	Филипп	Лебедев	Станиславович	+79010000048
49	49	Маргарита	Лебедева	Витальевна	+79010000049
50	50	Родион	Лебедев	Артемович	+79010000050
51	51	Лариса	Егорова	Вячеславовна	+79010000051
52	52	Олег	Егоров	Федорович	+79010000052
53	53	Алла	Егорова	Михайловна	+79010000053
54	54	Елисей	Егоров	Игнатьевич	+79010000054
55	55	Жанна	Егорова	Романовна	+79010000055
56	56	Глеб	Васильев	Никитич	+79010000056
57	57	Фаина	Васильева	Аркадьевна	+79010000057
58	58	Клим	Васильев	Максимович	+79010000058
59	59	Эльвира	Васильева	Тимофеевна	+79010000059
60	60	Арсений	Васильев	Платонович	+79010000060
61	61	Ярослав	Зайцев	Борисович	+79010000061
62	62	Влада	Зайцева	Макаровна	+79010000062
63	63	Семен	Зайцев	Анатольевич	+79010000063
64	64	Лада	Зайцева	Евгеньевна	+79010000064
65	65	Остап	Зайцев	Иосифович	+79010000065
66	66	Галина	Фролова	Семеновна	+79010000066
67	67	Валерий	Фролов	Валерьянович	+79010000067
68	68	Иветта	Фролова	Эдуардовна	+79010000068
69	69	Еремей	Фролов	Пантелеймонович	+79010000069
70	70	Нина	Фролова	Гавриловна	+79010000070
71	71	Платон	Денисов	Акимович	+79010000071
72	72	Софья	Денисова	Данииловна	+79010000072
73	73	Мирон	Денисов	Святославович	+79010000073
74	74	Ульяна	Денисова	Матвеевна	+79010000074
75	75	Ростислав	Денисов	Германович	+79010000075
76	76	Ева	Григорьева	Тимуровна	+79010000076
77	77	Богдан	Григорьев	Арсенович	+79010000077
78	78	Милена	Григорьева	Давыдовна	+79010000078
79	79	Лука	Григорьев	Эльдарович	+79010000079
80	80	Варвара	Григорьева	Робертовна	+79010000080
81	81	Гордей	Степанов	Альбертович	+79010000081
82	82	Нелли	Степанова	Владиславовна	+79010000082
83	83	Савелий	Степанов	Иннокентьевич	+79010000083
84	84	Агата	Степанова	Феликсовна	+79010000084
85	85	Лев	Степанов	Артурович	+79010000085
86	86	Агафья	Николаева	Марковна	+79010000086
87	87	Федор	Николаев	Демидович	+79010000087
88	88	Бронислава	Николаева	Кондратьевна	+79010000088
89	89	Ермолай	Николаев	Ефимович	+79010000089
90	90	Ада	Николаева	Карповна	+79010000090
91	91	Казимир	Андреев	Венедиктович	+79010000091
92	92	Ванда	Андреева	Мирославовна	+79010000092
93	93	Макар	Андреев	Самсонович	+79010000093
94	94	Нона	Андреева	Тарасовна	+79010000094
95	95	Всеволод	Андреев	Харитонович	+79010000095
96	96	Оксана	Макарова	Яковлевна	+79010000096
97	97	Кузьма	Макаров	Елизарович	+79010000097
98	98	Юна	Макарова	Федотовна	+79010000098
99	99	Всемил	Макаров	Глебович	+79010000099
100	100	Яна	Макарова	Александровна	+79010000100
\.


--
-- Data for Name: instrument; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.instrument (id, i_name, i_category, price, i_more, i_status) FROM stdin;
1	НОЖНИЦЫ ПО МЕТАЛЛУ МАКИТА JN 1601	режущий инструмент	500.00	-	доступен
3	ОТБОЙНЫЙ МОЛОТОК (для копки колодца)	строительный инструмент	1200.00	-	доступен
4	ПОЛИРОВАЛЬНАЯ МАШИНКА	электроинструмент	400.00	-	доступен
5	ПРЕСС КЛЕЩИ	инструмент	500.00	-	доступен
6	ПРИЦЕП ЛЕГКОВОЙ 1.8x1.2 500 кг	транспорт	800.00	-	доступен
7	ПИЛА ЦЕПНАЯ ЭЛЕКТРИЧЕСКАЯ	электроинструмент	800.00	-	доступен
8	ПЛИТКОРЕЗ РУЧНОЙ (400 мм)	ручной инструмент	400.00	-	доступен
9	ПУШКА ГАЗОВАЯ 15; 30; 60кВт 330 м3	тепловое оборудование	400.00	-	доступен
10	ПУШКА ДИЗЕЛЬ 20 КВт	тепловое оборудование	1000.00	-	доступен
11	ПУШКА ЭЛЕКТРИЧЕСКАЯ 3 кВт	тепловое оборудование	300.00	-	доступен
12	РЕНОВАТОР	электроинструмент	400.00	-	доступен
13	ПЕРФОРАТОР АККУМУЛЯТОРНЫЙ	электроинструмент	700.00	-	доступен
14	ПЕРФОРАТОР "МАКИТА" 5201	электроинструмент	1700.00	-	доступен
15	ПЕРФОРАТОР MAKITA HR 4011 12Д SDS max	электроинструмент	1400.00	-	доступен
16	ПЕРФОРАТОР Вихрь SDS max	электроинструмент	1000.00	-	доступен
17	ПЕРФОРАТОР SDS plus	электроинструмент	500.00	-	доступен
18	ПЫЛЕСОС KARCHER 361, мешок для пыли	уборочная техника	800.00	-	доступен
19	ПЫЛЕСОС МОЮЩИЙ	уборочная техника	800.00	-	доступен
20	СВАРОЧНИК ДЛЯ ПВХ 2000 Вт	сварочное оборудование	400.00	-	доступен
21	СВАРОЧНЫЙ АППАРАТ РЕСАНТА 160 ПН	сварочное оборудование	600.00	-	доступен
22	СВАРОЧНИК ПОЛУАВТОМАТ	сварочное оборудование	1000.00	-	доступен
23	ТАЛЬ ЦЕПНАЯ 2 тонны 3 метра	грузоподъемное оборудование	500.00	-	доступен
24	ТАЧКА СТРОИТЕЛЬНАЯ	строительный инвентарь	500.00	-	доступен
25	ТОРЦОВОЧНАЯ ПИЛА МЕТАВО KGS 305M	электроинструмент	800.00	-	доступен
26	ТРЕНОГА для колодезных колец	оборудование	700.00	-	доступен
27	ТРЕНОГА для копки колодцев	оборудование	500.00	-	доступен
28	ТРИМЕР	садовый инструмент	1400.00	-	доступен
29	УДЛИНИТЕЛЬ СЕТЕВОЙ 3X1.5	электрооборудование	300.00	-	доступен
30	УРОВЕНЬ ЛАЗЕРНЫЙ 3D	измерительный инструмент	500.00	-	доступен
31	ЦИРКУЛЯРНАЯ ПИЛА	электроинструмент	600.00	-	доступен
32	ШТРОБОРЕЗ Диск 125 (кирпич) Диск 150 (бетон)	строительный инструмент	1000.00	-	доступен
33	ШЛИФМАШИНКА энцентрик, ленточная, квадрат	электроинструмент	400.00	-	доступен
34	ШЛИФОВАЛЬНЫЙ ЖИРАФ (стены, потолок)	электроинструмент	1200.00	-	доступен
35	ШУРУПОВЕРТ	электроинструмент	500.00	-	доступен
36	ФЕН 2000Вт	электроинструмент	300.00	-	доступен
37	АРМАТУРОГИБ 16мм	строительный инструмент	500.00	-	доступен
38	БЕНЗОРЕЗ STIHL 420 (диск отдельно)	бензоинструмент	3500.00	-	доступен
39	БЕНЗОПИЛА STIHL 180, шина 40 см.	бензоинструмент	1500.00	-	доступен
40	БЕТОНМЕШАЛКА 160 литров	строительное оборудование	800.00	-	доступен
41	БЕТОНОЛОМ (ассортимент)	строительный инструмент	1200.00	-	доступен
42	БОЛГАРКА диск 230	электроинструмент	800.00	-	доступен
43	БОЛГАРКА диск 125	электроинструмент	500.00	-	доступен
44	БОЛГАРКА АККУМУЛЯТОРНАЯ 18ВТ 2 ак6 х 5Амп/Час	электроинструмент	600.00	-	доступен
45	ВОЗДУХОДУВКА STIHL BR 600	садовый инструмент	1500.00	-	доступен
46	ВИБРАТОР ГЛУБИННЫЙ 1.5 метра	строительный инструмент	700.00	-	доступен
47	ВИБРОПЛИТА 100кг	строительное оборудование	1500.00	-	доступен
48	ВИБРОПЛИТА 55 кг	строительное оборудование	1200.00	-	доступен
49	ВЫШКА ТУРА от 1.4 до 10.0 метров	строительное оборудование	500.00	от 500 - цена зависит от высоты	доступен
50	ГАЗОВОЙ БАЛЛОН 12-27-50 литров	газовое оборудование	250.00	-	доступен
51	ГАЗОВАЯ ГОРЕЛКА	газовое оборудование	500.00	-	доступен
52	ГАЙКОВЕРТ аккумуляторный	электроинструмент	700.00	-	доступен
53	ГЕНЕРАТОР DDE GG 3300P пускавая мощность 7 Кв	генераторы	800.00	-	доступен
54	ГЕНЕРАТОР DDE GG 5500P пускавая мощность 9 Кв	генераторы	1400.00	-	доступен
55	ДОМКРАТ (бутылочный, стакан) 32 12 тонн	грузоподъемное оборудование	500.00	-	доступен
56	ДРЕЛЬ МАЛООБОРОТИСТАЯ 1050 Вт	электроинструмент	500.00	-	доступен
57	ЗАХВАТ КЛЕЩИ (для поребриков, бордюров) 2 шт	инструмент	500.00	-	доступен
58	ИЗМЕЛЬЧИТЕЛЬ ВЕТОК	садовый инструмент	1800.00	-	доступен
59	КЛЕЩИ обжимные для проводов ср2; ср4	электроинструмент	400.00	-	доступен
60	КЛУПП РУЧНОЙ	слесарный инструмент	400.00	-	доступен
61	КЛЮЧ РАЗВОДНОЙ 100мм	слесарный инструмент	250.00	-	доступен
62	КОМПРЕССОР МЕТАВО 110 л/м	компрессорное оборудование	800.00	-	доступен
2	ОСУШИТЕЛЬ ВОЗДУХА	оборудование	700.00	-	доступен
63	КОМПРЕССОР 400 л/м	компрессорное оборудование	1200.00	-	доступен
64	КАТОК САДОВЫЙ 62 литра	садовый инструмент	700.00	-	доступен
65	ЛОБЗИК АККУМУЛЯТОРНЫЙ BOSCH 18V 4,0 Ah	электроинструмент	700.00	-	доступен
66	ЛОБЗИК МАКИТА 750Вт	электроинструмент	500.00	-	доступен
67	ЛЕБЕТКА РЫЧАЖНАЯ 4 тонны 3 метра	грузоподъемное оборудование	500.00	-	доступен
68	ЛЕСТНИЦА 3х12 8.5 метров ТРАНСФОРМЕР 4,8 метра	оборудование	500.00	-	доступен
69	МИКСЕР СТРОИТЕЛЬНЫЙ	строительный инструмент	600.00	-	доступен
70	МОТОБУР на двух операторов шнек 250мм	бензоинструмент	1800.00	-	доступен
71	МОТОБУР ЧЕМПИОН AG252	бензоинструмент	1400.00	-	доступен
72	МОТОКУЛЬТИВАТОР ХУСКВАРНА	садовая техника	1800.00	-	доступен
73	НАСОС фекальный 12м/330л/м дренажный 17м/350	насосное оборудование	800.00	-	доступен
74	НАСОС ФЕКАЛЬНЫЙ напор 8м 230л/час размер частиц 25	насосное оборудование	600.00	-	доступен
75	НАСОС Мощный напор 14 м 550 л/м	насосное оборудование	1200.00	-	доступен
77	НЕЙЛЕР ПНЕВМАТИЧЕСКИЙ ГВОЗДЕЗАБИВНОЙ 50мм	пневмоинструмент	500.00	-	недоступен
76	НИВЕЛИР ОПТИЧЕСКИЙ	измерительный инструмент	800.00	-	недоступен
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.orders (id, id_customer, id_instrument, id_user, start_date, count_days, finish_date, full_price, discount, discounted_price, status, o_more) FROM stdin;
101	31	35	1	2026-05-31 01:50:57.832881	3	2026-06-03 01:50:57.832881	1500.00	20.00	1200.00	возвращено	-
102	1	1	1	2026-05-31 21:35:57.525704	1	2026-06-01 21:35:57.525704	500.00	0.00	500.00	неоплачено	-
2	2	2	1	2025-05-02 11:30:00	5	2025-05-07 11:30:00	3500.00	0.00	3500.00	возвращено	-
89	89	11	1	2025-07-28 10:00:00	1	2025-07-29 10:00:00	300.00	0.00	300.00	возвращено	-
96	96	18	1	2025-08-04 10:15:00	1	2025-08-05 10:15:00	800.00	0.00	800.00	возвращено	-
97	97	19	1	2025-08-05 15:30:00	4	2025-08-09 15:30:00	3200.00	0.00	3200.00	возвращено	-
92	92	14	1	2025-07-31 11:00:00	2	2025-08-02 11:00:00	3400.00	0.00	3400.00	возвращено	-
4	4	4	1	2025-05-04 14:00:00	7	2025-05-11 14:00:00	2800.00	0.00	2800.00	возвращено	-
60	60	60	1	2025-06-29 12:00:00	7	2025-07-06 12:00:00	2800.00	0.00	2800.00	возвращено	-
95	95	17	1	2025-08-03 12:45:00	7	2025-08-10 12:45:00	3500.00	0.00	3500.00	возвращено	-
10	10	10	1	2025-05-10 11:00:00	8	2025-05-18 11:00:00	8000.00	0.00	8000.00	возвращено	-
1	1	1	1	2025-05-01 10:00:00	3	2025-05-04 10:00:00	1500.00	0.00	1500.00	возвращено	-
12	12	12	1	2025-05-12 10:00:00	3	2025-05-15 10:00:00	1200.00	0.00	1200.00	возвращено	-
3	3	3	1	2025-05-03 09:15:00	2	2025-05-05 09:15:00	2400.00	0.00	2400.00	возвращено	-
5	5	5	1	2025-05-05 16:20:00	1	2025-05-06 16:20:00	500.00	0.00	500.00	возвращено	-
8	8	8	1	2025-05-08 09:30:00	3	2025-05-11 09:30:00	1200.00	0.00	1200.00	возвращено	-
11	11	11	1	2025-05-11 13:30:00	5	2025-05-16 13:30:00	1500.00	0.00	1500.00	возвращено	-
15	15	15	1	2025-05-15 16:00:00	2	2025-05-17 16:00:00	2800.00	0.00	2800.00	возвращено	-
17	17	17	1	2025-05-17 10:30:00	1	2025-05-18 10:30:00	500.00	0.00	500.00	возвращено	-
20	20	20	1	2025-05-20 15:30:00	4	2025-05-24 15:30:00	1600.00	0.00	1600.00	возвращено	-
23	23	23	1	2025-05-23 11:45:00	5	2025-05-28 11:45:00	2500.00	0.00	2500.00	возвращено	-
26	26	26	1	2025-05-26 16:30:00	1	2025-05-27 16:30:00	700.00	0.00	700.00	возвращено	-
29	29	29	1	2025-05-29 13:30:00	2	2025-05-31 13:30:00	600.00	0.00	600.00	возвращено	-
32	32	32	1	2025-06-01 10:00:00	7	2025-06-08 10:00:00	7000.00	0.00	7000.00	возвращено	-
35	35	35	1	2025-06-04 12:45:00	6	2025-06-10 12:45:00	3000.00	0.00	3000.00	возвращено	-
38	38	38	1	2025-06-07 10:15:00	3	2025-06-10 10:15:00	10500.00	0.00	10500.00	возвращено	-
41	41	41	1	2025-06-10 14:00:00	4	2025-06-14 14:00:00	4800.00	0.00	4800.00	возвращено	-
44	44	44	1	2025-06-13 15:30:00	5	2025-06-18 15:30:00	3000.00	0.00	3000.00	возвращено	-
47	47	47	1	2025-06-16 09:00:00	1	2025-06-17 09:00:00	1500.00	0.00	1500.00	возвращено	-
50	50	50	1	2025-06-19 10:00:00	2	2025-06-21 10:00:00	500.00	0.00	500.00	возвращено	-
53	53	53	1	2025-06-22 09:30:00	7	2025-06-29 09:30:00	5600.00	0.00	5600.00	возвращено	-
56	56	56	1	2025-06-25 15:15:00	6	2025-07-01 15:15:00	3000.00	0.00	3000.00	возвращено	-
59	59	59	1	2025-06-28 09:15:00	3	2025-07-01 09:15:00	1200.00	0.00	1200.00	возвращено	-
62	62	62	1	2025-07-01 10:30:00	4	2025-07-05 10:30:00	3200.00	0.00	3200.00	возвращено	-
65	65	65	1	2025-07-04 09:00:00	5	2025-07-09 09:00:00	3500.00	0.00	3500.00	возвращено	-
98	98	20	1	2025-08-06 13:00:00	6	2025-08-12 13:00:00	2400.00	0.00	2400.00	возвращено	-
90	90	12	1	2025-07-29 16:00:00	4	2025-08-02 16:00:00	1600.00	0.00	1600.00	возвращено	-
94	94	16	1	2025-08-02 14:15:00	3	2025-08-05 14:15:00	3000.00	0.00	3000.00	возвращено	-
100	100	22	1	2025-08-08 09:00:00	5	2025-08-13 09:00:00	5000.00	20.00	4000.00	возвращено	-
7	7	7	1	2025-05-07 12:00:00	6	2025-05-13 12:00:00	4800.00	0.00	4800.00	возвращено	-
14	14	14	1	2025-05-14 14:30:00	6	2025-05-20 14:30:00	10200.00	0.00	10200.00	возвращено	-
16	16	16	1	2025-05-16 11:15:00	7	2025-05-23 11:15:00	7000.00	0.00	7000.00	возвращено	-
19	19	19	1	2025-05-19 09:00:00	3	2025-05-22 09:00:00	2400.00	0.00	2400.00	возвращено	-
21	21	21	1	2025-05-21 13:00:00	6	2025-05-27 13:00:00	3600.00	0.00	3600.00	возвращено	-
13	13	13	1	2025-05-13 09:45:00	4	2025-05-17 09:45:00	2800.00	0.00	2800.00	возвращено	-
18	18	18	1	2025-05-18 12:45:00	5	2025-05-23 12:45:00	4000.00	0.00	4000.00	возвращено	-
22	22	22	1	2025-05-22 10:15:00	2	2025-05-24 10:15:00	2000.00	0.00	2000.00	возвращено	-
63	63	63	1	2025-07-02 13:15:00	6	2025-07-08 13:15:00	7200.00	0.00	7200.00	возвращено	-
6	6	6	1	2025-05-06 10:45:00	4	2025-05-10 10:45:00	3200.00	0.00	3200.00	возвращено	-
9	9	9	1	2025-05-09 15:15:00	2	2025-05-11 15:15:00	800.00	0.00	800.00	возвращено	-
57	57	57	1	2025-06-26 10:45:00	2	2025-06-28 10:45:00	1000.00	0.00	1000.00	возвращено	-
91	91	13	1	2025-07-30 13:30:00	6	2025-08-05 13:30:00	4200.00	0.00	4200.00	возвращено	-
54	54	54	1	2025-06-23 13:00:00	1	2025-06-24 13:00:00	1400.00	0.00	1400.00	возвращено	-
51	51	51	1	2025-06-20 16:30:00	5	2025-06-25 16:30:00	2500.00	0.00	2500.00	возвращено	-
48	48	48	1	2025-06-17 11:30:00	4	2025-06-21 11:30:00	4800.00	0.00	4800.00	возвращено	-
45	45	45	1	2025-06-14 12:00:00	3	2025-06-17 12:00:00	4500.00	0.00	4500.00	возвращено	-
42	42	42	1	2025-06-11 11:15:00	6	2025-06-17 11:15:00	4800.00	0.00	4800.00	возвращено	-
39	39	39	1	2025-06-08 16:00:00	7	2025-06-15 16:00:00	10500.00	0.00	10500.00	возвращено	-
36	36	36	1	2025-06-05 11:30:00	2	2025-06-07 11:30:00	600.00	0.00	600.00	возвращено	-
33	33	33	1	2025-06-02 14:30:00	1	2025-06-03 14:30:00	400.00	0.00	400.00	возвращено	-
30	30	30	1	2025-05-30 11:00:00	5	2025-06-04 11:00:00	2500.00	0.00	2500.00	возвращено	-
27	27	27	1	2025-05-27 12:00:00	4	2025-05-31 12:00:00	2000.00	0.00	2000.00	возвращено	-
24	24	24	1	2025-05-24 14:15:00	3	2025-05-27 14:15:00	1500.00	0.00	1500.00	возвращено	-
64	64	64	1	2025-07-03 11:45:00	2	2025-07-05 11:45:00	1400.00	0.00	1400.00	возвращено	-
61	61	61	1	2025-06-30 16:00:00	1	2025-07-01 16:00:00	250.00	0.00	250.00	возвращено	-
58	58	58	1	2025-06-27 14:30:00	5	2025-07-02 14:30:00	9000.00	0.00	9000.00	возвращено	-
55	55	55	1	2025-06-24 11:00:00	4	2025-06-28 11:00:00	2000.00	0.00	2000.00	возвращено	-
52	52	52	1	2025-06-21 12:45:00	3	2025-06-24 12:45:00	2100.00	0.00	2100.00	возвращено	-
49	49	49	1	2025-06-18 14:15:00	6	2025-06-24 14:15:00	3000.00	0.00	3000.00	возвращено	-
46	46	46	1	2025-06-15 13:45:00	7	2025-06-22 13:45:00	4900.00	0.00	4900.00	возвращено	-
43	43	43	1	2025-06-12 10:30:00	2	2025-06-14 10:30:00	1000.00	0.00	1000.00	возвращено	-
40	40	40	1	2025-06-09 09:45:00	1	2025-06-10 09:45:00	800.00	0.00	800.00	возвращено	-
37	37	37	1	2025-06-06 13:00:00	5	2025-06-11 13:00:00	2500.00	0.00	2500.00	возвращено	-
34	34	34	1	2025-06-03 09:15:00	4	2025-06-07 09:15:00	4800.00	0.00	4800.00	возвращено	-
31	31	31	1	2025-05-31 15:00:00	3	2025-06-03 15:00:00	1800.00	0.00	1800.00	возвращено	-
28	28	28	1	2025-05-28 10:45:00	6	2025-06-03 10:45:00	8400.00	0.00	8400.00	возвращено	-
25	25	25	1	2025-05-25 09:30:00	7	2025-06-01 09:30:00	5600.00	0.00	5600.00	возвращено	-
93	93	15	1	2025-08-01 09:30:00	5	2025-08-06 09:30:00	7000.00	0.00	7000.00	возвращено	-
68	68	68	1	2025-07-07 10:00:00	1	2025-07-08 10:00:00	500.00	0.00	500.00	возвращено	-
71	71	71	1	2025-07-10 11:00:00	2	2025-07-12 11:00:00	2800.00	0.00	2800.00	возвращено	-
74	74	74	1	2025-07-13 12:30:00	7	2025-07-20 12:30:00	4200.00	0.00	4200.00	возвращено	-
77	77	77	1	2025-07-16 13:45:00	6	2025-07-22 13:45:00	3000.00	0.00	3000.00	возвращено	-
80	80	2	1	2025-07-19 14:30:00	3	2025-07-22 14:30:00	2100.00	0.00	2100.00	возвращено	-
83	83	5	1	2025-07-22 15:00:00	4	2025-07-26 15:00:00	2000.00	0.00	2000.00	возвращено	-
86	86	8	1	2025-07-25 09:15:00	5	2025-07-30 09:15:00	2000.00	0.00	2000.00	возвращено	-
81	81	3	1	2025-07-20 12:00:00	7	2025-07-27 12:00:00	8400.00	0.00	8400.00	возвращено	-
84	84	6	1	2025-07-23 13:15:00	6	2025-07-29 13:15:00	4800.00	0.00	4800.00	возвращено	-
87	87	9	1	2025-07-26 14:45:00	3	2025-07-29 14:45:00	1200.00	0.00	1200.00	возвращено	-
99	99	21	1	2025-08-07 11:45:00	2	2025-08-09 11:45:00	1200.00	0.00	1200.00	возвращено	-
82	82	4	1	2025-07-21 10:30:00	1	2025-07-22 10:30:00	400.00	0.00	400.00	возвращено	-
85	85	7	1	2025-07-24 11:30:00	2	2025-07-26 11:30:00	1600.00	0.00	1600.00	возвращено	-
88	88	10	1	2025-07-27 12:30:00	7	2025-08-03 12:30:00	7000.00	0.00	7000.00	возвращено	-
66	66	66	1	2025-07-05 14:30:00	3	2025-07-08 14:30:00	1500.00	0.00	1500.00	возвращено	-
78	78	77	1	2025-07-17 11:15:00	2	2025-07-19 11:15:00	1000.00	0.00	1000.00	возвращено	-
75	75	75	1	2025-07-14 10:15:00	1	2025-07-15 10:15:00	1200.00	0.00	1200.00	возвращено	-
72	72	72	1	2025-07-11 09:30:00	5	2025-07-16 09:30:00	9000.00	0.00	9000.00	возвращено	-
69	69	69	1	2025-07-08 15:45:00	4	2025-07-12 15:45:00	2400.00	0.00	2400.00	возвращено	-
79	79	1	1	2025-07-18 09:45:00	5	2025-07-23 09:45:00	2500.00	0.00	2500.00	возвращено	-
76	76	76	1	2025-07-15 16:15:00	4	2025-07-19 16:15:00	3200.00	0.00	3200.00	возвращено	-
73	73	73	1	2025-07-12 14:00:00	3	2025-07-15 14:00:00	2400.00	0.00	2400.00	возвращено	-
70	70	70	1	2025-07-09 13:30:00	6	2025-07-15 13:30:00	10800.00	0.00	10800.00	возвращено	-
67	67	67	1	2025-07-06 12:15:00	7	2025-07-13 12:15:00	3500.00	0.00	3500.00	возвращено	-
\.


--
-- Data for Name: passport; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.passport (id, p_number, p_home) FROM stdin;
1	\\x5f666456c513a20799025fc56adaa92f	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769ba2b0ea7391bf83dec127293c744edafe
2	\\x4d506dc3c0de305552e79b073a90929f	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769b1ebb44f30820c2e742eb1a3b46c73015
3	\\xc47556d9b4c35019b88ff88237e977d7	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769bf1aedf63951b88684d5dbdc89342c916
4	\\x5d719a072a329c5379163341f717b540	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769ba601168161ffbc7a3aa9c438d732cdcb
5	\\xf7d91a363763390e16fab3cf2e8cc3ef	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769bf039f572b9c1daa9893de18070cb46ad
6	\\x755798fd144f7a58e1fe6e864dcb97cb	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769bbec05f07223bd7b854f00e7a97d8fafa
7	\\x5a02afa9a5de75206ac28e49026277ed	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769bb0eaf7f49e521eb45f07911b18d99477
8	\\x02a0f239b261990d36c44024ef29fc0f	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769ba46d464570d42d2f8727b2d911cb5e63
9	\\x48634c3be3d1be8b491d1ed4aeabe769	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769bb7c51369f200ead123a03fa73eeec0f6
10	\\x53c2c188ce7be69d73a4acdeb9625e6b	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e05f5eb5446b593d76e041bc25d7623b1639ed23c4b14fd07b2f6aa53e0c3769bdd0ab577869da4c9ec38002ff69e43deabd7cde73544928a4f42d74e4a0afd28
11	\\x9e0825fb821151c55145ab3241b865f6	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948c51ead7ad00e32ef7613856353dc2e4cd
12	\\xc129dcf83fcd86a0e03612627d2bab3e	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948c555f974f0e02d95f9cc967efb37857c3
62	\\x79111b32648039b29b83aae44fdcd57d	\\xace1759e3268eb12a2c4dbc80bd998855219083f8e5b38488f3b677d8afd3dc71af9d8728b2315f0cdf0bd8c42d2346cdca11fb57ee4b27358258def2ad7789fb72d488b2d966a322d237245f7933a6e
13	\\x7333e019274c0da8ff59b9dd4c5a75d7	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948cfa24896ef278a3990d9ed20a3c9cbc82
14	\\xa84bd47f84adf813e03f360e8db2bcb3	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948ca9eaac9db2da1eb10cdfddffcb57da56
15	\\x2b06cd73f0b2015428457df999aad371	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948cb3e3af01d0362009c631afaf19219feb
16	\\x1950054e73b160db4a53a396d83eadeb	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948c28e70a834e1190de381e7a5ea55a2f2a
17	\\x02396e173c425aa28068d6eb9db80d96	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948c97d8cb8d464e006736077a3cc692c564
18	\\xd61fc9a5b3ef5400221bd16845257124	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948c12b0464289d689067d89dbb62294faf8
19	\\x96d7524287c596bff2658ef8b40f0d5e	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948c9762835295129efd7ec58728b565ce4a
20	\\x7acc3860e3039a4e5dae8f0636e054b0	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e6d33949675e65761ec5127e00f2fa75e650da7e4cb5317d61f9a276eae61dce627f3bc7f218e639ec64470dde61ed576a1ba87a71acd97c2295b41ef47d9948ce66687616b9ce10181927d7261d3c77b419efa7eedacb4ac14294e15fcefb9ec
21	\\x45a6d409d5cf9201482098e45f6a6b6f	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc3229593807e92d504edf2463892c11c6e7103
22	\\xe81254268d304b64017970e4ce972db1	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295c24889e353b492958f7083b8ddc6768c
23	\\xa46cfdcb303f913301f9469e413c1885	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295977994115615219de30a88800e892271
24	\\x1ad1ef53c3b9b3799b7c6f7c45dfb73d	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc322958a1d74b65a409307646634c4e3007ac7
25	\\x6120995d4fc089b5aa172901f9051418	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295355a44c71f04e0c1a347ab123bdd8ee4
26	\\xb81660007986c97b407741fe00813b8c	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc322950ba7c3e229562c0edb45a8ecbae988d1
27	\\xd1454eb777afc05d8e590da8d4a4211c	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295459ca9bf94a6d007ef410c73ed52c247
28	\\x6ab269b4b089e2c40abbfb68385464f5	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295660de6858fa20dced636041ebaac8f77
29	\\xb4b0a81a999a3943bd12b62776da3dfd	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295cd2f1c02a274d1d405e0eb2860c6de96
30	\\x5f3111de9f803df2e5f7f3f79d64dc67	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e1487b1f693c423937a12b8992942cf347bfe8ebbe4a45a338c282969dcc32295a66ebe4f612feed142acce60556a1b79
31	\\xd5e8e2733762a9129ffda90e4a18c932	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38e0a8639918335ae867fe2ec72a3e9ba87102da45a12a3f8880ed1a7200ff15e1
32	\\x2008021a3ddeccfffac0503f6957379f	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f382acc6c6c351e06e4229d57ec0de22627f17097422ebaea8c9c8e562544a45d3d
33	\\xd06a4fc842d8573ff3fbb9ba14adc492	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38e93fe9a099d4560817e52538d2710a7a73f2906b0f8371f226f63aa221a0338d
34	\\x3ce9335deb75de3302052e3696ceb595	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f384bbf4a46bc019acf0b01eb88ed5f6e4f023e2680f8fb07aa46172044da3c3bc3
35	\\x4781c8311a37ccf8cb9b3979bdae2b2d	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38c0d3b53025708d6727ba9a6e64a4115135a0a76f742710e653de3dbd2a75aaf4
36	\\x003c30369a5f45f372f7fc39a3bcc260	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38d1cec37ca38812a376555cdb719b6544d56a15d897c611a60a6210ea9fd4dab0
37	\\x04a1ed250b4e117ff46814ef27c88a9d	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38d6bbb15f094cfbf65fd31ad4a0aefc9ad1c96aaa026aed402b1fc2748e290d34
38	\\x898e2b939ff9176f0346fe3907be3ad3	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38b2ee26be039d024d02e0f0b17f012bed5c50e1dd14fa3a5377df4f2628499c65
39	\\xede6c505db3f12c33dac0a01c402c6e0	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38a3db5038b5211a00b799db9ccbe6e14d97a16f0d63999bea1cfb3283f048cada
40	\\xab9e4d85f51eb58a53dedf0119c1e3a1	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4ebb423f99daa9578fdac85d698a783f38e0a8639918335ae867fe2ec72a3e9ba835ecf85f253ca98661c2969d57a40774
41	\\x9f6a8a8fe45cd65110c74b2999449607	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222e59702b3338ab0ab568e8ab2dd0911cd5bfcaea1a8385f5baa6cdd473109f005d
42	\\x720c9f8763f78d2d607b1a3f3129e13e	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222ee41cc5b1e0c57c445918728bccfd3e5fbd3140578e6ccd640c24b24c915860c8
43	\\xd1503622ee5878588e230f6fae14a7bf	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222ed94ccb5688408b00755539b1a9fa41cae0c719e9c6bf667dcfd4ab49962a5b5d
44	\\x0ffd51bf892f453c2089f3fa1d030ca7	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222e1d9b5ef92b9dcfe3a6f48723d04090fee4d2c7131595e38324f7b7497e9d1c0f
45	\\x93604becc5017f40f8ea57a328bf036d	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222efd023868e116e90966a1d9d6b288c899b1d188442d10e2aaaf9077bd8a8e4b63
46	\\xb38fbd47b377d561ed450910f8bbdb6d	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222e94c027aa5852815cfd01aa3d6b148aa9e3d9ebf44005f14b830b5976e0c8b0b2
47	\\x6d2038df416f3a5ed84ca097b3e209b4	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222e78d3781bbdc0b17ffe5323bada1a16d6c73b45e463b421dd2e5b45b72bf1c96e
48	\\x0c171accdcba75c13150fcb78febfc58	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222ebe1281115b98f280ed846c4def1c3c6a72c9b6470950a918659b1860ec0fa2d4
49	\\xc695d0a67a912a75239ead59638957b0	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222ea69cd199cb55e315cddca67b78794efdeb6d08df27d350aab2500f8337939a9e
50	\\xd28e4cc41c53ed9ff48aece19eedc953	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e3be42a7c0680283808e500792bd5ac46283142f8ed3c6c0a3d4435defdf5222e76becc43fbb7810dcf5979cd3bae4422ee2e7ab782519cbd51d1dd41b0078c00
51	\\x841e7d988f86f88857877269c9375ae5	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e10ea364548704c8219ba0db183ff4c83d
52	\\xd264c024b5cf19fe09692882bfc44bf2	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e177a3a4ce2ebb925cf2930dbc8b3ea0c6
53	\\x854ad8db9b99e4492f4f82feb4e21ed5	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e1be3166e9e2ac0ac873330540b70b87a9
54	\\xea9dd76b54f355c55e9cf9bc78eccd70	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e1e6a6527974064c6be8e175a6a13a5e02
55	\\xb22245ad72b9968f2183a11ffd381ab9	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e10606ab512d8e8e98847e34f52cebbd9a
56	\\xb99f78bfa5f92db53aeeda02dde69113	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e125946a603571f29016fabef6a3c83921
57	\\xf5b87ade63b74926f27382460a1ae8e3	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e1baa13de989cf4580df0e3b90b2e16ca0
58	\\x366a1337653eeed53397d609d7faef8a	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e1e47275777b21fc981c29fb21084a8abe
59	\\x2d63a910f932834b259df218da449054	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e19ad963577978869ad992210b3713bab4
60	\\xfae5f0272b17a4113a3b4dfb03440418	\\x7adb99f8c0bdb6a9af044d0ed696ee63d252f57fda3ab0ba20e06ea16e7b2d4e0eeb5470166b80557d1a41cab99e6986e12ddbb5f53282798df82cdd0b0094e1ab3fd748bd0b89758b646df096f33930
61	\\x3801508d923fd5cafc74501532f66fd0	\\xace1759e3268eb12a2c4dbc80bd998855219083f8e5b38488f3b677d8afd3dc71af9d8728b2315f0cdf0bd8c42d2346c7eab69bce8f6b57063948d4783da038f427d4b5c6d8d2807f3c10a13e3182d36
63	\\x1154059b087461eb387972eb2b7d2e68	\\xace1759e3268eb12a2c4dbc80bd998855219083f8e5b38488f3b677d8afd3dc71af9d8728b2315f0cdf0bd8c42d2346c03f70e0a49d6544bc1ac25c71531a39c42cec562bfb7eda008e042456dfd5afc
64	\\xdf433ab6df3a6142f8f848c786f82b43	\\xace1759e3268eb12a2c4dbc80bd998855219083f8e5b38488f3b677d8afd3dc71af9d8728b2315f0cdf0bd8c42d2346cf1046bbd775565b44e509806773a91c98f2b4e0cb09511c76b8c4a7cb7205d9f
65	\\x8220b22ce973d9351de9a3855532e11d	\\xace1759e3268eb12a2c4dbc80bd998855219083f8e5b38488f3b677d8afd3dc71af9d8728b2315f0cdf0bd8c42d2346caa04cb7a3c53c7cb05539c6335868a8ee49fedbf2e52ed868ef0b0773ee5e8a3
66	\\xfcad4b74eac4294cb90e6797262f24f7	\\x476a31176bfeb2b9de3b26b9b22bfc7ffba608c724cd12ff3164f8b5b27d4a3dd34f31fb87374fa862540e1795f8e290c6e0e86bfb849c5aa30778d0b825dfa83c9e7743be2038bb3faaee68377878eb
67	\\x9a779e3a62503d7d1929aa95b2f4933f	\\x476a31176bfeb2b9de3b26b9b22bfc7ffba608c724cd12ff3164f8b5b27d4a3dd34f31fb87374fa862540e1795f8e290173811e4c0200ef41a6cb1136ad99602cc24d2526363f084bd11809f3162bd37
68	\\x460ef1ad6d5ac021c28911c2e340abfb	\\x476a31176bfeb2b9de3b26b9b22bfc7ffba608c724cd12ff3164f8b5b27d4a3dd34f31fb87374fa862540e1795f8e290797436d61fdc57d8a458a6c52d39b3a6ee3f8996f143a1a2add11998f03eeecf
69	\\xb0f2a995552101aa60e94afa60272acf	\\x476a31176bfeb2b9de3b26b9b22bfc7ffba608c724cd12ff3164f8b5b27d4a3dd34f31fb87374fa862540e1795f8e290304738e5a5477928bfd09f3fa6e58efd2b277accfa3fb0c84718cddbcae418ee
70	\\x892de54bd02ec76e70c1f9acbd087a42	\\x476a31176bfeb2b9de3b26b9b22bfc7ffba608c724cd12ff3164f8b5b27d4a3dd34f31fb87374fa862540e1795f8e290ef5967c5c405b5a2af06b0ea52f987c1ef192e72c7265f3e5a1726dfd519d5bd
71	\\x81e1be978010449ac2fb04dd86307137	\\x15fba3fe2b71e1120ae2e2404ace7c05643ba977981c477bd666296a37140b7476ccc3c7078db88b0ac8b604f684015e3150e54f035293acd0837fe7b5dc4f57
72	\\x1b902564e06e7b6bebe66b61c8f64898	\\x15fba3fe2b71e1120ae2e2404ace7c05643ba977981c477bd666296a37140b7498b871e19655f59962564fc56dced007a64abfa018025f8b3109995f0e8ccec4
73	\\x16ba5616bca670424e89293403ee7b71	\\x15fba3fe2b71e1120ae2e2404ace7c05643ba977981c477bd666296a37140b7403569b01dba982bafae7a78cc080184cb1e6629e4df20f94e89d141748e20bc4
74	\\x7ad1e22f114260da705b963f2a1dc7ef	\\x15fba3fe2b71e1120ae2e2404ace7c05643ba977981c477bd666296a37140b74b8352660b8b466548ee8bef6270707bc87adea64d9dbecdf42e0b35bfb98c358
75	\\xda146df6a2281ee76de22940177ab005	\\x15fba3fe2b71e1120ae2e2404ace7c05643ba977981c477bd666296a37140b7415ca2aeef8b6abb6631199da1e82f75603980ca80b8844605b93587f6ff9d01e
76	\\x3124047e510bd0939a67d44faf25a68b	\\xeb15d1767b5c95bf42c9598beb38c2715a35199ab5257ac1894b46d9b8914ddcc10a67c8a5201e3f63c32880ecc8a513de00e58d08bf5292b8ed599b7f537215
77	\\x9b4cef0052a8733097c93d7e54a35acd	\\xeb15d1767b5c95bf42c9598beb38c2715a35199ab5257ac1894b46d9b8914ddcc10a67c8a5201e3f63c32880ecc8a51357948f7dcdf2a2db432008fb2a5a74eb
78	\\x711d1c437d525e90fde8c8f00c42c585	\\xeb15d1767b5c95bf42c9598beb38c2715a35199ab5257ac1894b46d9b8914ddcc10a67c8a5201e3f63c32880ecc8a5130ce14436833c63ab8eddba706d75c924
79	\\x6e3e64bd7125ecedbd78590f8d1f9de1	\\xeb15d1767b5c95bf42c9598beb38c2715a35199ab5257ac1894b46d9b8914ddcc10a67c8a5201e3f63c32880ecc8a513f341d77e9bd027a736b1eeb1efbb41ff
80	\\xe9289cf8b5d4c8c37a4f3919845106f6	\\xeb15d1767b5c95bf42c9598beb38c2715a35199ab5257ac1894b46d9b8914ddcc10a67c8a5201e3f63c32880ecc8a51365b244330d5d35dc32f473202dc4fdeb
81	\\x402f7089e5558142af61c5fba7a0d417	\\xb8bab1021386abc58be8044c5b87dfa5058179d5c3712e832040178605a88c470050f919d1ea3fbab0e18c15a5f8ae3d37787f0b36bf71bf076795a5a2d08161d5049f0544a95930fa8f443771d02cd2
82	\\x4d1270b898dc5a9992fc03a193553048	\\xb8bab1021386abc58be8044c5b87dfa5058179d5c3712e832040178605a88c470050f919d1ea3fbab0e18c15a5f8ae3d4ea8f85c974ee97e8a4259e39f909b6e8ad8b9e430c8e0e4cca0a3aab924e838
83	\\x5ea8bf6be7536566b37299f477c5f912	\\xb8bab1021386abc58be8044c5b87dfa5058179d5c3712e832040178605a88c470050f919d1ea3fbab0e18c15a5f8ae3d0f6422bf50b7c48afd937e0be4a682c9eea4d756f4948585ded2c6f520ffb50c
84	\\xb8da059305baaf4ba0087ce2b3328f19	\\xb8bab1021386abc58be8044c5b87dfa5058179d5c3712e832040178605a88c470050f919d1ea3fbab0e18c15a5f8ae3dd3ff22ec36add2cb8a5ade1de8506618641865c8170b531834b91f1e5aed9904
85	\\xa59379fe43a4659133d1f8d0f1cf72ec	\\xb8bab1021386abc58be8044c5b87dfa5058179d5c3712e832040178605a88c470050f919d1ea3fbab0e18c15a5f8ae3d626fbe656d17728e3e9acdc14bf60915a72950bc0e4a4d37aa90b67967b1007e
86	\\x6cd943966dc52f511561e4810da0e618	\\x4668ff6fea9c999e2fe89fab6850950b6d5a2547c0a830163b88959a6ddca287f9b0c1297ca2136d828f3204e71847f96a1a1b8c49244ef97230810cce86b3c7427cea6e4720afc9eb925be2bc236890bd047990b396a0775f0d8216ebad9ce3
87	\\xf3156e29f9b80b42169e4faa19a1b640	\\x4668ff6fea9c999e2fe89fab6850950b6d5a2547c0a830163b88959a6ddca287f9b0c1297ca2136d828f3204e71847f96a1a1b8c49244ef97230810cce86b3c7427cea6e4720afc9eb925be2bc236890dbb076e56cea6a27da0c68cd8bea27b7
88	\\x1123f9b2849b8716283d4072311508be	\\x4668ff6fea9c999e2fe89fab6850950b6d5a2547c0a830163b88959a6ddca287f9b0c1297ca2136d828f3204e71847f96a1a1b8c49244ef97230810cce86b3c7427cea6e4720afc9eb925be2bc2368901ca0d379aaa0133c4ee5d9ad154218a5
89	\\x9d8ce16dc3c8f0003fb2c0893f4591b8	\\x4668ff6fea9c999e2fe89fab6850950b6d5a2547c0a830163b88959a6ddca287f9b0c1297ca2136d828f3204e71847f96a1a1b8c49244ef97230810cce86b3c7427cea6e4720afc9eb925be2bc236890545eac8703b619f8b2b715d12d4c379b
90	\\x16fa06b47faf67898ed550599f923deb	\\x4668ff6fea9c999e2fe89fab6850950b6d5a2547c0a830163b88959a6ddca287f9b0c1297ca2136d828f3204e71847f96a1a1b8c49244ef97230810cce86b3c7427cea6e4720afc9eb925be2bc23689015b5cd85deba803e30e76cb086211117
91	\\x86229aae3fab855ca580124f021c9113	\\x02472b1d4d4916fd000fbb436f1419a0bef75f5a0d7484f79097ffb85b44596966b7f049150d3ee098ac16cb076f0447503cfdacfd8a1b8ebecbdf89674398e293cc1d8b0db8b6e67351fe4aaa1876ec
92	\\x35a6bfb64af8e2f77d538227440535ef	\\x02472b1d4d4916fd000fbb436f1419a0bef75f5a0d7484f79097ffb85b44596966b7f049150d3ee098ac16cb076f0447503cfdacfd8a1b8ebecbdf89674398e21b40feba62e5c872e4de34cb80c702d7
93	\\xe25687277295d5d4e41c8bab8b571163	\\x02472b1d4d4916fd000fbb436f1419a0bef75f5a0d7484f79097ffb85b44596966b7f049150d3ee098ac16cb076f0447503cfdacfd8a1b8ebecbdf89674398e21072f5bd57e32443a3bd3d2ffac4f77f
94	\\xa9146785c2c8940864d5de7680d2fe7d	\\x02472b1d4d4916fd000fbb436f1419a0bef75f5a0d7484f79097ffb85b44596966b7f049150d3ee098ac16cb076f0447503cfdacfd8a1b8ebecbdf89674398e233b12e8300796c2a98bea300f1266212
95	\\x452236d9bf9352a60a9c3cac8f85fa1d	\\x02472b1d4d4916fd000fbb436f1419a0bef75f5a0d7484f79097ffb85b44596966b7f049150d3ee098ac16cb076f0447503cfdacfd8a1b8ebecbdf89674398e2cb66d58964c9f5aefd74211f43c72888
96	\\x2dca0c86f5a21e6a07115afc58a9889c	\\x36046fdffa2622b6840124318eac3f4b8b9d0b4118f645cc6dacc997be03efaacf830a8d4e3d70565dd77d0015bf8e914bccd93544715b55d521e5fd7060ec422e19801f2172f76a12ad9043eaa941656f6626fe5c4de0ae2bf09ad79a3a06da
97	\\xe766f97fd2322d38caaa731210c6d895	\\x36046fdffa2622b6840124318eac3f4b8b9d0b4118f645cc6dacc997be03efaacf830a8d4e3d70565dd77d0015bf8e914bccd93544715b55d521e5fd7060ec422e19801f2172f76a12ad9043eaa9416592cfa7b956f45ab0015df5da72f47315
98	\\x8f243e4446a9b6645f7d53e054b898b1	\\x36046fdffa2622b6840124318eac3f4b8b9d0b4118f645cc6dacc997be03efaacf830a8d4e3d70565dd77d0015bf8e914bccd93544715b55d521e5fd7060ec422e19801f2172f76a12ad9043eaa941653cd291e5018ec2cb03856daa6a2141b4
99	\\x48d1b9e759f5a0065a635a0e0a3263c2	\\x36046fdffa2622b6840124318eac3f4b8b9d0b4118f645cc6dacc997be03efaacf830a8d4e3d70565dd77d0015bf8e914bccd93544715b55d521e5fd7060ec422e19801f2172f76a12ad9043eaa9416592ecca1fc7e92cf30fab0ec9f979400e
100	\\x0a7c228e55150cc393a8aa8c717612e9	\\x36046fdffa2622b6840124318eac3f4b8b9d0b4118f645cc6dacc997be03efaacf830a8d4e3d70565dd77d0015bf8e914bccd93544715b55d521e5fd7060ec422e19801f2172f76a12ad9043eaa941656304196f6243e01598c7764e0737b066
\.


--
-- Data for Name: price_history; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.price_history (id, id_instrument, old_price, new_price, change_date, changed_by) FROM stdin;
1	2	500.00	700.00	2026-05-30 19:12:16.921411	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.users (id, u_name, u_password, u_role) FROM stdin;
1	user	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	сотрудник
5	admin	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	администратор
6	highuser	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	старший сотрудник
7	isnap	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	старший сотрудник
\.


--
-- Name: customer_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.customer_id_seq', 100, true);


--
-- Name: instrument_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.instrument_id_seq', 77, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.orders_id_seq', 102, true);


--
-- Name: passport_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.passport_id_seq', 100, true);


--
-- Name: price_history_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.price_history_id_seq', 1, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.users_id_seq', 7, true);


--
-- Name: customer customer_id_passport_key; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.customer
    ADD CONSTRAINT customer_id_passport_key UNIQUE (id_passport);


--
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (id);


--
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: passport passport_pkey; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.passport
    ADD CONSTRAINT passport_pkey PRIMARY KEY (id);


--
-- Name: price_history price_history_pkey; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.price_history
    ADD CONSTRAINT price_history_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_u_name_key; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.users
    ADD CONSTRAINT users_u_name_key UNIQUE (u_name);


--
-- Name: orders trg_calculate_finish_date; Type: TRIGGER; Schema: summer_cp; Owner: postgres
--

CREATE TRIGGER trg_calculate_finish_date BEFORE INSERT OR UPDATE OF start_date, count_days ON summer_cp.orders FOR EACH ROW EXECUTE FUNCTION summer_cp.calculate_finish_date();


--
-- Name: orders trg_calculate_full_price; Type: TRIGGER; Schema: summer_cp; Owner: postgres
--

CREATE TRIGGER trg_calculate_full_price BEFORE INSERT OR UPDATE OF id_instrument, count_days, discount ON summer_cp.orders FOR EACH ROW EXECUTE FUNCTION summer_cp.calculate_full_price();


--
-- Name: passport trg_encrypt_passport; Type: TRIGGER; Schema: summer_cp; Owner: postgres
--

CREATE TRIGGER trg_encrypt_passport BEFORE INSERT OR UPDATE ON summer_cp.passport FOR EACH ROW EXECUTE FUNCTION summer_cp.encrypt_passport_trigger();


--
-- Name: instrument trg_log_price_change; Type: TRIGGER; Schema: summer_cp; Owner: postgres
--

CREATE TRIGGER trg_log_price_change AFTER UPDATE OF price ON summer_cp.instrument FOR EACH ROW EXECUTE FUNCTION summer_cp.log_price_change();


--
-- Name: customer customer_id_passport_fkey; Type: FK CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.customer
    ADD CONSTRAINT customer_id_passport_fkey FOREIGN KEY (id_passport) REFERENCES summer_cp.passport(id) ON DELETE CASCADE;


--
-- Name: orders orders_id_customer_fkey; Type: FK CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.orders
    ADD CONSTRAINT orders_id_customer_fkey FOREIGN KEY (id_customer) REFERENCES summer_cp.customer(id);


--
-- Name: orders orders_id_instrument_fkey; Type: FK CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.orders
    ADD CONSTRAINT orders_id_instrument_fkey FOREIGN KEY (id_instrument) REFERENCES summer_cp.instrument(id);


--
-- Name: orders orders_id_user_fkey; Type: FK CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.orders
    ADD CONSTRAINT orders_id_user_fkey FOREIGN KEY (id_user) REFERENCES summer_cp.users(id);


--
-- Name: price_history price_history_id_instrument_fkey; Type: FK CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.price_history
    ADD CONSTRAINT price_history_id_instrument_fkey FOREIGN KEY (id_instrument) REFERENCES summer_cp.instrument(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict HhLEzUeVpaLu1OrM8ynpssId7kDruKyAiXdAgFhJaRc5AxVYFFcbklQU82NpoJ8

