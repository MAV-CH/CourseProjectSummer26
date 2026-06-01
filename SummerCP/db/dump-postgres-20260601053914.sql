--
-- PostgreSQL database dump
--

\restrict PTUnXLRHFhrOV3DdoWrOaZIxTSiQSb47SmPA1L80fd0stKBvIte2NfCAhrQO47a

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
-- Name: summer_cp; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA summer_cp;


ALTER SCHEMA summer_cp OWNER TO postgres;

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
-- Name: passport; Type: TABLE; Schema: summer_cp; Owner: postgres
--

CREATE TABLE summer_cp.passport (
    id integer NOT NULL,
    p_number character varying(20) NOT NULL,
    p_home character varying(256) NOT NULL
);


ALTER TABLE summer_cp.passport OWNER TO postgres;

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
-- Name: revenue_all; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.revenue_all AS
 SELECT COALESCE(sum(discounted_price), (0)::numeric) AS total_revenue,
    count(id) AS total_orders,
    COALESCE(avg(discounted_price), (0)::numeric) AS avg_order_value
   FROM summer_cp.orders
  WHERE (status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status]));


ALTER VIEW summer_cp.revenue_all OWNER TO postgres;

--
-- Name: revenue_by_month; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.revenue_by_month AS
 SELECT to_char(date_trunc('month'::text, start_date), 'yyyy-mm'::text) AS month,
    COALESCE(sum(discounted_price), (0)::numeric) AS revenue,
    count(id) AS orders_count
   FROM summer_cp.orders
  WHERE ((status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (start_date >= (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone) - '1 year'::interval)))
  GROUP BY (date_trunc('month'::text, start_date))
  ORDER BY (to_char(date_trunc('month'::text, start_date), 'yyyy-mm'::text)) DESC;


ALTER VIEW summer_cp.revenue_by_month OWNER TO postgres;

--
-- Name: revenue_half_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.revenue_half_year AS
 SELECT to_char(date_trunc('month'::text, start_date), 'yyyy-mm'::text) AS month,
    COALESCE(sum(discounted_price), (0)::numeric) AS revenue,
    count(id) AS orders_count,
    sum(COALESCE(sum(discounted_price), (0)::numeric)) OVER (ORDER BY (date_trunc('month'::text, start_date))) AS cumulative_revenue
   FROM summer_cp.orders
  WHERE ((status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (start_date >= (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone) - '6 mons'::interval)))
  GROUP BY (date_trunc('month'::text, start_date))
  ORDER BY (to_char(date_trunc('month'::text, start_date), 'yyyy-mm'::text));


ALTER VIEW summer_cp.revenue_half_year OWNER TO postgres;

--
-- Name: revenue_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.revenue_year AS
 SELECT to_char(date_trunc('month'::text, start_date), 'yyyy-mm'::text) AS month,
    COALESCE(sum(discounted_price), (0)::numeric) AS revenue,
    count(id) AS orders_count,
    sum(COALESCE(sum(discounted_price), (0)::numeric)) OVER (ORDER BY (date_trunc('month'::text, start_date))) AS cumulative_revenue
   FROM summer_cp.orders
  WHERE ((status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (start_date >= (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone) - '1 year'::interval)))
  GROUP BY (date_trunc('month'::text, start_date))
  ORDER BY (to_char(date_trunc('month'::text, start_date), 'yyyy-mm'::text));


ALTER VIEW summer_cp.revenue_year OWNER TO postgres;

--
-- Name: top_customers_all; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_all AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.discounted_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_all OWNER TO postgres;

--
-- Name: top_customers_half_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_half_year AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '180 days'::interval)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.discounted_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_half_year OWNER TO postgres;

--
-- Name: top_customers_month; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_month AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '30 days'::interval)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.discounted_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_month OWNER TO postgres;

--
-- Name: top_customers_quarter; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_quarter AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '90 days'::interval)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.discounted_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_quarter OWNER TO postgres;

--
-- Name: top_customers_year; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_customers_year AS
 SELECT c.id,
    concat(c.l_name, ' ', c.f_name) AS full_name,
    c.phone,
    count(o.id) AS rental_count,
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_spent
   FROM (summer_cp.customer c
     LEFT JOIN summer_cp.orders o ON (((o.id_customer = c.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '365 days'::interval)))))
  GROUP BY c.id, c.l_name, c.f_name, c.phone
  ORDER BY COALESCE(sum(o.discounted_price), (0)::numeric) DESC;


ALTER VIEW summer_cp.top_customers_year OWNER TO postgres;

--
-- Name: top_instruments_all; Type: VIEW; Schema: summer_cp; Owner: postgres
--

CREATE VIEW summer_cp.top_instruments_all AS
 SELECT i.id,
    i.i_name,
    count(o.id) AS rental_count,
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_revenue
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
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '180 days'::interval)))))
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
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '30 days'::interval)))))
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
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '90 days'::interval)))))
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
    COALESCE(sum(o.discounted_price), (0)::numeric) AS total_revenue
   FROM (summer_cp.instrument i
     LEFT JOIN summer_cp.orders o ON (((o.id_instrument = i.id) AND (o.status = ANY (ARRAY['оплачено'::summer_cp.order_status, 'возвращено'::summer_cp.order_status])) AND (o.start_date >= (CURRENT_DATE - '365 days'::interval)))))
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
101	101	Георгий	Берг	Иванович	89000409900
\.


