-- نظام إدارة المتجر | Supabase PostgreSQL
create extension if not exists pgcrypto;

create table if not exists roles (
 id uuid primary key default gen_random_uuid(),
 name text unique not null,
 permissions jsonb not null default '{}'::jsonb
);
create table if not exists profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 phone text,
 role_id uuid references roles(id),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists settings (
 key text primary key,
 value jsonb not null
);
create table if not exists categories (id uuid primary key default gen_random_uuid(), name text not null unique, active boolean default true);
create table if not exists brands (id uuid primary key default gen_random_uuid(), name text not null unique, active boolean default true);
create table if not exists units (id uuid primary key default gen_random_uuid(), name text not null unique, active boolean default true);
create table if not exists warehouses (id uuid primary key default gen_random_uuid(), name text not null unique, location text, active boolean default true);
create table if not exists products (
 id uuid primary key default gen_random_uuid(), name text not null, image_url text, sku text unique,
 barcode text unique, category_id uuid references categories(id), brand_id uuid references brands(id),
 unit_id uuid references units(id), purchase_price numeric(14,3) not null default 0,
 avg_cost numeric(14,3) not null default 0, retail_price numeric(14,3) not null default 0,
 wholesale_price numeric(14,3) not null default 0, discount numeric(14,3) not null default 0,
 tax_rate numeric(7,3) not null default 0, qty numeric(14,3) not null default 0,
 min_stock numeric(14,3) not null default 0, max_stock numeric(14,3),
 location text, supplier_id uuid, active boolean not null default true,
 notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists customers (
 id uuid primary key default gen_random_uuid(), name text not null, phone text, email text, address text,
 balance numeric(14,3) not null default 0, credit_limit numeric(14,3) not null default 0,
 notes text, created_at timestamptz not null default now()
);
create table if not exists suppliers (
 id uuid primary key default gen_random_uuid(), name text not null, phone text, email text, address text,
 balance numeric(14,3) not null default 0, notes text, created_at timestamptz not null default now()
);
alter table products drop constraint if exists products_supplier_id_fkey;
alter table products add constraint products_supplier_id_fkey foreign key (supplier_id) references suppliers(id);

create table if not exists payment_methods (id uuid primary key default gen_random_uuid(), name text not null unique, active boolean default true);
create table if not exists sales (
 id uuid primary key default gen_random_uuid(), invoice_no text unique not null, customer_id uuid references customers(id),
 subtotal numeric(14,3) not null default 0, discount numeric(14,3) not null default 0, tax numeric(14,3) not null default 0,
 total numeric(14,3) not null default 0, paid numeric(14,3) not null default 0, due numeric(14,3) not null default 0,
 payment_method_id uuid references payment_methods(id), status text not null default 'posted',
 notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists sale_items (
 id uuid primary key default gen_random_uuid(), sale_id uuid not null references sales(id) on delete cascade,
 product_id uuid not null references products(id), qty numeric(14,3) not null, price numeric(14,3) not null,
 discount numeric(14,3) not null default 0, tax numeric(14,3) not null default 0,
 cost numeric(14,3) not null default 0
);
create table if not exists purchases (
 id uuid primary key default gen_random_uuid(), invoice_no text unique not null, supplier_id uuid references suppliers(id),
 subtotal numeric(14,3) not null default 0, discount numeric(14,3) not null default 0, tax numeric(14,3) not null default 0,
 total numeric(14,3) not null default 0, paid numeric(14,3) not null default 0, due numeric(14,3) not null default 0,
 payment_method_id uuid references payment_methods(id), status text not null default 'posted',
 notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists purchase_items (
 id uuid primary key default gen_random_uuid(), purchase_id uuid not null references purchases(id) on delete cascade,
 product_id uuid not null references products(id), qty numeric(14,3) not null, price numeric(14,3) not null,
 discount numeric(14,3) not null default 0, tax numeric(14,3) not null default 0
);
create table if not exists expenses (
 id uuid primary key default gen_random_uuid(), category_id uuid, amount numeric(14,3) not null,
 payment_method_id uuid references payment_methods(id), expense_date date not null default current_date,
 description text, attachment_url text, notes text, created_by uuid references auth.users(id), created_at timestamptz default now()
);
create table if not exists expense_categories (id uuid primary key default gen_random_uuid(), name text unique not null, active boolean default true);
alter table expenses add constraint expenses_category_id_fkey foreign key (category_id) references expense_categories(id);

create table if not exists stock_movements (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references products(id),
 movement_type text not null, qty numeric(14,3) not null, balance_after numeric(14,3) not null,
 reference_type text, reference_id uuid, notes text, created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists payments (
 id uuid primary key default gen_random_uuid(), direction text not null check(direction in ('customer','supplier')),
 customer_id uuid references customers(id), supplier_id uuid references suppliers(id),
 amount numeric(14,3) not null, payment_method_id uuid references payment_methods(id),
 reference_id uuid, notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists audit_logs (
 id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id), action text not null,
 section text, document_id uuid, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
create table if not exists notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id),
 type text not null, title text not null, body text, read boolean default false, created_at timestamptz default now()
);

insert into roles(name,permissions) values
('مدير','{"all":true}'),
('محاسب','{"dashboard":true,"sales":true,"purchases":true,"expenses":true,"customers":true,"suppliers":true,"reports":true}'),
('موظف مبيعات','{"dashboard":true,"sales":true,"customers":true}'),
('موظف مخزون','{"dashboard":true,"products":true,"inventory":true,"purchases":true}'),
('موظف','{"dashboard":true}')
on conflict(name) do nothing;

insert into payment_methods(name) values ('نقدي'),('بطاقة'),('تحويل بنكي'),('آجل') on conflict(name) do nothing;
insert into expense_categories(name) values ('إيجار'),('كهرباء'),('ماء'),('إنترنت'),('رواتب'),('نقل'),('وقود'),('صيانة'),('تسويق'),('إعلانات'),('أدوات مكتبية'),('رسوم بنكية'),('اشتراكات'),('مصروفات أخرى') on conflict(name) do nothing;
insert into settings(key,value) values
('store','{"name":"متجري","phone":"","address":"","email":"","currency":"OMR","tax_rate":0}'),
('invoice','{"footer":"شكرًا لتعاملكم معنا","show_logo":true}'),
('ui','{"theme":"light","language":"ar"}')
on conflict(key) do nothing;

create or replace function audit_trigger() returns trigger language plpgsql security definer as $$
begin
 insert into audit_logs(user_id,action,section,document_id,before_data,after_data)
 values(auth.uid(),TG_OP,TG_TABLE_NAME,coalesce(NEW.id,OLD.id),case when TG_OP in ('UPDATE','DELETE') then to_jsonb(OLD) end,case when TG_OP in ('INSERT','UPDATE') then to_jsonb(NEW) end);
 return coalesce(NEW,OLD);
end $$;

drop trigger if exists products_audit on products;
create trigger products_audit after insert or update or delete on products for each row execute function audit_trigger();
drop trigger if exists sales_audit on sales;
create trigger sales_audit after insert or update or delete on sales for each row execute function audit_trigger();
drop trigger if exists purchases_audit on purchases;
create trigger purchases_audit after insert or update or delete on purchases for each row execute function audit_trigger();
drop trigger if exists expenses_audit on expenses;
create trigger expenses_audit after insert or update or delete on expenses for each row execute function audit_trigger();

alter table profiles enable row level security;
alter table products enable row level security;
alter table categories enable row level security;
alter table brands enable row level security;
alter table units enable row level security;
alter table warehouses enable row level security;
alter table customers enable row level security;
alter table suppliers enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table purchases enable row level security;
alter table purchase_items enable row level security;
alter table expenses enable row level security;
alter table expense_categories enable row level security;
alter table stock_movements enable row level security;
alter table payments enable row level security;
alter table audit_logs enable row level security;
alter table notifications enable row level security;
alter table payment_methods enable row level security;
alter table settings enable row level security;
alter table roles enable row level security;

-- Authenticated users can operate the store; finer permissions are enforced by the application role layer.
do $$ declare t text; begin
 foreach t in array array['profiles','products','categories','brands','units','warehouses','customers','suppliers','sales','sale_items','purchases','purchase_items','expenses','expense_categories','stock_movements','payments','audit_logs','notifications','payment_methods','settings','roles'] loop
  execute format('drop policy if exists "auth_all_%s" on %I',t,t);
  execute format('create policy "auth_all_%s" on %I for all to authenticated using (true) with check (true)',t,t);
 end loop;
end $$;

create or replace function create_sale(
 p_customer uuid, p_items jsonb, p_paid numeric, p_payment uuid, p_notes text default null
) returns uuid language plpgsql security definer as $$
declare sid uuid; item jsonb; pid uuid; q numeric; pr numeric; c numeric; sub numeric:=0; tot numeric:=0; duev numeric;
begin
 if jsonb_array_length(p_items)=0 then raise exception 'لا توجد منتجات'; end if;
 insert into sales(invoice_no,customer_id,paid,payment_method_id,notes,created_by)
 values('S-'||to_char(now(),'YYYYMMDDHH24MISSMS'),p_customer,p_paid,p_payment,p_notes,auth.uid()) returning id into sid;
 for item in select * from jsonb_array_elements(p_items) loop
  pid := (item->>'product_id')::uuid; q := (item->>'qty')::numeric; pr := (item->>'price')::numeric;
  select avg_cost into c from products where id=pid for update;
  if not found then raise exception 'المنتج غير موجود'; end if;
  update products set qty=qty-q, updated_at=now() where id=pid;
  select qty into q from products where id=pid;
  insert into sale_items(sale_id,product_id,qty,price,cost) values(sid,pid,(item->>'qty')::numeric,pr,c);
  insert into stock_movements(product_id,movement_type,qty,balance_after,reference_type,reference_id,created_by)
  values(pid,'sale',-((item->>'qty')::numeric),q,'sale',sid,auth.uid());
  sub := sub + ((item->>'qty')::numeric*pr);
 end loop;
 tot:=sub;
 duev:=greatest(tot-p_paid,0);
 update sales set subtotal=sub,total=tot,due=duev where id=sid;
 if p_customer is not null then update customers set balance=balance+duev where id=p_customer; end if;
 return sid;
end $$;

create or replace function create_purchase(
 p_supplier uuid, p_items jsonb, p_paid numeric, p_payment uuid, p_notes text default null
) returns uuid language plpgsql security definer as $$
declare pid uuid; item jsonb; prod uuid; q numeric; pr numeric; newqty numeric; oldavg numeric; oldqty numeric; newavg numeric; sub numeric:=0; duev numeric;
begin
 insert into purchases(invoice_no,supplier_id,paid,payment_method_id,notes,created_by)
 values('P-'||to_char(now(),'YYYYMMDDHH24MISSMS'),p_supplier,p_paid,p_payment,p_notes,auth.uid()) returning id into pid;
 for item in select * from jsonb_array_elements(p_items) loop
  prod := (item->>'product_id')::uuid; q := (item->>'qty')::numeric; pr := (item->>'price')::numeric;
  select qty,avg_cost into oldqty,oldavg from products where id=prod for update;
  if not found then raise exception 'المنتج غير موجود'; end if;
  newqty:=oldqty+q; newavg:=case when newqty=0 then pr else ((oldqty*coalesce(oldavg,0))+(q*pr))/newqty end;
  update products set qty=newqty,avg_cost=newavg,purchase_price=pr,updated_at=now() where id=prod;
  insert into purchase_items(purchase_id,product_id,qty,price) values(pid,prod,q,pr);
  insert into stock_movements(product_id,movement_type,qty,balance_after,reference_type,reference_id,created_by)
  values(prod,'purchase',q,newqty,'purchase',pid,auth.uid());
  sub:=sub+(q*pr);
 end loop;
 duev:=greatest(sub-p_paid,0);
 update purchases set subtotal=sub,total=sub,due=duev where id=pid;
 if p_supplier is not null then update suppliers set balance=balance+duev where id=p_supplier; end if;
 return pid;
end $$;
