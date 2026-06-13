-- =========================================================
-- RLS（行级安全）策略
-- 设计原则：
--  1. 所有表默认启用 RLS，未登录用户无任何权限。
--  2. 所有"已登录"员工（auth.uid() 不为空）可以读取/新增/修改业务数据
--     （客户、供应商、商品、库存、采购、销售）。
--  3. 删除操作仅限 role = 'admin' 的用户（通过 profiles 表判断）。
--  4. profiles 表：用户只能读取/修改自己的资料；admin 可读取所有。
-- =========================================================

-- ---------------------------------------------------------
-- 辅助函数：判断当前用户是否为 admin
-- ---------------------------------------------------------
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;

-- ---------------------------------------------------------
-- 1. profiles
-- ---------------------------------------------------------
alter table profiles enable row level security;

drop policy if exists "profiles_select_own_or_admin" on profiles;
create policy "profiles_select_own_or_admin" on profiles
  for select using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id);

-- profiles 由触发器自动插入，不需要客户端 insert 策略，
-- 但保留以防客户端需要写入（仅本人）：
drop policy if exists "profiles_insert_own" on profiles;
create policy "profiles_insert_own" on profiles
  for insert with check (auth.uid() = id);

-- ---------------------------------------------------------
-- 2. customers 客户管理
-- ---------------------------------------------------------
alter table customers enable row level security;

drop policy if exists "customers_select" on customers;
create policy "customers_select" on customers
  for select using (auth.uid() is not null);

drop policy if exists "customers_insert" on customers;
create policy "customers_insert" on customers
  for insert with check (auth.uid() is not null);

drop policy if exists "customers_update" on customers;
create policy "customers_update" on customers
  for update using (auth.uid() is not null);

drop policy if exists "customers_delete" on customers;
create policy "customers_delete" on customers
  for delete using (public.is_admin());

-- ---------------------------------------------------------
-- 3. suppliers 供应商管理
-- ---------------------------------------------------------
alter table suppliers enable row level security;

drop policy if exists "suppliers_select" on suppliers;
create policy "suppliers_select" on suppliers
  for select using (auth.uid() is not null);

drop policy if exists "suppliers_insert" on suppliers;
create policy "suppliers_insert" on suppliers
  for insert with check (auth.uid() is not null);

drop policy if exists "suppliers_update" on suppliers;
create policy "suppliers_update" on suppliers
  for update using (auth.uid() is not null);

drop policy if exists "suppliers_delete" on suppliers;
create policy "suppliers_delete" on suppliers
  for delete using (public.is_admin());

-- ---------------------------------------------------------
-- 4. products 商品
-- ---------------------------------------------------------
alter table products enable row level security;

drop policy if exists "products_select" on products;
create policy "products_select" on products
  for select using (auth.uid() is not null);

drop policy if exists "products_insert" on products;
create policy "products_insert" on products
  for insert with check (auth.uid() is not null);

drop policy if exists "products_update" on products;
create policy "products_update" on products
  for update using (auth.uid() is not null);

drop policy if exists "products_delete" on products;
create policy "products_delete" on products
  for delete using (public.is_admin());

-- ---------------------------------------------------------
-- 5. inventory 库存
-- ---------------------------------------------------------
alter table inventory enable row level security;

drop policy if exists "inventory_select" on inventory;
create policy "inventory_select" on inventory
  for select using (auth.uid() is not null);

-- 库存数据原则上通过 apply_inventory_change() 函数(security definer)写入，
-- 但也允许已登录用户直接 insert/update，便于初始化盘点。
drop policy if exists "inventory_insert" on inventory;
create policy "inventory_insert" on inventory
  for insert with check (auth.uid() is not null);

drop policy if exists "inventory_update" on inventory;
create policy "inventory_update" on inventory
  for update using (auth.uid() is not null);

drop policy if exists "inventory_delete" on inventory;
create policy "inventory_delete" on inventory
  for delete using (public.is_admin());

-- ---------------------------------------------------------
-- 6. inventory_transactions 库存流水
-- ---------------------------------------------------------
alter table inventory_transactions enable row level security;

drop policy if exists "inv_txn_select" on inventory_transactions;
create policy "inv_txn_select" on inventory_transactions
  for select using (auth.uid() is not null);

drop policy if exists "inv_txn_insert" on inventory_transactions;
create policy "inv_txn_insert" on inventory_transactions
  for insert with check (auth.uid() is not null);

-- 流水不可修改/删除（仅 admin 可删，用于纠错）
drop policy if exists "inv_txn_delete" on inventory_transactions;
create policy "inv_txn_delete" on inventory_transactions
  for delete using (public.is_admin());

-- ---------------------------------------------------------
-- 7. purchase_orders / purchase_order_items 采购
-- ---------------------------------------------------------
alter table purchase_orders enable row level security;

drop policy if exists "po_select" on purchase_orders;
create policy "po_select" on purchase_orders
  for select using (auth.uid() is not null);

drop policy if exists "po_insert" on purchase_orders;
create policy "po_insert" on purchase_orders
  for insert with check (auth.uid() is not null);

drop policy if exists "po_update" on purchase_orders;
create policy "po_update" on purchase_orders
  for update using (auth.uid() is not null);

drop policy if exists "po_delete" on purchase_orders;
create policy "po_delete" on purchase_orders
  for delete using (public.is_admin());

alter table purchase_order_items enable row level security;

drop policy if exists "po_items_select" on purchase_order_items;
create policy "po_items_select" on purchase_order_items
  for select using (auth.uid() is not null);

drop policy if exists "po_items_insert" on purchase_order_items;
create policy "po_items_insert" on purchase_order_items
  for insert with check (auth.uid() is not null);

drop policy if exists "po_items_update" on purchase_order_items;
create policy "po_items_update" on purchase_order_items
  for update using (auth.uid() is not null);

drop policy if exists "po_items_delete" on purchase_order_items;
create policy "po_items_delete" on purchase_order_items
  for delete using (auth.uid() is not null);

-- ---------------------------------------------------------
-- 8. sales_orders / sales_order_items 销售
-- ---------------------------------------------------------
alter table sales_orders enable row level security;

drop policy if exists "so_select" on sales_orders;
create policy "so_select" on sales_orders
  for select using (auth.uid() is not null);

drop policy if exists "so_insert" on sales_orders;
create policy "so_insert" on sales_orders
  for insert with check (auth.uid() is not null);

drop policy if exists "so_update" on sales_orders;
create policy "so_update" on sales_orders
  for update using (auth.uid() is not null);

drop policy if exists "so_delete" on sales_orders;
create policy "so_delete" on sales_orders
  for delete using (public.is_admin());

alter table sales_order_items enable row level security;

drop policy if exists "so_items_select" on sales_order_items;
create policy "so_items_select" on sales_order_items
  for select using (auth.uid() is not null);

drop policy if exists "so_items_insert" on sales_order_items;
create policy "so_items_insert" on sales_order_items
  for insert with check (auth.uid() is not null);

drop policy if exists "so_items_update" on sales_order_items;
create policy "so_items_update" on sales_order_items
  for update using (auth.uid() is not null);

drop policy if exists "so_items_delete" on sales_order_items;
create policy "so_items_delete" on sales_order_items
  for delete using (auth.uid() is not null);
