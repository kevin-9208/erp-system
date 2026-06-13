-- =========================================================
-- Supabase Storage 配置
-- 用于存储：商品图片 (product-images)、附件如采购/销售单据 (attachments)
-- =========================================================

-- ---------------------------------------------------------
-- 1. 创建存储桶
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;

-- ---------------------------------------------------------
-- 2. product-images 桶策略
--    - 公开读取（商品图片展示无需登录）
--    - 已登录用户可上传/更新/删除
-- ---------------------------------------------------------
drop policy if exists "product_images_public_read" on storage.objects;
create policy "product_images_public_read" on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists "product_images_auth_insert" on storage.objects;
create policy "product_images_auth_insert" on storage.objects
  for insert with check (
    bucket_id = 'product-images' and auth.uid() is not null
  );

drop policy if exists "product_images_auth_update" on storage.objects;
create policy "product_images_auth_update" on storage.objects
  for update using (
    bucket_id = 'product-images' and auth.uid() is not null
  );

drop policy if exists "product_images_auth_delete" on storage.objects;
create policy "product_images_auth_delete" on storage.objects
  for delete using (
    bucket_id = 'product-images' and auth.uid() is not null
  );

-- ---------------------------------------------------------
-- 3. attachments 桶策略
--    - 仅登录用户可读写（采购/销售单据、合同等内部文件）
-- ---------------------------------------------------------
drop policy if exists "attachments_auth_read" on storage.objects;
create policy "attachments_auth_read" on storage.objects
  for select using (
    bucket_id = 'attachments' and auth.uid() is not null
  );

drop policy if exists "attachments_auth_insert" on storage.objects;
create policy "attachments_auth_insert" on storage.objects
  for insert with check (
    bucket_id = 'attachments' and auth.uid() is not null
  );

drop policy if exists "attachments_auth_update" on storage.objects;
create policy "attachments_auth_update" on storage.objects
  for update using (
    bucket_id = 'attachments' and auth.uid() is not null
  );

drop policy if exists "attachments_auth_delete" on storage.objects;
create policy "attachments_auth_delete" on storage.objects
  for delete using (
    bucket_id = 'attachments' and auth.uid() is not null
  );

-- 说明：
-- 商品图片建议路径: product-images/{product_id}/{filename}
-- 采购/销售附件建议路径: attachments/{purchase|sales}/{order_id}/{filename}
