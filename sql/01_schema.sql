-- =========================================================
-- ERP 系统数据库结构 (Supabase / PostgreSQL)
-- =========================================================

-- 启用 uuid 生成函数
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------
-- 1. 用户资料表（绑定 auth.users）
-- ---------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'staff' check (role in ('admin','staff')),
  created_at timestamptz default now()
);

-- 注册时自动创建 profile
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.email), 'staff');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------
-- 2. 客户管理
-- ---------------------------------------------------------
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  contact_person text,
  phone text,
  email text,
  address text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ---------------------------------------------------------
-- 3. 供应商管理
-- ---------------------------------------------------------
create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  contact_person text,
  phone text,
  email text,
  address text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ---------------------------------------------------------
-- 4. 商品 / 物料
-- ---------------------------------------------------------
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  sku text unique not null,
  name text not null,
  category text,
  unit text default '个',
  cost_price numeric(12,2) default 0,
  sale_price numeric(12,2) default 0,
  image_url text,
  description text,
  is_active boolean default true,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ---------------------------------------------------------
-- 5. 库存
-- ---------------------------------------------------------
create table if not exists inventory (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  warehouse text not null default '主仓库',
  quantity numeric(14,2) not null default 0,
  updated_at timestamptz default now(),
  unique (product_id, warehouse)
);

-- 库存变动流水
create table if not exists inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id),
  warehouse text not null default '主仓库',
  type text not null check (type in ('in','out','adjust')),
  quantity numeric(14,2) not null, -- 正数=入库/调增, 负数=出库/调减
  ref_type text,                   -- purchase / sales / adjust
  ref_id uuid,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- ---------------------------------------------------------
-- 6. 采购管理
-- ---------------------------------------------------------
create table if not exists purchase_orders (
  id uuid primary key default gen_random_uuid(),
  order_no text unique not null,
  supplier_id uuid references suppliers(id),
  status text not null default 'draft' check (status in ('draft','confirmed','received','cancelled')),
  total_amount numeric(14,2) default 0,
  order_date date default current_date,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references purchase_orders(id) on delete cascade,
  product_id uuid not null references products(id),
  quantity numeric(14,2) not null,
  unit_price numeric(12,2) not null default 0,
  subtotal numeric(14,2) generated always as (quantity * unit_price) stored
);

-- ---------------------------------------------------------
-- 7. 销售管理
-- ---------------------------------------------------------
create table if not exists sales_orders (
  id uuid primary key default gen_random_uuid(),
  order_no text unique not null,
  customer_id uuid references customers(id),
  status text not null default 'draft' check (status in ('draft','confirmed','shipped','cancelled')),
  total_amount numeric(14,2) default 0,
  order_date date default current_date,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references sales_orders(id) on delete cascade,
  product_id uuid not null references products(id),
  quantity numeric(14,2) not null,
  unit_price numeric(12,2) not null default 0,
  subtotal numeric(14,2) generated always as (quantity * unit_price) stored
);

-- ---------------------------------------------------------
-- 8. 索引
-- ---------------------------------------------------------
create index if not exists idx_inv_txn_product on inventory_transactions(product_id);
create index if not exists idx_po_items_po on purchase_order_items(purchase_order_id);
create index if not exists idx_so_items_so on sales_order_items(sales_order_id);
create index if not exists idx_po_supplier on purchase_orders(supplier_id);
create index if not exists idx_so_customer on sales_orders(customer_id);

-- ---------------------------------------------------------
-- 9. 业务函数与触发器：自动更新 updated_at
-- ---------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_customers_updated on customers;
create trigger trg_customers_updated before update on customers
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_suppliers_updated on suppliers;
create trigger trg_suppliers_updated before update on suppliers
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_products_updated on products;
create trigger trg_products_updated before update on products
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_po_updated on purchase_orders;
create trigger trg_po_updated before update on purchase_orders
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_so_updated on sales_orders;
create trigger trg_so_updated before update on sales_orders
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------
-- 10. 库存写入辅助函数（增加/扣减库存 + 写流水）
-- ---------------------------------------------------------
create or replace function public.apply_inventory_change(
  p_product_id uuid,
  p_warehouse text,
  p_qty_delta numeric,
  p_type text,
  p_ref_type text,
  p_ref_id uuid,
  p_note text
) returns void as $$
begin
  insert into inventory (product_id, warehouse, quantity)
  values (p_product_id, p_warehouse, 0)
  on conflict (product_id, warehouse) do nothing;

  update inventory
    set quantity = quantity + p_qty_delta,
        updated_at = now()
    where product_id = p_product_id and warehouse = p_warehouse;

  insert into inventory_transactions
    (product_id, warehouse, type, quantity, ref_type, ref_id, note, created_by)
  values
    (p_product_id, p_warehouse, p_type, p_qty_delta, p_ref_type, p_ref_id, p_note, auth.uid());