--
-- Data for Name: instrument; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.instrument (id, i_name, i_category, price, i_more, i_status) FROM stdin;
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
1	НОЖНИЦЫ ПО МЕТАЛЛУ МАКИТА JN 1601	режущий инструмент	700.00	-	доступен
76	НИВЕЛИР ОПТИЧЕСКИЙ	измерительный инструмент	800.00	-	недоступен
78	Болгарка аккумулятрная	\N	500.00	Заряда хватает на 15 минут использования	недоступен
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.orders (id, id_customer, id_instrument, id_user, start_date, count_days, finish_date, full_price, discount, discounted_price, status, o_more) FROM stdin;
1	34	10	1	2026-03-12 00:00:00	11	2026-03-23 00:00:00	11000.00	0.00	11000.00	возвращено	-
2	55	4	1	2026-05-01 00:00:00	6	2026-05-07 00:00:00	2400.00	0.00	2400.00	возвращено	-
3	4	56	5	2026-05-04 00:00:00	14	2026-05-18 00:00:00	7000.00	0.00	7000.00	возвращено	-
4	91	53	5	2026-04-13 00:00:00	10	2026-04-23 00:00:00	8000.00	0.00	8000.00	возвращено	-
5	53	68	5	2026-02-23 00:00:00	1	2026-02-24 00:00:00	500.00	0.00	500.00	возвращено	-
6	76	14	7	2026-05-20 00:00:00	5	2026-05-25 00:00:00	8500.00	0.00	8500.00	возвращено	-
7	87	63	7	2026-01-26 00:00:00	7	2026-02-02 00:00:00	8400.00	0.00	8400.00	возвращено	-
8	62	69	1	2026-02-01 00:00:00	14	2026-02-15 00:00:00	8400.00	0.00	8400.00	возвращено	-
9	73	2	7	2026-01-10 00:00:00	9	2026-01-19 00:00:00	6300.00	0.00	6300.00	возвращено	-
10	18	8	7	2026-04-02 00:00:00	9	2026-04-11 00:00:00	3600.00	0.00	3600.00	возвращено	-
11	58	67	5	2026-02-10 00:00:00	1	2026-02-11 00:00:00	500.00	0.00	500.00	возвращено	-
12	84	74	1	2026-01-27 00:00:00	1	2026-01-28 00:00:00	600.00	0.00	600.00	возвращено	-
13	61	46	6	2026-01-08 00:00:00	9	2026-01-17 00:00:00	6300.00	0.00	6300.00	возвращено	-
14	37	69	6	2026-05-10 00:00:00	9	2026-05-19 00:00:00	5400.00	0.00	5400.00	возвращено	-
15	48	70	1	2026-02-18 00:00:00	9	2026-02-27 00:00:00	16200.00	0.00	16200.00	возвращено	-
16	67	25	6	2026-04-14 00:00:00	13	2026-04-27 00:00:00	10400.00	0.00	10400.00	возвращено	-
17	53	74	7	2026-02-22 00:00:00	10	2026-03-04 00:00:00	6000.00	0.00	6000.00	возвращено	-
18	99	65	7	2026-03-15 00:00:00	4	2026-03-19 00:00:00	2800.00	0.00	2800.00	возвращено	-
19	56	43	1	2026-04-03 00:00:00	13	2026-04-16 00:00:00	6500.00	0.00	6500.00	возвращено	-
20	74	44	5	2026-01-05 00:00:00	6	2026-01-11 00:00:00	3600.00	0.00	3600.00	возвращено	-
21	1	3	5	2026-03-02 00:00:00	4	2026-03-06 00:00:00	4800.00	0.00	4800.00	возвращено	-
22	77	51	1	2026-01-28 00:00:00	3	2026-01-31 00:00:00	1500.00	0.00	1500.00	возвращено	-
23	19	32	1	2026-01-10 00:00:00	8	2026-01-18 00:00:00	8000.00	0.00	8000.00	возвращено	-
24	22	60	7	2026-01-11 00:00:00	5	2026-01-16 00:00:00	2000.00	0.00	2000.00	возвращено	-
25	39	3	5	2026-03-12 00:00:00	13	2026-03-25 00:00:00	15600.00	0.00	15600.00	возвращено	-
26	16	47	6	2026-03-17 00:00:00	7	2026-03-24 00:00:00	10500.00	0.00	10500.00	возвращено	-
27	43	70	6	2026-05-18 00:00:00	5	2026-05-23 00:00:00	9000.00	0.00	9000.00	возвращено	-
28	15	23	7	2026-05-06 00:00:00	12	2026-05-18 00:00:00	6000.00	0.00	6000.00	возвращено	-
29	7	4	5	2026-03-02 00:00:00	11	2026-03-13 00:00:00	4400.00	0.00	4400.00	возвращено	-
30	96	60	1	2026-03-16 00:00:00	2	2026-03-18 00:00:00	800.00	0.00	800.00	возвращено	-
31	68	5	1	2026-01-28 00:00:00	14	2026-02-11 00:00:00	7000.00	0.00	7000.00	возвращено	-
32	34	77	1	2026-03-06 00:00:00	13	2026-03-19 00:00:00	6500.00	0.00	6500.00	возвращено	-
33	34	23	5	2026-03-30 00:00:00	12	2026-04-11 00:00:00	6000.00	0.00	6000.00	возвращено	-
34	92	77	1	2026-05-05 00:00:00	2	2026-05-07 00:00:00	1000.00	0.00	1000.00	возвращено	-
35	83	45	5	2026-02-25 00:00:00	1	2026-02-26 00:00:00	1500.00	0.00	1500.00	возвращено	-
36	90	13	1	2026-04-11 00:00:00	6	2026-04-17 00:00:00	4200.00	0.00	4200.00	возвращено	-
37	16	75	5	2026-04-28 00:00:00	5	2026-05-03 00:00:00	6000.00	0.00	6000.00	возвращено	-
38	65	63	7	2026-04-12 00:00:00	6	2026-04-18 00:00:00	7200.00	0.00	7200.00	возвращено	-
39	50	71	6	2026-03-02 00:00:00	4	2026-03-06 00:00:00	5600.00	0.00	5600.00	возвращено	-
40	5	19	1	2026-01-16 00:00:00	3	2026-01-19 00:00:00	2400.00	0.00	2400.00	возвращено	-
41	59	23	5	2026-02-24 00:00:00	2	2026-02-26 00:00:00	1000.00	0.00	1000.00	возвращено	-
42	65	1	5	2026-04-28 00:00:00	6	2026-05-04 00:00:00	3000.00	0.00	3000.00	возвращено	-
43	94	10	7	2026-03-12 00:00:00	8	2026-03-20 00:00:00	8000.00	0.00	8000.00	возвращено	-
44	6	32	6	2026-01-26 00:00:00	5	2026-01-31 00:00:00	5000.00	0.00	5000.00	возвращено	-
45	36	12	5	2026-03-14 00:00:00	13	2026-03-27 00:00:00	5200.00	0.00	5200.00	возвращено	-
46	22	50	6	2026-03-08 00:00:00	2	2026-03-10 00:00:00	500.00	0.00	500.00	возвращено	-
47	99	54	7	2026-02-24 00:00:00	1	2026-02-25 00:00:00	1400.00	0.00	1400.00	возвращено	-
48	72	37	6	2026-04-05 00:00:00	6	2026-04-11 00:00:00	3000.00	0.00	3000.00	возвращено	-
49	94	48	5	2026-04-12 00:00:00	4	2026-04-16 00:00:00	4800.00	0.00	4800.00	возвращено	-
50	86	63	6	2026-03-18 00:00:00	6	2026-03-24 00:00:00	7200.00	0.00	7200.00	возвращено	-
51	78	8	5	2026-01-24 00:00:00	9	2026-02-02 00:00:00	3600.00	0.00	3600.00	возвращено	-
52	45	51	7	2026-01-06 00:00:00	4	2026-01-10 00:00:00	2000.00	0.00	2000.00	возвращено	-
53	66	21	6	2026-03-04 00:00:00	12	2026-03-16 00:00:00	7200.00	0.00	7200.00	возвращено	-
54	50	62	5	2026-03-21 00:00:00	12	2026-04-02 00:00:00	9600.00	0.00	9600.00	возвращено	-
55	76	58	5	2026-03-10 00:00:00	12	2026-03-22 00:00:00	21600.00	0.00	21600.00	возвращено	-
56	20	15	1	2026-03-06 00:00:00	13	2026-03-19 00:00:00	18200.00	0.00	18200.00	возвращено	-
57	21	12	5	2026-01-26 00:00:00	9	2026-02-04 00:00:00	3600.00	0.00	3600.00	возвращено	-
58	52	22	7	2026-02-23 00:00:00	12	2026-03-07 00:00:00	12000.00	0.00	12000.00	возвращено	-
59	98	48	1	2026-03-21 00:00:00	9	2026-03-30 00:00:00	10800.00	0.00	10800.00	возвращено	-
60	42	9	7	2026-01-07 00:00:00	5	2026-01-12 00:00:00	2000.00	0.00	2000.00	возвращено	-
61	46	64	6	2026-05-12 00:00:00	2	2026-05-14 00:00:00	1400.00	0.00	1400.00	возвращено	-
62	44	4	1	2026-03-15 00:00:00	6	2026-03-21 00:00:00	2400.00	0.00	2400.00	возвращено	-
63	71	69	6	2026-03-12 00:00:00	12	2026-03-24 00:00:00	7200.00	0.00	7200.00	возвращено	-
64	5	34	1	2026-01-11 00:00:00	1	2026-01-12 00:00:00	1200.00	0.00	1200.00	возвращено	-
65	23	45	5	2026-03-10 00:00:00	4	2026-03-14 00:00:00	6000.00	0.00	6000.00	возвращено	-
66	61	74	5	2026-01-11 00:00:00	6	2026-01-17 00:00:00	3600.00	0.00	3600.00	возвращено	-
67	36	14	5	2026-01-09 00:00:00	3	2026-01-12 00:00:00	5100.00	0.00	5100.00	возвращено	-
68	87	10	6	2026-05-09 00:00:00	9	2026-05-18 00:00:00	9000.00	0.00	9000.00	возвращено	-
69	90	40	7	2026-02-16 00:00:00	6	2026-02-22 00:00:00	4800.00	0.00	4800.00	возвращено	-
70	25	31	5	2026-01-22 00:00:00	1	2026-01-23 00:00:00	600.00	0.00	600.00	возвращено	-
71	87	63	1	2026-04-11 00:00:00	4	2026-04-15 00:00:00	4800.00	0.00	4800.00	возвращено	-
72	68	75	5	2026-02-21 00:00:00	3	2026-02-24 00:00:00	3600.00	0.00	3600.00	возвращено	-
73	3	50	7	2026-01-23 00:00:00	7	2026-01-30 00:00:00	1750.00	0.00	1750.00	возвращено	-
74	57	49	6	2026-01-01 00:00:00	7	2026-01-08 00:00:00	3500.00	0.00	3500.00	возвращено	-
75	87	33	6	2026-04-02 00:00:00	8	2026-04-10 00:00:00	3200.00	0.00	3200.00	возвращено	-
76	82	75	5	2026-01-09 00:00:00	9	2026-01-18 00:00:00	10800.00	0.00	10800.00	возвращено	-
77	10	64	1	2026-01-26 00:00:00	1	2026-01-27 00:00:00	700.00	0.00	700.00	возвращено	-
78	32	67	6	2026-03-27 00:00:00	13	2026-04-09 00:00:00	6500.00	0.00	6500.00	возвращено	-
79	99	12	1	2026-04-18 00:00:00	9	2026-04-27 00:00:00	3600.00	0.00	3600.00	возвращено	-
80	55	21	1	2026-01-06 00:00:00	4	2026-01-10 00:00:00	2400.00	0.00	2400.00	возвращено	-
81	76	66	7	2026-03-09 00:00:00	2	2026-03-11 00:00:00	1000.00	0.00	1000.00	возвращено	-
82	64	31	6	2026-02-11 00:00:00	12	2026-02-23 00:00:00	7200.00	0.00	7200.00	возвращено	-
83	56	28	6	2026-02-06 00:00:00	11	2026-02-17 00:00:00	15400.00	0.00	15400.00	возвращено	-
84	61	7	1	2026-01-03 00:00:00	11	2026-01-14 00:00:00	8800.00	0.00	8800.00	возвращено	-
85	64	51	6	2026-05-04 00:00:00	3	2026-05-07 00:00:00	1500.00	0.00	1500.00	возвращено	-
86	17	50	7	2026-03-10 00:00:00	11	2026-03-21 00:00:00	2750.00	0.00	2750.00	возвращено	-
87	96	59	1	2026-03-16 00:00:00	7	2026-03-23 00:00:00	2800.00	0.00	2800.00	возвращено	-
88	61	6	7	2026-02-17 00:00:00	11	2026-02-28 00:00:00	8800.00	0.00	8800.00	возвращено	-
89	99	48	1	2026-05-10 00:00:00	4	2026-05-14 00:00:00	4800.00	0.00	4800.00	возвращено	-
90	73	14	1	2026-04-03 00:00:00	3	2026-04-06 00:00:00	5100.00	0.00	5100.00	возвращено	-
91	99	74	7	2026-02-06 00:00:00	13	2026-02-19 00:00:00	7800.00	0.00	7800.00	возвращено	-
92	22	56	6	2026-02-09 00:00:00	4	2026-02-13 00:00:00	2000.00	0.00	2000.00	возвращено	-
93	61	74	7	2026-04-11 00:00:00	2	2026-04-13 00:00:00	1200.00	0.00	1200.00	возвращено	-
94	83	42	7	2026-04-19 00:00:00	5	2026-04-24 00:00:00	4000.00	0.00	4000.00	возвращено	-
95	41	45	1	2026-02-22 00:00:00	6	2026-02-28 00:00:00	9000.00	0.00	9000.00	возвращено	-
96	52	45	6	2026-04-09 00:00:00	8	2026-04-17 00:00:00	12000.00	0.00	12000.00	возвращено	-
97	83	30	1	2026-05-07 00:00:00	8	2026-05-15 00:00:00	4000.00	0.00	4000.00	возвращено	-
98	48	30	6	2026-03-19 00:00:00	9	2026-03-28 00:00:00	4500.00	0.00	4500.00	возвращено	-
99	22	50	6	2026-02-25 00:00:00	12	2026-03-09 00:00:00	3000.00	0.00	3000.00	возвращено	-
100	61	45	7	2026-02-04 00:00:00	13	2026-02-17 00:00:00	19500.00	0.00	19500.00	возвращено	-
101	7	8	5	2026-04-03 00:00:00	5	2026-04-08 00:00:00	2000.00	0.00	2000.00	возвращено	-
102	42	1	7	2026-01-05 00:00:00	6	2026-01-11 00:00:00	3000.00	0.00	3000.00	возвращено	-
103	7	33	5	2026-01-05 00:00:00	5	2026-01-10 00:00:00	2000.00	0.00	2000.00	возвращено	-
104	36	50	1	2026-03-01 00:00:00	8	2026-03-09 00:00:00	2000.00	0.00	2000.00	возвращено	-
105	3	11	6	2026-01-15 00:00:00	14	2026-01-29 00:00:00	4200.00	0.00	4200.00	возвращено	-
106	78	51	5	2026-05-09 00:00:00	7	2026-05-16 00:00:00	3500.00	0.00	3500.00	возвращено	-
107	69	7	7	2026-03-04 00:00:00	12	2026-03-16 00:00:00	9600.00	0.00	9600.00	возвращено	-
108	13	26	7	2026-02-13 00:00:00	13	2026-02-26 00:00:00	9100.00	0.00	9100.00	возвращено	-
109	8	26	7	2026-03-21 00:00:00	10	2026-03-31 00:00:00	7000.00	0.00	7000.00	возвращено	-
110	38	51	5	2026-01-07 00:00:00	9	2026-01-16 00:00:00	4500.00	0.00	4500.00	возвращено	-
111	36	33	5	2026-03-31 00:00:00	1	2026-04-01 00:00:00	400.00	0.00	400.00	возвращено	-
112	83	3	7	2026-01-28 00:00:00	6	2026-02-03 00:00:00	7200.00	0.00	7200.00	возвращено	-
113	62	58	7	2026-03-26 00:00:00	5	2026-03-31 00:00:00	9000.00	0.00	9000.00	возвращено	-
114	62	54	5	2026-04-26 00:00:00	5	2026-05-01 00:00:00	7000.00	0.00	7000.00	возвращено	-
115	51	64	5	2026-01-31 00:00:00	13	2026-02-13 00:00:00	9100.00	0.00	9100.00	возвращено	-
116	14	37	6	2026-02-19 00:00:00	5	2026-02-24 00:00:00	2500.00	0.00	2500.00	возвращено	-
117	41	8	7	2026-04-19 00:00:00	3	2026-04-22 00:00:00	1200.00	0.00	1200.00	возвращено	-
118	69	71	7	2026-04-02 00:00:00	4	2026-04-06 00:00:00	5600.00	0.00	5600.00	возвращено	-
119	66	43	7	2026-03-24 00:00:00	2	2026-03-26 00:00:00	1000.00	0.00	1000.00	возвращено	-
120	18	63	1	2026-04-19 00:00:00	4	2026-04-23 00:00:00	4800.00	0.00	4800.00	возвращено	-
121	9	41	5	2026-01-29 00:00:00	8	2026-02-06 00:00:00	9600.00	0.00	9600.00	возвращено	-
122	22	66	5	2026-02-26 00:00:00	10	2026-03-08 00:00:00	5000.00	0.00	5000.00	возвращено	-
123	75	69	5	2026-03-04 00:00:00	10	2026-03-14 00:00:00	6000.00	0.00	6000.00	возвращено	-
124	17	23	1	2026-03-26 00:00:00	9	2026-04-04 00:00:00	4500.00	0.00	4500.00	возвращено	-
125	76	52	6	2026-01-08 00:00:00	8	2026-01-16 00:00:00	5600.00	0.00	5600.00	возвращено	-
126	75	66	1	2026-02-13 00:00:00	8	2026-02-21 00:00:00	4000.00	0.00	4000.00	возвращено	-
127	68	44	5	2026-03-31 00:00:00	4	2026-04-04 00:00:00	2400.00	0.00	2400.00	возвращено	-
128	71	12	7	2026-03-16 00:00:00	13	2026-03-29 00:00:00	5200.00	0.00	5200.00	возвращено	-
129	85	9	1	2026-04-08 00:00:00	5	2026-04-13 00:00:00	2000.00	0.00	2000.00	возвращено	-
130	1	62	1	2026-02-08 00:00:00	2	2026-02-10 00:00:00	1600.00	0.00	1600.00	возвращено	-
131	69	62	1	2026-02-21 00:00:00	11	2026-03-04 00:00:00	8800.00	0.00	8800.00	возвращено	-
132	76	32	7	2026-05-01 00:00:00	5	2026-05-06 00:00:00	5000.00	0.00	5000.00	возвращено	-
133	9	21	7	2026-03-12 00:00:00	1	2026-03-13 00:00:00	600.00	0.00	600.00	возвращено	-
134	87	39	5	2026-04-06 00:00:00	7	2026-04-13 00:00:00	10500.00	0.00	10500.00	возвращено	-
135	12	63	7	2026-05-18 00:00:00	4	2026-05-22 00:00:00	4800.00	0.00	4800.00	возвращено	-
136	52	23	5	2026-02-22 00:00:00	11	2026-03-05 00:00:00	5500.00	0.00	5500.00	возвращено	-
137	78	33	7	2026-02-24 00:00:00	7	2026-03-03 00:00:00	2800.00	0.00	2800.00	возвращено	-
138	43	65	7	2026-03-24 00:00:00	7	2026-03-31 00:00:00	4900.00	0.00	4900.00	возвращено	-
139	13	49	7	2026-05-04 00:00:00	13	2026-05-17 00:00:00	6500.00	0.00	6500.00	возвращено	-
140	37	33	7	2026-03-07 00:00:00	11	2026-03-18 00:00:00	4400.00	0.00	4400.00	возвращено	-
141	59	46	1	2026-01-05 00:00:00	1	2026-01-06 00:00:00	700.00	0.00	700.00	возвращено	-
142	95	54	1	2026-02-08 00:00:00	6	2026-02-14 00:00:00	8400.00	0.00	8400.00	возвращено	-
143	89	53	5	2026-03-01 00:00:00	2	2026-03-03 00:00:00	1600.00	0.00	1600.00	возвращено	-
144	45	48	1	2026-01-15 00:00:00	6	2026-01-21 00:00:00	7200.00	0.00	7200.00	возвращено	-
145	1	35	6	2026-04-26 00:00:00	1	2026-04-27 00:00:00	500.00	0.00	500.00	возвращено	-
146	62	58	6	2026-04-16 00:00:00	5	2026-04-21 00:00:00	9000.00	0.00	9000.00	возвращено	-
147	1	27	1	2026-01-15 00:00:00	3	2026-01-18 00:00:00	1500.00	0.00	1500.00	возвращено	-
148	46	62	5	2026-03-11 00:00:00	8	2026-03-19 00:00:00	6400.00	0.00	6400.00	возвращено	-
149	66	42	6	2026-05-13 00:00:00	11	2026-05-24 00:00:00	8800.00	0.00	8800.00	возвращено	-
150	86	77	7	2026-01-25 00:00:00	8	2026-02-02 00:00:00	4000.00	0.00	4000.00	возвращено	-
151	28	51	6	2026-05-02 00:00:00	10	2026-05-12 00:00:00	5000.00	0.00	5000.00	возвращено	-
152	15	29	7	2026-05-12 00:00:00	2	2026-05-14 00:00:00	600.00	0.00	600.00	возвращено	-
153	71	56	6	2026-02-04 00:00:00	4	2026-02-08 00:00:00	2000.00	0.00	2000.00	возвращено	-
154	38	43	5	2026-04-15 00:00:00	5	2026-04-20 00:00:00	2500.00	0.00	2500.00	возвращено	-
155	32	28	6	2026-01-07 00:00:00	11	2026-01-18 00:00:00	15400.00	0.00	15400.00	возвращено	-
156	75	17	5	2026-03-07 00:00:00	4	2026-03-11 00:00:00	2000.00	0.00	2000.00	возвращено	-
157	85	56	6	2026-04-07 00:00:00	8	2026-04-15 00:00:00	4000.00	0.00	4000.00	возвращено	-
158	23	52	5	2026-02-07 00:00:00	11	2026-02-18 00:00:00	7700.00	0.00	7700.00	возвращено	-
159	88	44	1	2026-03-29 00:00:00	8	2026-04-06 00:00:00	4800.00	0.00	4800.00	возвращено	-
160	63	31	5	2026-04-17 00:00:00	14	2026-05-01 00:00:00	8400.00	0.00	8400.00	возвращено	-
161	18	52	1	2026-02-06 00:00:00	13	2026-02-19 00:00:00	9100.00	0.00	9100.00	возвращено	-
162	11	56	7	2026-03-24 00:00:00	13	2026-04-06 00:00:00	6500.00	0.00	6500.00	возвращено	-
163	100	7	6	2026-02-06 00:00:00	2	2026-02-08 00:00:00	1600.00	0.00	1600.00	возвращено	-
164	75	1	5	2026-04-26 00:00:00	9	2026-05-05 00:00:00	4500.00	0.00	4500.00	возвращено	-
165	33	35	1	2026-02-27 00:00:00	1	2026-02-28 00:00:00	500.00	0.00	500.00	возвращено	-
166	13	57	6	2026-04-29 00:00:00	6	2026-05-05 00:00:00	3000.00	0.00	3000.00	возвращено	-
167	2	32	7	2026-01-02 00:00:00	7	2026-01-09 00:00:00	7000.00	0.00	7000.00	возвращено	-
168	48	22	7	2026-03-01 00:00:00	1	2026-03-02 00:00:00	1000.00	0.00	1000.00	возвращено	-
169	96	74	7	2026-03-04 00:00:00	11	2026-03-15 00:00:00	6600.00	0.00	6600.00	возвращено	-
170	25	75	1	2026-05-19 00:00:00	14	2026-06-02 00:00:00	16800.00	0.00	16800.00	возвращено	-
171	47	3	5	2026-01-25 00:00:00	2	2026-01-27 00:00:00	2400.00	0.00	2400.00	возвращено	-
172	13	17	1	2026-04-24 00:00:00	9	2026-05-03 00:00:00	4500.00	0.00	4500.00	возвращено	-
173	29	63	1	2026-04-03 00:00:00	12	2026-04-15 00:00:00	14400.00	0.00	14400.00	возвращено	-
174	69	69	7	2026-03-12 00:00:00	12	2026-03-24 00:00:00	7200.00	0.00	7200.00	возвращено	-
175	22	53	7	2026-01-07 00:00:00	1	2026-01-08 00:00:00	800.00	0.00	800.00	возвращено	-
176	87	18	7	2026-03-04 00:00:00	4	2026-03-08 00:00:00	3200.00	0.00	3200.00	возвращено	-
177	36	57	1	2026-01-02 00:00:00	7	2026-01-09 00:00:00	3500.00	0.00	3500.00	возвращено	-
178	82	24	5	2026-03-26 00:00:00	2	2026-03-28 00:00:00	1000.00	0.00	1000.00	возвращено	-
179	18	67	1	2026-01-18 00:00:00	13	2026-01-31 00:00:00	6500.00	0.00	6500.00	возвращено	-
180	88	73	6	2026-03-18 00:00:00	8	2026-03-26 00:00:00	6400.00	0.00	6400.00	возвращено	-
181	95	56	6	2026-04-19 00:00:00	5	2026-04-24 00:00:00	2500.00	0.00	2500.00	возвращено	-
182	59	17	5	2026-03-10 00:00:00	13	2026-03-23 00:00:00	6500.00	0.00	6500.00	возвращено	-
183	11	58	1	2026-02-08 00:00:00	8	2026-02-16 00:00:00	14400.00	0.00	14400.00	возвращено	-
184	72	48	5	2026-05-20 00:00:00	13	2026-06-02 00:00:00	15600.00	0.00	15600.00	возвращено	-
185	93	25	6	2026-02-27 00:00:00	8	2026-03-07 00:00:00	6400.00	0.00	6400.00	возвращено	-
186	10	48	6	2026-03-28 00:00:00	14	2026-04-11 00:00:00	16800.00	0.00	16800.00	возвращено	-
187	93	7	6	2026-02-21 00:00:00	14	2026-03-07 00:00:00	11200.00	0.00	11200.00	возвращено	-
188	43	66	5	2026-01-07 00:00:00	8	2026-01-15 00:00:00	4000.00	0.00	4000.00	возвращено	-
189	35	38	6	2026-04-11 00:00:00	14	2026-04-25 00:00:00	49000.00	0.00	49000.00	возвращено	-
190	80	25	6	2026-04-25 00:00:00	9	2026-05-04 00:00:00	7200.00	0.00	7200.00	возвращено	-
191	60	76	5	2026-03-01 00:00:00	4	2026-03-05 00:00:00	3200.00	0.00	3200.00	возвращено	-
192	61	23	6	2026-01-12 00:00:00	1	2026-01-13 00:00:00	500.00	0.00	500.00	возвращено	-
193	96	34	1	2026-03-04 00:00:00	5	2026-03-09 00:00:00	6000.00	0.00	6000.00	возвращено	-
194	21	49	1	2026-05-06 00:00:00	8	2026-05-14 00:00:00	4000.00	0.00	4000.00	возвращено	-
195	23	23	5	2026-01-25 00:00:00	10	2026-02-04 00:00:00	5000.00	0.00	5000.00	возвращено	-
196	1	13	1	2026-04-12 00:00:00	1	2026-04-13 00:00:00	700.00	0.00	700.00	возвращено	-
197	100	51	5	2026-01-10 00:00:00	10	2026-01-20 00:00:00	5000.00	0.00	5000.00	возвращено	-
198	47	36	1	2026-03-31 00:00:00	4	2026-04-04 00:00:00	1200.00	0.00	1200.00	возвращено	-
199	45	51	6	2026-02-03 00:00:00	14	2026-02-17 00:00:00	7000.00	0.00	7000.00	возвращено	-
200	1	2	5	2026-01-26 00:00:00	14	2026-02-09 00:00:00	9800.00	0.00	9800.00	возвращено	-
201	13	40	5	2026-03-27 00:00:00	6	2026-04-02 00:00:00	4800.00	0.00	4800.00	возвращено	-
202	82	6	6	2026-03-18 00:00:00	4	2026-03-22 00:00:00	3200.00	0.00	3200.00	возвращено	-
203	8	42	6	2026-02-23 00:00:00	13	2026-03-08 00:00:00	10400.00	0.00	10400.00	возвращено	-
204	41	59	1	2026-02-12 00:00:00	6	2026-02-18 00:00:00	2400.00	0.00	2400.00	возвращено	-
205	36	37	6	2026-05-16 00:00:00	6	2026-05-22 00:00:00	3000.00	0.00	3000.00	возвращено	-
206	55	28	5	2026-03-22 00:00:00	13	2026-04-04 00:00:00	18200.00	0.00	18200.00	возвращено	-
207	83	55	7	2026-01-27 00:00:00	3	2026-01-30 00:00:00	1500.00	0.00	1500.00	возвращено	-
208	77	75	5	2026-04-20 00:00:00	12	2026-05-02 00:00:00	14400.00	0.00	14400.00	возвращено	-
209	77	69	6	2026-03-28 00:00:00	8	2026-04-05 00:00:00	4800.00	0.00	4800.00	возвращено	-
210	10	34	7	2026-05-18 00:00:00	12	2026-05-30 00:00:00	14400.00	0.00	14400.00	возвращено	-
211	38	73	6	2026-03-14 00:00:00	7	2026-03-21 00:00:00	5600.00	0.00	5600.00	возвращено	-
212	20	56	6	2026-01-26 00:00:00	13	2026-02-08 00:00:00	6500.00	0.00	6500.00	возвращено	-
213	100	74	7	2026-02-12 00:00:00	3	2026-02-15 00:00:00	1800.00	0.00	1800.00	возвращено	-
214	89	15	5	2026-03-09 00:00:00	7	2026-03-16 00:00:00	9800.00	0.00	9800.00	возвращено	-
215	32	24	6	2026-03-19 00:00:00	13	2026-04-01 00:00:00	6500.00	0.00	6500.00	возвращено	-
216	26	47	7	2026-01-20 00:00:00	11	2026-01-31 00:00:00	16500.00	0.00	16500.00	возвращено	-
217	25	32	5	2026-03-14 00:00:00	9	2026-03-23 00:00:00	9000.00	0.00	9000.00	возвращено	-
218	54	35	6	2026-04-11 00:00:00	9	2026-04-20 00:00:00	4500.00	0.00	4500.00	возвращено	-
219	2	20	6	2026-03-08 00:00:00	4	2026-03-12 00:00:00	1600.00	0.00	1600.00	возвращено	-
220	44	55	7	2026-03-02 00:00:00	3	2026-03-05 00:00:00	1500.00	0.00	1500.00	возвращено	-
221	63	77	7	2026-02-24 00:00:00	6	2026-03-02 00:00:00	3000.00	0.00	3000.00	возвращено	-
222	29	29	7	2026-04-25 00:00:00	11	2026-05-06 00:00:00	3300.00	0.00	3300.00	возвращено	-
223	56	17	5	2026-01-02 00:00:00	13	2026-01-15 00:00:00	6500.00	0.00	6500.00	возвращено	-
224	91	18	1	2026-02-27 00:00:00	5	2026-03-04 00:00:00	4000.00	0.00	4000.00	возвращено	-
225	32	57	7	2026-03-16 00:00:00	12	2026-03-28 00:00:00	6000.00	0.00	6000.00	возвращено	-
226	63	54	7	2026-02-10 00:00:00	14	2026-02-24 00:00:00	19600.00	0.00	19600.00	возвращено	-
227	97	22	7	2026-01-03 00:00:00	9	2026-01-12 00:00:00	9000.00	0.00	9000.00	возвращено	-
228	25	13	1	2026-02-12 00:00:00	9	2026-02-21 00:00:00	6300.00	0.00	6300.00	возвращено	-
229	54	32	5	2026-01-07 00:00:00	4	2026-01-11 00:00:00	4000.00	0.00	4000.00	возвращено	-
230	21	10	6	2026-04-15 00:00:00	7	2026-04-22 00:00:00	7000.00	0.00	7000.00	возвращено	-
231	59	70	6	2026-05-01 00:00:00	5	2026-05-06 00:00:00	9000.00	0.00	9000.00	возвращено	-
232	83	28	1	2026-02-09 00:00:00	4	2026-02-13 00:00:00	5600.00	0.00	5600.00	возвращено	-
233	34	6	5	2026-02-17 00:00:00	14	2026-03-03 00:00:00	11200.00	0.00	11200.00	возвращено	-
234	7	63	5	2026-04-17 00:00:00	5	2026-04-22 00:00:00	6000.00	0.00	6000.00	возвращено	-
235	8	18	6	2026-02-05 00:00:00	6	2026-02-11 00:00:00	4800.00	0.00	4800.00	возвращено	-
236	41	62	7	2026-04-16 00:00:00	11	2026-04-27 00:00:00	8800.00	0.00	8800.00	возвращено	-
237	18	45	5	2026-02-11 00:00:00	11	2026-02-22 00:00:00	16500.00	0.00	16500.00	возвращено	-
238	96	20	7	2026-03-29 00:00:00	3	2026-04-01 00:00:00	1200.00	0.00	1200.00	возвращено	-
239	40	21	7	2026-01-10 00:00:00	4	2026-01-14 00:00:00	2400.00	0.00	2400.00	возвращено	-
240	16	72	6	2026-01-29 00:00:00	10	2026-02-08 00:00:00	18000.00	0.00	18000.00	возвращено	-
241	11	41	6	2026-01-08 00:00:00	14	2026-01-22 00:00:00	16800.00	0.00	16800.00	возвращено	-
242	11	14	5	2026-01-24 00:00:00	12	2026-02-05 00:00:00	20400.00	0.00	20400.00	возвращено	-
243	54	5	6	2026-04-27 00:00:00	9	2026-05-06 00:00:00	4500.00	0.00	4500.00	возвращено	-
244	20	59	7	2026-02-07 00:00:00	5	2026-02-12 00:00:00	2000.00	0.00	2000.00	возвращено	-
245	77	10	7	2026-04-04 00:00:00	4	2026-04-08 00:00:00	4000.00	0.00	4000.00	возвращено	-
246	1	3	1	2026-01-16 00:00:00	6	2026-01-22 00:00:00	7200.00	0.00	7200.00	возвращено	-
247	24	37	1	2026-01-29 00:00:00	6	2026-02-04 00:00:00	3000.00	0.00	3000.00	возвращено	-
248	48	16	5	2026-05-10 00:00:00	1	2026-05-11 00:00:00	1000.00	0.00	1000.00	возвращено	-
249	53	74	5	2026-03-15 00:00:00	5	2026-03-20 00:00:00	3000.00	0.00	3000.00	возвращено	-
250	64	42	6	2026-04-13 00:00:00	4	2026-04-17 00:00:00	3200.00	0.00	3200.00	возвращено	-
251	19	64	6	2026-02-12 00:00:00	4	2026-02-16 00:00:00	2800.00	0.00	2800.00	возвращено	-
252	56	48	7	2026-03-30 00:00:00	11	2026-04-10 00:00:00	13200.00	0.00	13200.00	возвращено	-
253	79	32	1	2026-03-30 00:00:00	3	2026-04-02 00:00:00	3000.00	0.00	3000.00	возвращено	-
254	84	68	6	2026-04-20 00:00:00	12	2026-05-02 00:00:00	6000.00	0.00	6000.00	возвращено	-
255	62	31	7	2026-01-31 00:00:00	12	2026-02-12 00:00:00	7200.00	0.00	7200.00	возвращено	-
256	21	52	6	2026-03-03 00:00:00	6	2026-03-09 00:00:00	4200.00	0.00	4200.00	возвращено	-
257	19	66	6	2026-03-08 00:00:00	2	2026-03-10 00:00:00	1000.00	0.00	1000.00	возвращено	-
258	13	54	6	2026-02-04 00:00:00	7	2026-02-11 00:00:00	9800.00	0.00	9800.00	возвращено	-
259	45	14	7	2026-03-22 00:00:00	13	2026-04-04 00:00:00	22100.00	0.00	22100.00	возвращено	-
260	93	58	6	2026-05-15 00:00:00	5	2026-05-20 00:00:00	9000.00	0.00	9000.00	возвращено	-
261	94	35	5	2026-04-09 00:00:00	3	2026-04-12 00:00:00	1500.00	0.00	1500.00	возвращено	-
262	22	3	7	2026-02-22 00:00:00	2	2026-02-24 00:00:00	2400.00	0.00	2400.00	возвращено	-
263	18	16	5	2026-03-23 00:00:00	14	2026-04-06 00:00:00	14000.00	0.00	14000.00	возвращено	-
264	6	50	5	2026-04-22 00:00:00	5	2026-04-27 00:00:00	1250.00	0.00	1250.00	возвращено	-
265	76	29	6	2026-01-30 00:00:00	11	2026-02-10 00:00:00	3300.00	0.00	3300.00	возвращено	-
266	14	68	7	2026-03-18 00:00:00	6	2026-03-24 00:00:00	3000.00	0.00	3000.00	возвращено	-
267	6	67	5	2026-02-22 00:00:00	7	2026-03-01 00:00:00	3500.00	0.00	3500.00	возвращено	-
268	73	77	1	2026-02-07 00:00:00	1	2026-02-08 00:00:00	500.00	0.00	500.00	возвращено	-
269	71	65	7	2026-02-21 00:00:00	13	2026-03-06 00:00:00	9100.00	0.00	9100.00	возвращено	-
270	68	9	7	2026-03-04 00:00:00	4	2026-03-08 00:00:00	1600.00	0.00	1600.00	возвращено	-
271	27	25	7	2026-01-01 00:00:00	6	2026-01-07 00:00:00	4800.00	0.00	4800.00	возвращено	-
272	48	67	5	2026-05-04 00:00:00	6	2026-05-10 00:00:00	3000.00	0.00	3000.00	возвращено	-
273	74	43	1	2026-01-06 00:00:00	14	2026-01-20 00:00:00	7000.00	0.00	7000.00	возвращено	-
274	8	3	5	2026-01-12 00:00:00	11	2026-01-23 00:00:00	13200.00	0.00	13200.00	возвращено	-
275	17	75	5	2026-03-30 00:00:00	1	2026-03-31 00:00:00	1200.00	0.00	1200.00	возвращено	-
276	52	59	7	2026-05-20 00:00:00	1	2026-05-21 00:00:00	400.00	0.00	400.00	возвращено	-
277	77	30	1	2026-05-16 00:00:00	5	2026-05-21 00:00:00	2500.00	0.00	2500.00	возвращено	-
278	30	69	6	2026-03-22 00:00:00	4	2026-03-26 00:00:00	2400.00	0.00	2400.00	возвращено	-
279	67	8	6	2026-01-24 00:00:00	5	2026-01-29 00:00:00	2000.00	0.00	2000.00	возвращено	-
280	68	73	6	2026-03-01 00:00:00	10	2026-03-11 00:00:00	8000.00	0.00	8000.00	возвращено	-
281	81	50	1	2026-01-03 00:00:00	4	2026-01-07 00:00:00	1000.00	0.00	1000.00	возвращено	-
282	1	63	5	2026-02-16 00:00:00	8	2026-02-24 00:00:00	9600.00	0.00	9600.00	возвращено	-
283	63	56	6	2026-03-09 00:00:00	10	2026-03-19 00:00:00	5000.00	0.00	5000.00	возвращено	-
284	91	15	7	2026-03-21 00:00:00	7	2026-03-28 00:00:00	9800.00	0.00	9800.00	возвращено	-
285	8	7	6	2026-03-15 00:00:00	12	2026-03-27 00:00:00	9600.00	0.00	9600.00	возвращено	-
286	76	13	6	2026-03-19 00:00:00	8	2026-03-27 00:00:00	5600.00	0.00	5600.00	возвращено	-
287	18	55	6	2026-05-10 00:00:00	5	2026-05-15 00:00:00	2500.00	0.00	2500.00	возвращено	-
288	22	24	7	2026-02-27 00:00:00	13	2026-03-12 00:00:00	6500.00	0.00	6500.00	возвращено	-
289	76	36	1	2026-01-14 00:00:00	12	2026-01-26 00:00:00	3600.00	0.00	3600.00	возвращено	-
290	77	65	1	2026-02-11 00:00:00	8	2026-02-19 00:00:00	5600.00	0.00	5600.00	возвращено	-
291	12	69	5	2026-03-07 00:00:00	13	2026-03-20 00:00:00	7800.00	0.00	7800.00	возвращено	-
292	55	75	6	2026-02-12 00:00:00	11	2026-02-23 00:00:00	13200.00	0.00	13200.00	возвращено	-
293	28	38	1	2026-04-07 00:00:00	14	2026-04-21 00:00:00	49000.00	0.00	49000.00	возвращено	-
294	64	57	1	2026-02-04 00:00:00	2	2026-02-06 00:00:00	1000.00	0.00	1000.00	возвращено	-
295	51	71	5	2026-05-05 00:00:00	2	2026-05-07 00:00:00	2800.00	0.00	2800.00	возвращено	-
296	44	65	1	2026-04-16 00:00:00	3	2026-04-19 00:00:00	2100.00	0.00	2100.00	возвращено	-
297	3	43	6	2026-04-03 00:00:00	4	2026-04-07 00:00:00	2000.00	0.00	2000.00	возвращено	-
298	6	41	6	2026-04-25 00:00:00	5	2026-04-30 00:00:00	6000.00	0.00	6000.00	возвращено	-
299	81	40	7	2026-05-18 00:00:00	12	2026-05-30 00:00:00	9600.00	0.00	9600.00	возвращено	-
300	17	70	7	2026-01-25 00:00:00	7	2026-02-01 00:00:00	12600.00	0.00	12600.00	возвращено	-
301	35	69	5	2026-03-31 00:00:00	1	2026-04-01 00:00:00	600.00	0.00	600.00	возвращено	-
302	73	39	1	2026-04-13 00:00:00	13	2026-04-26 00:00:00	19500.00	0.00	19500.00	возвращено	-
303	58	15	5	2026-02-26 00:00:00	5	2026-03-03 00:00:00	7000.00	0.00	7000.00	возвращено	-
304	89	67	5	2026-04-09 00:00:00	5	2026-04-14 00:00:00	2500.00	0.00	2500.00	возвращено	-
305	59	75	6	2026-01-10 00:00:00	14	2026-01-24 00:00:00	16800.00	0.00	16800.00	возвращено	-
306	71	70	6	2026-02-05 00:00:00	14	2026-02-19 00:00:00	25200.00	0.00	25200.00	возвращено	-
307	54	60	1	2026-02-07 00:00:00	5	2026-02-12 00:00:00	2000.00	0.00	2000.00	возвращено	-
308	88	30	6	2026-02-12 00:00:00	7	2026-02-19 00:00:00	3500.00	0.00	3500.00	возвращено	-
309	2	18	6	2026-05-02 00:00:00	9	2026-05-11 00:00:00	7200.00	0.00	7200.00	возвращено	-
310	37	20	7	2026-04-01 00:00:00	5	2026-04-06 00:00:00	2000.00	0.00	2000.00	возвращено	-
311	27	21	1	2026-05-16 00:00:00	7	2026-05-23 00:00:00	4200.00	0.00	4200.00	возвращено	-
312	30	27	7	2026-02-07 00:00:00	6	2026-02-13 00:00:00	3000.00	0.00	3000.00	возвращено	-
313	48	50	5	2026-02-02 00:00:00	1	2026-02-03 00:00:00	250.00	0.00	250.00	возвращено	-
314	74	36	5	2026-02-04 00:00:00	5	2026-02-09 00:00:00	1500.00	0.00	1500.00	возвращено	-
315	100	21	1	2026-04-26 00:00:00	14	2026-05-10 00:00:00	8400.00	0.00	8400.00	возвращено	-
316	7	61	5	2026-05-13 00:00:00	3	2026-05-16 00:00:00	750.00	0.00	750.00	возвращено	-
317	99	2	6	2026-01-13 00:00:00	1	2026-01-14 00:00:00	700.00	0.00	700.00	возвращено	-
318	24	53	1	2026-05-11 00:00:00	7	2026-05-18 00:00:00	5600.00	0.00	5600.00	возвращено	-
319	49	46	1	2026-02-04 00:00:00	2	2026-02-06 00:00:00	1400.00	0.00	1400.00	возвращено	-
320	51	14	6	2026-04-05 00:00:00	12	2026-04-17 00:00:00	20400.00	0.00	20400.00	возвращено	-
321	4	24	6	2026-03-04 00:00:00	12	2026-03-16 00:00:00	6000.00	0.00	6000.00	возвращено	-
322	39	24	7	2026-02-15 00:00:00	7	2026-02-22 00:00:00	3500.00	0.00	3500.00	возвращено	-
323	14	30	6	2026-04-05 00:00:00	2	2026-04-07 00:00:00	1000.00	0.00	1000.00	возвращено	-
324	73	37	6	2026-04-28 00:00:00	6	2026-05-04 00:00:00	3000.00	0.00	3000.00	возвращено	-
325	13	17	1	2026-05-02 00:00:00	6	2026-05-08 00:00:00	3000.00	0.00	3000.00	возвращено	-
326	46	4	1	2026-04-12 00:00:00	12	2026-04-24 00:00:00	4800.00	0.00	4800.00	возвращено	-
327	70	59	1	2026-02-24 00:00:00	7	2026-03-03 00:00:00	2800.00	0.00	2800.00	возвращено	-
328	17	55	5	2026-01-18 00:00:00	1	2026-01-19 00:00:00	500.00	0.00	500.00	возвращено	-
329	95	71	6	2026-01-20 00:00:00	1	2026-01-21 00:00:00	1400.00	0.00	1400.00	возвращено	-
330	71	20	1	2026-02-10 00:00:00	12	2026-02-22 00:00:00	4800.00	0.00	4800.00	возвращено	-
331	61	66	1	2026-04-26 00:00:00	14	2026-05-10 00:00:00	7000.00	0.00	7000.00	возвращено	-
332	37	9	6	2026-02-18 00:00:00	8	2026-02-26 00:00:00	3200.00	0.00	3200.00	возвращено	-
333	21	56	6	2026-01-08 00:00:00	10	2026-01-18 00:00:00	5000.00	0.00	5000.00	возвращено	-
334	83	52	1	2026-01-17 00:00:00	12	2026-01-29 00:00:00	8400.00	0.00	8400.00	возвращено	-
335	96	66	6	2026-02-19 00:00:00	7	2026-02-26 00:00:00	3500.00	0.00	3500.00	возвращено	-
336	70	74	5	2026-02-27 00:00:00	3	2026-03-02 00:00:00	1800.00	0.00	1800.00	возвращено	-
337	57	50	5	2026-04-16 00:00:00	13	2026-04-29 00:00:00	3250.00	0.00	3250.00	возвращено	-
338	83	50	1	2026-02-08 00:00:00	2	2026-02-10 00:00:00	500.00	0.00	500.00	возвращено	-
339	8	20	5	2026-01-06 00:00:00	4	2026-01-10 00:00:00	1600.00	0.00	1600.00	возвращено	-
340	30	58	6	2026-04-28 00:00:00	12	2026-05-10 00:00:00	21600.00	0.00	21600.00	возвращено	-
341	79	19	6	2026-05-04 00:00:00	10	2026-05-14 00:00:00	8000.00	0.00	8000.00	возвращено	-
342	41	32	1	2026-04-10 00:00:00	8	2026-04-18 00:00:00	8000.00	0.00	8000.00	возвращено	-
343	46	8	7	2026-01-20 00:00:00	9	2026-01-29 00:00:00	3600.00	0.00	3600.00	возвращено	-
344	47	25	5	2026-03-01 00:00:00	2	2026-03-03 00:00:00	1600.00	0.00	1600.00	возвращено	-
345	93	63	6	2026-04-22 00:00:00	14	2026-05-06 00:00:00	16800.00	0.00	16800.00	возвращено	-
346	24	60	7	2026-03-11 00:00:00	1	2026-03-12 00:00:00	400.00	0.00	400.00	возвращено	-
347	87	58	1	2026-01-30 00:00:00	4	2026-02-03 00:00:00	7200.00	0.00	7200.00	возвращено	-
348	70	31	6	2026-05-14 00:00:00	2	2026-05-16 00:00:00	1200.00	0.00	1200.00	возвращено	-
349	40	15	7	2026-04-17 00:00:00	13	2026-04-30 00:00:00	18200.00	0.00	18200.00	возвращено	-
350	65	29	5	2026-04-12 00:00:00	13	2026-04-25 00:00:00	3900.00	0.00	3900.00	возвращено	-
351	68	66	1	2026-04-03 00:00:00	12	2026-04-15 00:00:00	6000.00	0.00	6000.00	возвращено	-
352	81	59	6	2026-02-23 00:00:00	5	2026-02-28 00:00:00	2000.00	0.00	2000.00	возвращено	-
353	40	1	5	2026-05-09 00:00:00	12	2026-05-21 00:00:00	6000.00	0.00	6000.00	возвращено	-
354	59	22	5	2026-02-16 00:00:00	11	2026-02-27 00:00:00	11000.00	0.00	11000.00	возвращено	-
355	88	52	7	2026-04-04 00:00:00	2	2026-04-06 00:00:00	1400.00	0.00	1400.00	возвращено	-
356	91	57	1	2026-03-30 00:00:00	5	2026-04-04 00:00:00	2500.00	0.00	2500.00	возвращено	-
357	89	54	6	2026-03-16 00:00:00	13	2026-03-29 00:00:00	18200.00	0.00	18200.00	возвращено	-
358	33	2	7	2026-01-02 00:00:00	4	2026-01-06 00:00:00	2800.00	0.00	2800.00	возвращено	-
359	16	3	7	2026-04-07 00:00:00	14	2026-04-21 00:00:00	16800.00	0.00	16800.00	возвращено	-
360	84	4	6	2026-05-15 00:00:00	11	2026-05-26 00:00:00	4400.00	0.00	4400.00	возвращено	-
361	80	20	1	2026-05-08 00:00:00	13	2026-05-21 00:00:00	5200.00	0.00	5200.00	возвращено	-
362	91	22	1	2026-05-10 00:00:00	12	2026-05-22 00:00:00	12000.00	0.00	12000.00	возвращено	-
363	40	15	5	2026-02-22 00:00:00	9	2026-03-03 00:00:00	12600.00	0.00	12600.00	возвращено	-
364	12	61	7	2026-04-29 00:00:00	14	2026-05-13 00:00:00	3500.00	0.00	3500.00	возвращено	-
365	10	77	5	2026-01-30 00:00:00	9	2026-02-08 00:00:00	4500.00	0.00	4500.00	возвращено	-
366	67	1	7	2026-02-04 00:00:00	5	2026-02-09 00:00:00	2500.00	0.00	2500.00	возвращено	-
367	14	63	1	2026-01-08 00:00:00	5	2026-01-13 00:00:00	6000.00	0.00	6000.00	возвращено	-
368	54	16	1	2026-03-18 00:00:00	9	2026-03-27 00:00:00	9000.00	0.00	9000.00	возвращено	-
369	97	24	6	2026-05-09 00:00:00	10	2026-05-19 00:00:00	5000.00	0.00	5000.00	возвращено	-
370	98	40	7	2026-04-12 00:00:00	5	2026-04-17 00:00:00	4000.00	0.00	4000.00	возвращено	-
371	21	56	7	2026-04-23 00:00:00	8	2026-05-01 00:00:00	4000.00	0.00	4000.00	возвращено	-
372	32	72	7	2026-02-08 00:00:00	11	2026-02-19 00:00:00	19800.00	0.00	19800.00	возвращено	-
373	50	45	6	2026-05-19 00:00:00	8	2026-05-27 00:00:00	12000.00	0.00	12000.00	возвращено	-
374	8	30	7	2026-05-06 00:00:00	7	2026-05-13 00:00:00	3500.00	0.00	3500.00	возвращено	-
375	42	32	5	2026-05-17 00:00:00	13	2026-05-30 00:00:00	13000.00	0.00	13000.00	возвращено	-
376	39	40	6	2026-02-10 00:00:00	9	2026-02-19 00:00:00	7200.00	0.00	7200.00	возвращено	-
377	37	71	6	2026-04-02 00:00:00	13	2026-04-15 00:00:00	18200.00	0.00	18200.00	возвращено	-
378	31	63	5	2026-03-22 00:00:00	11	2026-04-02 00:00:00	13200.00	0.00	13200.00	возвращено	-
379	96	8	5	2026-01-15 00:00:00	10	2026-01-25 00:00:00	4000.00	0.00	4000.00	возвращено	-
380	35	32	1	2026-04-18 00:00:00	12	2026-04-30 00:00:00	12000.00	0.00	12000.00	возвращено	-
381	49	67	5	2026-04-19 00:00:00	6	2026-04-25 00:00:00	3000.00	0.00	3000.00	возвращено	-
382	48	14	6	2026-01-20 00:00:00	4	2026-01-24 00:00:00	6800.00	0.00	6800.00	возвращено	-
383	90	20	5	2026-05-17 00:00:00	8	2026-05-25 00:00:00	3200.00	0.00	3200.00	возвращено	-
384	56	35	5	2026-03-24 00:00:00	1	2026-03-25 00:00:00	500.00	0.00	500.00	возвращено	-
385	67	70	1	2026-04-24 00:00:00	1	2026-04-25 00:00:00	1800.00	0.00	1800.00	возвращено	-
386	38	66	1	2026-01-12 00:00:00	4	2026-01-16 00:00:00	2000.00	0.00	2000.00	возвращено	-
387	40	44	5	2026-04-30 00:00:00	13	2026-05-13 00:00:00	7800.00	0.00	7800.00	возвращено	-
388	74	17	1	2026-03-24 00:00:00	2	2026-03-26 00:00:00	1000.00	0.00	1000.00	возвращено	-
389	83	55	5	2026-01-17 00:00:00	8	2026-01-25 00:00:00	4000.00	0.00	4000.00	возвращено	-
390	24	17	7	2026-01-25 00:00:00	13	2026-02-07 00:00:00	6500.00	0.00	6500.00	возвращено	-
391	87	5	1	2026-03-09 00:00:00	3	2026-03-12 00:00:00	1500.00	0.00	1500.00	возвращено	-
392	64	36	1	2026-02-09 00:00:00	10	2026-02-19 00:00:00	3000.00	0.00	3000.00	возвращено	-
393	5	36	5	2026-04-14 00:00:00	5	2026-04-19 00:00:00	1500.00	0.00	1500.00	возвращено	-
394	41	29	6	2026-04-17 00:00:00	5	2026-04-22 00:00:00	1500.00	0.00	1500.00	возвращено	-
395	89	7	7	2026-01-05 00:00:00	10	2026-01-15 00:00:00	8000.00	0.00	8000.00	возвращено	-
396	44	64	1	2026-03-29 00:00:00	3	2026-04-01 00:00:00	2100.00	0.00	2100.00	возвращено	-
397	62	12	5	2026-02-23 00:00:00	5	2026-02-28 00:00:00	2000.00	0.00	2000.00	возвращено	-
398	21	56	6	2026-01-22 00:00:00	14	2026-02-05 00:00:00	7000.00	0.00	7000.00	возвращено	-
399	88	9	6	2026-02-23 00:00:00	11	2026-03-06 00:00:00	4400.00	0.00	4400.00	возвращено	-
400	17	11	1	2026-03-13 00:00:00	1	2026-03-14 00:00:00	300.00	0.00	300.00	возвращено	-
401	97	33	1	2026-02-20 00:00:00	12	2026-03-04 00:00:00	4800.00	0.00	4800.00	возвращено	-
402	20	29	6	2026-02-06 00:00:00	11	2026-02-17 00:00:00	3300.00	0.00	3300.00	возвращено	-
403	53	20	7	2026-02-15 00:00:00	4	2026-02-19 00:00:00	1600.00	0.00	1600.00	возвращено	-
404	63	76	7	2026-01-08 00:00:00	13	2026-01-21 00:00:00	10400.00	0.00	10400.00	возвращено	-
405	35	6	1	2026-05-01 00:00:00	4	2026-05-05 00:00:00	3200.00	0.00	3200.00	возвращено	-
406	49	59	5	2026-01-29 00:00:00	7	2026-02-05 00:00:00	2800.00	0.00	2800.00	возвращено	-
407	96	13	6	2026-02-11 00:00:00	10	2026-02-21 00:00:00	7000.00	0.00	7000.00	возвращено	-
408	25	62	1	2026-05-06 00:00:00	14	2026-05-20 00:00:00	11200.00	0.00	11200.00	возвращено	-
409	18	18	1	2026-01-10 00:00:00	5	2026-01-15 00:00:00	4000.00	0.00	4000.00	возвращено	-
410	84	10	7	2026-03-12 00:00:00	1	2026-03-13 00:00:00	1000.00	0.00	1000.00	возвращено	-
411	86	6	6	2026-01-16 00:00:00	11	2026-01-27 00:00:00	8800.00	0.00	8800.00	возвращено	-
412	55	44	1	2026-02-10 00:00:00	13	2026-02-23 00:00:00	7800.00	0.00	7800.00	возвращено	-
413	69	17	6	2026-01-22 00:00:00	7	2026-01-29 00:00:00	3500.00	0.00	3500.00	возвращено	-
414	1	17	1	2026-01-11 00:00:00	4	2026-01-15 00:00:00	2000.00	0.00	2000.00	возвращено	-
415	15	72	1	2026-05-12 00:00:00	3	2026-05-15 00:00:00	5400.00	0.00	5400.00	возвращено	-
416	17	36	7	2026-03-14 00:00:00	14	2026-03-28 00:00:00	4200.00	0.00	4200.00	возвращено	-
417	43	29	5	2026-03-16 00:00:00	12	2026-03-28 00:00:00	3600.00	0.00	3600.00	возвращено	-
418	12	41	7	2026-02-25 00:00:00	3	2026-02-28 00:00:00	3600.00	0.00	3600.00	возвращено	-
419	57	18	7	2026-03-05 00:00:00	8	2026-03-13 00:00:00	6400.00	0.00	6400.00	возвращено	-
420	83	1	6	2026-03-10 00:00:00	4	2026-03-14 00:00:00	2000.00	0.00	2000.00	возвращено	-
421	40	61	1	2026-04-27 00:00:00	8	2026-05-05 00:00:00	2000.00	0.00	2000.00	возвращено	-
422	15	59	5	2026-04-25 00:00:00	14	2026-05-09 00:00:00	5600.00	0.00	5600.00	возвращено	-
423	76	37	6	2026-04-05 00:00:00	5	2026-04-10 00:00:00	2500.00	0.00	2500.00	возвращено	-
424	35	18	1	2026-05-04 00:00:00	6	2026-05-10 00:00:00	4800.00	0.00	4800.00	возвращено	-
425	38	36	7	2026-03-24 00:00:00	3	2026-03-27 00:00:00	900.00	0.00	900.00	возвращено	-
426	98	63	6	2026-02-08 00:00:00	2	2026-02-10 00:00:00	2400.00	0.00	2400.00	возвращено	-
427	95	66	6	2026-05-19 00:00:00	14	2026-06-02 00:00:00	7000.00	0.00	7000.00	возвращено	-
428	90	23	6	2026-05-06 00:00:00	2	2026-05-08 00:00:00	1000.00	0.00	1000.00	возвращено	-
429	49	32	7	2026-03-06 00:00:00	5	2026-03-11 00:00:00	5000.00	0.00	5000.00	возвращено	-
430	73	67	1	2026-03-11 00:00:00	10	2026-03-21 00:00:00	5000.00	0.00	5000.00	возвращено	-
431	10	28	5	2026-04-18 00:00:00	4	2026-04-22 00:00:00	5600.00	0.00	5600.00	возвращено	-
432	34	75	7	2026-04-01 00:00:00	5	2026-04-06 00:00:00	6000.00	0.00	6000.00	возвращено	-
433	25	25	6	2026-03-12 00:00:00	1	2026-03-13 00:00:00	800.00	0.00	800.00	возвращено	-
434	92	67	5	2026-02-14 00:00:00	9	2026-02-23 00:00:00	4500.00	0.00	4500.00	возвращено	-
435	59	70	6	2026-05-12 00:00:00	14	2026-05-26 00:00:00	25200.00	0.00	25200.00	возвращено	-
436	4	66	5	2026-02-10 00:00:00	8	2026-02-18 00:00:00	4000.00	0.00	4000.00	возвращено	-
437	68	66	6	2026-01-17 00:00:00	14	2026-01-31 00:00:00	7000.00	0.00	7000.00	возвращено	-
438	2	71	7	2026-01-19 00:00:00	11	2026-01-30 00:00:00	15400.00	0.00	15400.00	возвращено	-
439	37	5	5	2026-01-05 00:00:00	11	2026-01-16 00:00:00	5500.00	0.00	5500.00	возвращено	-
440	58	65	7	2026-02-26 00:00:00	14	2026-03-12 00:00:00	9800.00	0.00	9800.00	возвращено	-
441	2	43	1	2026-01-05 00:00:00	3	2026-01-08 00:00:00	1500.00	0.00	1500.00	возвращено	-
442	46	45	1	2026-04-16 00:00:00	8	2026-04-24 00:00:00	12000.00	0.00	12000.00	возвращено	-
443	11	25	7	2026-01-25 00:00:00	10	2026-02-04 00:00:00	8000.00	0.00	8000.00	возвращено	-
444	17	22	6	2026-04-19 00:00:00	1	2026-04-20 00:00:00	1000.00	0.00	1000.00	возвращено	-
445	89	77	6	2026-05-02 00:00:00	1	2026-05-03 00:00:00	500.00	0.00	500.00	возвращено	-
446	96	76	6	2026-04-22 00:00:00	4	2026-04-26 00:00:00	3200.00	0.00	3200.00	возвращено	-
447	74	20	7	2026-04-20 00:00:00	2	2026-04-22 00:00:00	800.00	0.00	800.00	возвращено	-
448	39	3	7	2026-03-19 00:00:00	10	2026-03-29 00:00:00	12000.00	0.00	12000.00	возвращено	-
449	13	47	5	2026-03-16 00:00:00	12	2026-03-28 00:00:00	18000.00	0.00	18000.00	возвращено	-
450	28	22	5	2026-05-19 00:00:00	8	2026-05-27 00:00:00	8000.00	0.00	8000.00	возвращено	-
451	30	53	1	2026-01-25 00:00:00	6	2026-01-31 00:00:00	4800.00	0.00	4800.00	возвращено	-
452	40	36	1	2026-01-27 00:00:00	11	2026-02-07 00:00:00	3300.00	0.00	3300.00	возвращено	-
453	81	75	6	2026-03-05 00:00:00	4	2026-03-09 00:00:00	4800.00	0.00	4800.00	возвращено	-
454	4	36	1	2026-04-07 00:00:00	12	2026-04-19 00:00:00	3600.00	0.00	3600.00	возвращено	-
455	68	75	5	2026-01-21 00:00:00	2	2026-01-23 00:00:00	2400.00	0.00	2400.00	возвращено	-
456	23	39	7	2026-01-02 00:00:00	14	2026-01-16 00:00:00	21000.00	0.00	21000.00	возвращено	-
457	88	49	5	2026-02-12 00:00:00	9	2026-02-21 00:00:00	4500.00	0.00	4500.00	возвращено	-
458	44	5	6	2026-04-29 00:00:00	10	2026-05-09 00:00:00	5000.00	0.00	5000.00	возвращено	-
459	43	75	5	2026-03-22 00:00:00	14	2026-04-05 00:00:00	16800.00	0.00	16800.00	возвращено	-
460	15	3	1	2026-01-06 00:00:00	1	2026-01-07 00:00:00	1200.00	0.00	1200.00	возвращено	-
461	24	71	7	2026-04-16 00:00:00	11	2026-04-27 00:00:00	15400.00	0.00	15400.00	возвращено	-
462	70	67	1	2026-03-03 00:00:00	8	2026-03-11 00:00:00	4000.00	0.00	4000.00	возвращено	-
463	74	31	6	2026-01-13 00:00:00	14	2026-01-27 00:00:00	8400.00	0.00	8400.00	возвращено	-
464	54	37	1	2026-05-10 00:00:00	8	2026-05-18 00:00:00	4000.00	0.00	4000.00	возвращено	-
465	56	66	5	2026-04-24 00:00:00	5	2026-04-29 00:00:00	2500.00	0.00	2500.00	возвращено	-
466	13	35	7	2026-02-28 00:00:00	2	2026-03-02 00:00:00	1000.00	0.00	1000.00	возвращено	-
467	10	17	1	2026-01-28 00:00:00	13	2026-02-10 00:00:00	6500.00	0.00	6500.00	возвращено	-
468	3	20	5	2026-05-03 00:00:00	13	2026-05-16 00:00:00	5200.00	0.00	5200.00	возвращено	-
469	17	28	7	2026-03-28 00:00:00	2	2026-03-30 00:00:00	2800.00	0.00	2800.00	возвращено	-
470	29	72	5	2026-03-16 00:00:00	4	2026-03-20 00:00:00	7200.00	0.00	7200.00	возвращено	-
471	21	40	1	2026-04-03 00:00:00	2	2026-04-05 00:00:00	1600.00	0.00	1600.00	возвращено	-
472	32	3	7	2026-01-08 00:00:00	12	2026-01-20 00:00:00	14400.00	0.00	14400.00	возвращено	-
473	85	18	5	2026-04-12 00:00:00	3	2026-04-15 00:00:00	2400.00	0.00	2400.00	возвращено	-
474	23	60	6	2026-03-24 00:00:00	13	2026-04-06 00:00:00	5200.00	0.00	5200.00	возвращено	-
475	32	45	6	2026-01-06 00:00:00	1	2026-01-07 00:00:00	1500.00	0.00	1500.00	возвращено	-
476	28	71	5	2026-02-02 00:00:00	12	2026-02-14 00:00:00	16800.00	0.00	16800.00	возвращено	-
477	10	60	7	2026-04-10 00:00:00	1	2026-04-11 00:00:00	400.00	0.00	400.00	возвращено	-
478	93	26	6	2026-01-22 00:00:00	9	2026-01-31 00:00:00	6300.00	0.00	6300.00	возвращено	-
479	3	16	5	2026-02-14 00:00:00	6	2026-02-20 00:00:00	6000.00	0.00	6000.00	возвращено	-
480	77	71	5	2026-02-09 00:00:00	5	2026-02-14 00:00:00	7000.00	0.00	7000.00	возвращено	-
481	98	75	6	2026-03-04 00:00:00	5	2026-03-09 00:00:00	6000.00	0.00	6000.00	возвращено	-
482	10	23	7	2026-03-02 00:00:00	6	2026-03-08 00:00:00	3000.00	0.00	3000.00	возвращено	-
483	94	75	7	2026-02-12 00:00:00	14	2026-02-26 00:00:00	16800.00	0.00	16800.00	возвращено	-
484	55	14	6	2026-04-28 00:00:00	1	2026-04-29 00:00:00	1700.00	0.00	1700.00	возвращено	-
485	67	16	7	2026-01-30 00:00:00	7	2026-02-06 00:00:00	7000.00	0.00	7000.00	возвращено	-
486	71	17	5	2026-03-28 00:00:00	11	2026-04-08 00:00:00	5500.00	0.00	5500.00	возвращено	-
487	8	6	6	2026-01-27 00:00:00	11	2026-02-07 00:00:00	8800.00	0.00	8800.00	возвращено	-
488	67	16	5	2026-03-08 00:00:00	1	2026-03-09 00:00:00	1000.00	0.00	1000.00	возвращено	-
489	17	77	5	2026-02-19 00:00:00	8	2026-02-27 00:00:00	4000.00	0.00	4000.00	возвращено	-
490	82	40	6	2026-04-15 00:00:00	5	2026-04-20 00:00:00	4000.00	0.00	4000.00	возвращено	-
491	78	4	6	2026-05-08 00:00:00	7	2026-05-15 00:00:00	2800.00	0.00	2800.00	возвращено	-
492	100	46	7	2026-02-23 00:00:00	7	2026-03-02 00:00:00	4900.00	0.00	4900.00	возвращено	-
493	81	7	1	2026-02-08 00:00:00	12	2026-02-20 00:00:00	9600.00	0.00	9600.00	возвращено	-
494	54	58	7	2026-05-17 00:00:00	1	2026-05-18 00:00:00	1800.00	0.00	1800.00	возвращено	-
495	10	45	1	2026-02-13 00:00:00	10	2026-02-23 00:00:00	15000.00	0.00	15000.00	возвращено	-
496	12	72	1	2026-02-28 00:00:00	8	2026-03-08 00:00:00	14400.00	0.00	14400.00	возвращено	-
497	70	54	5	2026-04-13 00:00:00	4	2026-04-17 00:00:00	5600.00	0.00	5600.00	возвращено	-
498	41	67	1	2026-04-15 00:00:00	5	2026-04-20 00:00:00	2500.00	0.00	2500.00	возвращено	-
499	76	38	7	2026-05-14 00:00:00	1	2026-05-15 00:00:00	3500.00	0.00	3500.00	возвращено	-
500	26	68	7	2026-04-24 00:00:00	5	2026-04-29 00:00:00	2500.00	0.00	2500.00	возвращено	-
501	6	35	1	2026-06-01 05:11:24.622316	2	2026-06-03 05:11:24.622316	1000.00	0.00	1000.00	оплачено	Приедет утром
503	49	35	1	2026-06-01 05:13:32.15092	3	2026-06-04 05:13:32.15092	1500.00	60.00	600.00	оплачено	Вернет утром
502	1	1	1	2026-06-01 05:12:20.03823	4	2026-06-05 05:12:20.03823	2000.00	0.00	2000.00	неоплачено	Вернет вечером
\.


