create extension if not exists pgcrypto;

--

create or replace function encrypt_data(data text)
returns bytea as $$
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
$$ language plpgsql;

create or replace function decrypt_data(data bytea)
returns text as $$
begin
    if data is null then
        return null;
    end if;
    return convert_from(
        decrypt(data, digest('my_super_secret_key_2024', 'sha256'), 'aes-cbc/pad:pkcs'),
        'utf8'
    );
end;
$$ language plpgsql;

--

-- сначала добавим временные колонки
alter table passport add column p_number_encrypted bytea;
alter table passport add column p_home_encrypted bytea;

-- переносим данные с шифрованием
update passport set 
    p_number_encrypted = encrypt_data(p_number),
    p_home_encrypted = encrypt_data(p_home);

-- удаляем старые колонки
alter table passport drop column p_number;
alter table passport drop column p_home;

-- переименовываем новые колонки
alter table passport rename column p_number_encrypted to p_number;
alter table passport rename column p_home_encrypted to p_home;

--

create view passport_decrypted as
select 
    id,
    decrypt_data(p_number) as p_number,
    decrypt_data(p_home) as p_home
from passport;

--

create or replace function encrypt_passport_trigger()
returns trigger as $$
begin
    if new.p_number is not null and pg_typeof(new.p_number) = 'text'::regtype then
        new.p_number := encrypt_data(new.p_number);
    end if;
    if new.p_home is not null and pg_typeof(new.p_home) = 'text'::regtype then
        new.p_home := encrypt_data(new.p_home);
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_encrypt_passport
before insert or update on passport
for each row
execute function encrypt_passport_trigger();

--

create or replace view customers_with_passport as
select 
    c.id,
    c.l_name,
    c.f_name,
    c.v_name,
    c.phone,
    decrypt_data(p.p_number) as passport_number,
    decrypt_data(p.p_home) as passport_home
from customer c
join passport p on c.id_passport = p.id;

---новое
create or replace function decrypt_data(data bytea)
returns text as $$
begin
    if data is null then
        return null;
    end if;
    return convert_from(
        decrypt(data, digest('my_super_secret_key_2024', 'sha256'), 'aes-cbc/pad:pkcs'),
        'utf8'
    );
end;
$$ language plpgsql;