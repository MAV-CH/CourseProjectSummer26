CREATE OR REPLACE FUNCTION calculate_full_price()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_full_price ON orders;
CREATE TRIGGER trg_calculate_full_price
BEFORE INSERT OR UPDATE OF id_instrument, count_days, discount ON orders
FOR EACH ROW
EXECUTE FUNCTION calculate_full_price();

---

create or replace function calculate_finish_date()
returns trigger as $$
begin
    new.finish_date := new.start_date + (new.count_days || ' days')::interval;
    return new;
end;
$$ language plpgsql;

create trigger trg_calculate_finish_date
before insert or update of start_date, count_days on orders
for each row
execute function calculate_finish_date();

-- новая функция для истории цен
create or replace function log_price_change()
returns trigger as $$
begin
    if old.price != new.price then
        insert into price_history (id_instrument, old_price, new_price, changed_by)
        values (new.id, old.price, new.price, current_user_id());
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_log_price_change
after update of price on instrument
for each row
execute function log_price_change();

-- функция для получения ID текущего пользователя
create or replace function current_user_id()
returns int as $$
begin
    return null;
end;
$$ language plpgsql;