--
-- Data for Name: passport; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.passport (id, p_number, p_home) FROM stdin;
1	4501 123456	г. Великий Новгород, ул. Большая Московская, д. 1, кв. 1
2	4501 123457	г. Великий Новгород, ул. Большая Московская, д. 2, кв. 2
3	4501 123458	г. Великий Новгород, ул. Большая Московская, д. 3, кв. 3
4	4501 123459	г. Великий Новгород, ул. Большая Московская, д. 4, кв. 4
5	4501 123460	г. Великий Новгород, ул. Большая Московская, д. 5, кв. 5
6	4501 123461	г. Великий Новгород, ул. Большая Московская, д. 6, кв. 6
7	4501 123462	г. Великий Новгород, ул. Большая Московская, д. 7, кв. 7
8	4501 123463	г. Великий Новгород, ул. Большая Московская, д. 8, кв. 8
9	4501 123464	г. Великий Новгород, ул. Большая Московская, д. 9, кв. 9
10	4501 123465	г. Великий Новгород, ул. Большая Московская, д. 10, кв. 10
11	4501 123466	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 1, кв. 1
12	4501 123467	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 2, кв. 2
13	4501 123468	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 3, кв. 3
14	4501 123469	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 4, кв. 4
15	4501 123470	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 5, кв. 5
16	4501 123471	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 6, кв. 6
17	4501 123472	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 7, кв. 7
18	4501 123473	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 8, кв. 8
19	4501 123474	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 9, кв. 9
20	4501 123475	г. Великий Новгород, ул. Большая Санкт-Петербургская, д. 10, кв. 10
21	4501 123476	г. Великий Новгород, ул. Псковская, д. 1, кв. 1
22	4501 123477	г. Великий Новгород, ул. Псковская, д. 2, кв. 2
23	4501 123478	г. Великий Новгород, ул. Псковская, д. 3, кв. 3
24	4501 123479	г. Великий Новгород, ул. Псковская, д. 4, кв. 4
25	4501 123480	г. Великий Новгород, ул. Псковская, д. 5, кв. 5
26	4501 123481	г. Великий Новгород, ул. Псковская, д. 6, кв. 6
27	4501 123482	г. Великий Новгород, ул. Псковская, д. 7, кв. 7
28	4501 123483	г. Великий Новгород, ул. Псковская, д. 8, кв. 8
29	4501 123484	г. Великий Новгород, ул. Псковская, д. 9, кв. 9
30	4501 123485	г. Великий Новгород, ул. Псковская, д. 10, кв. 10
31	4501 123486	г. Великий Новгород, ул. Германа, д. 1, кв. 1
32	4501 123487	г. Великий Новгород, ул. Германа, д. 2, кв. 2
33	4501 123488	г. Великий Новгород, ул. Германа, д. 3, кв. 3
34	4501 123489	г. Великий Новгород, ул. Германа, д. 4, кв. 4
35	4501 123490	г. Великий Новгород, ул. Германа, д. 5, кв. 5
36	4501 123491	г. Великий Новгород, ул. Германа, д. 6, кв. 6
37	4501 123492	г. Великий Новгород, ул. Германа, д. 7, кв. 7
38	4501 123493	г. Великий Новгород, ул. Германа, д. 8, кв. 8
39	4501 123494	г. Великий Новгород, ул. Германа, д. 9, кв. 9
40	4501 123495	г. Великий Новгород, ул. Германа, д. 10, кв. 10
41	4501 123496	г. Великий Новгород, ул. Новолучанская, д. 1, кв. 1
42	4501 123497	г. Великий Новгород, ул. Новолучанская, д. 2, кв. 2
43	4501 123498	г. Великий Новгород, ул. Новолучанская, д. 3, кв. 3
44	4501 123499	г. Великий Новгород, ул. Новолучанская, д. 4, кв. 4
45	4501 123500	г. Великий Новгород, ул. Новолучанская, д. 5, кв. 5
46	4501 123501	г. Великий Новгород, ул. Новолучанская, д. 6, кв. 6
47	4501 123502	г. Великий Новгород, ул. Новолучанская, д. 7, кв. 7
48	4501 123503	г. Великий Новгород, ул. Новолучанская, д. 8, кв. 8
49	4501 123504	г. Великий Новгород, ул. Новолучанская, д. 9, кв. 9
50	4501 123505	г. Великий Новгород, ул. Новолучанская, д. 10, кв. 10
51	4501 123506	г. Великий Новгород, ул. Кочетова, д. 1, кв. 1
52	4501 123507	г. Великий Новгород, ул. Кочетова, д. 2, кв. 2
53	4501 123508	г. Великий Новгород, ул. Кочетова, д. 3, кв. 3
54	4501 123509	г. Великий Новгород, ул. Кочетова, д. 4, кв. 4
55	4501 123510	г. Великий Новгород, ул. Кочетова, д. 5, кв. 5
56	4501 123511	г. Великий Новгород, ул. Кочетова, д. 6, кв. 6
57	4501 123512	г. Великий Новгород, ул. Кочетова, д. 7, кв. 7
58	4501 123513	г. Великий Новгород, ул. Кочетова, д. 8, кв. 8
59	4501 123514	г. Великий Новгород, ул. Кочетова, д. 9, кв. 9
60	4501 123515	г. Великий Новгород, ул. Кочетова, д. 10, кв. 10
61	4501 123516	г. Боровичи, ул. Коммунарная, д. 1, кв. 1
62	4501 123517	г. Боровичи, ул. Коммунарная, д. 2, кв. 2
63	4501 123518	г. Боровичи, ул. Коммунарная, д. 3, кв. 3
64	4501 123519	г. Боровичи, ул. Коммунарная, д. 4, кв. 4
65	4501 123520	г. Боровичи, ул. Коммунарная, д. 5, кв. 5
66	4501 123521	г. Старая Русса, ул. Возрождения, д. 1, кв. 1
67	4501 123522	г. Старая Русса, ул. Возрождения, д. 2, кв. 2
68	4501 123523	г. Старая Русса, ул. Возрождения, д. 3, кв. 3
69	4501 123524	г. Старая Русса, ул. Возрождения, д. 4, кв. 4
70	4501 123525	г. Старая Русса, ул. Возрождения, д. 5, кв. 5
71	4501 123526	г. Валдай, ул. Ватутина, д. 1, кв. 1
72	4501 123527	г. Валдай, ул. Ватутина, д. 2, кв. 2
73	4501 123528	г. Валдай, ул. Ватутина, д. 3, кв. 3
74	4501 123529	г. Валдай, ул. Ватутина, д. 4, кв. 4
75	4501 123530	г. Валдай, ул. Ватутина, д. 5, кв. 5
76	4501 123531	г. Чудово, ул. Некрасова, д. 1, кв. 1
77	4501 123532	г. Чудово, ул. Некрасова, д. 2, кв. 2
78	4501 123533	г. Чудово, ул. Некрасова, д. 3, кв. 3
79	4501 123534	г. Чудово, ул. Некрасова, д. 4, кв. 4
80	4501 123535	г. Чудово, ул. Некрасова, д. 5, кв. 5
81	4501 123536	г. Малая Вишера, ул. Красная, д. 1, кв. 1
82	4501 123537	г. Малая Вишера, ул. Красная, д. 2, кв. 2
83	4501 123538	г. Малая Вишера, ул. Красная, д. 3, кв. 3
84	4501 123539	г. Малая Вишера, ул. Красная, д. 4, кв. 4
85	4501 123540	г. Малая Вишера, ул. Красная, д. 5, кв. 5
86	4501 123541	д. Бронница, Новгородский р-н, ул. Центральная, д. 1
87	4501 123542	д. Бронница, Новгородский р-н, ул. Центральная, д. 2
88	4501 123543	д. Бронница, Новгородский р-н, ул. Центральная, д. 3
89	4501 123544	д. Бронница, Новгородский р-н, ул. Центральная, д. 4
90	4501 123545	д. Бронница, Новгородский р-н, ул. Центральная, д. 5
91	4501 123546	д. Сырково, Новгородский р-н, ул. Дачная, д. 1
92	4501 123547	д. Сырково, Новгородский р-н, ул. Дачная, д. 2
93	4501 123548	д. Сырково, Новгородский р-н, ул. Дачная, д. 3
94	4501 123549	д. Сырково, Новгородский р-н, ул. Дачная, д. 4
95	4501 123550	д. Сырково, Новгородский р-н, ул. Дачная, д. 5
96	4501 123551	д. Григорово, Новгородский р-н, ул. Садовая, д. 1
97	4501 123552	д. Григорово, Новгородский р-н, ул. Садовая, д. 2
98	4501 123553	д. Григорово, Новгородский р-н, ул. Садовая, д. 3
99	4501 123554	д. Григорово, Новгородский р-н, ул. Садовая, д. 4
100	4501 123555	д. Григорово, Новгородский р-н, ул. Садовая, д. 5
101	4444 666666	г. Минск ул. Победы д. 4
\.