end;
$$ language plpgsql security definer;

-- ---------------------------------------------------------
-- 11. 采购单/销售单 状态变更 -> 自动调整库存与合计金额
-- ---------------------------------------------------------
create or replace function public.handle_purchase_status_change()
returns trigger as $$
declare
  item record;
begin
  -- 状态变为 received 时，入库
  if new.status = 'received' and old.status <> 'received' then
    for item in select * from purchase_order_items where purchase_order_id = new.id loop
      perform public.apply_inventory_change(
        item.product_id, '主仓库', item.quantity, 'in', 'purchase', new.id,
        '采购单 ' || new.order_no || ' 入库'
      );
    end loop;
  end if;

  -- 撤销 received -> 其他状态时，回退库存
  if old.status = 'received' and new.status <> 'received' then
    for item in select * from purchase_order_items where purchase_order_id = new.id loop
      perform public.apply_inventory_change(
        item.product_id, '主仓库', -item.quantity, 'adjust', 'purchase', new.id,
        '采购单 ' || new.order_no || ' 撤销入库'
      );
    end loop;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_purchase_status on purchase_orders;
create trigger trg_purchase_status
  after update of status on purchase_orders
  for each row execute procedure public.handle_purchase_status_change();

create or replace function public.handle_sales_status_change()
returns trigger as $$
declare
  item record;
begin
  -- 状态变为 shipped 时，出库
  if new.status = 'shipped' and old.status <> 'shipped' then
    for item in select * from sales_order_items where sales_order_id = new.id loop
      perform public.apply_inventory_change(
        item.product_id, '主仓库', -item.quantity, 'out', 'sales', new.id,
        '销售单 ' || new.order_no || ' 出库'
      );
    end loop;
  end if;

  -- 撤销 shipped -> 其他状态时，回退库存
  if old.status = 'shipped' and new.status <> 'shipped' then
    for item in select * from sales_order_items where sales_order_id = new.id loop
      perform public.apply_inventory_change(
        item.product_id, '主仓库', item.quantity, 'adjust', 'sales', new.id,
        '销售单 ' || new.order_no || ' 撤销出库'
      );
    end loop;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_sales_status on sales_orders;
create trigger trg_sales_status
  after update of status on sales_orders
  for each row execute procedure public.handle_sales_status_change();

-- ---------------------------------------------------------
-- 12. 订单合计金额自动汇总（明细变更时）
-- ---------------------------------------------------------
create or replace function public.recalc_purchase_total()
returns trigger as $$
begin
  update purchase_orders set total_amount = (
    select coalesce(sum(subtotal),0) from purchase_order_items
    where purchase_order_id = coalesce(new.purchase_order_id, old.purchase_order_id)
  ) where id = coalesce(new.purchase_order_id, old.purchase_order_id);
  return null;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_po_items_recalc on purchase_order_items;
create trigger trg_po_items_recalc
  after insert or update or delete on purchase_order_items
  for each row execute procedure public.recalc_purchase_total();

create or replace function public.recalc_sales_total()
returns trigger as $$
begin
  update sales_orders set total_amount = (
    select coalesce(sum(subtotal),0) from sales_order_items
    where sales_order_id = coalesce(new.sales_order_id, old.sales_order_id)
  ) where id = coalesce(new.sales_order_id, old.sales_order_id);
  return null;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_so_items_recalc on sales_order_items;
create trigger trg_so_items_recalc
  after insert or update or delete on sales_order_items
  for each row execute procedure public.recalc_sales_total();