--
-- Data for Name: price_history; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.price_history (id, id_instrument, old_price, new_price, change_date, changed_by) FROM stdin;
1	2	500.00	700.00	2026-05-30 19:12:16.921411	\N
2	1	500.00	700.00	2026-06-01 05:15:59.914896	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: summer_cp; Owner: postgres
--

COPY summer_cp.users (id, u_name, u_password, u_role) FROM stdin;
1	user	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	сотрудник
5	admin	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	администратор
6	highuser	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	старший сотрудник
7	isnap	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	старший сотрудник
8	lolo	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	старший сотрудник
\.


--
-- Name: customer_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.customer_id_seq', 101, true);


--
-- Name: instrument_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.instrument_id_seq', 78, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.orders_id_seq', 503, true);


--
-- Name: passport_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.passport_id_seq', 101, true);


--
-- Name: price_history_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.price_history_id_seq', 2, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: summer_cp; Owner: postgres
--

SELECT pg_catalog.setval('summer_cp.users_id_seq', 8, true);


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
-- Name: passport passport_p_number_key; Type: CONSTRAINT; Schema: summer_cp; Owner: postgres
--

ALTER TABLE ONLY summer_cp.passport
    ADD CONSTRAINT passport_p_number_key UNIQUE (p_number);


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
-- PostgreSQL database dump complete
--

\unrestrict PTUnXLRHFhrOV3DdoWrOaZIxTSiQSb47SmPA1L80fd0stKBvIte2NfCAhrQO47a

