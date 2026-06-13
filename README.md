# ERP 管理系统（Vue3 + Supabase）

一个基于 **Vue3（组合式 API）+ Element Plus + Pinia + Vue Router + Supabase** 的轻量级 ERP 管理系统，
涵盖登录注册、客户管理、供应商管理、商品管理、采购管理、销售管理、库存管理、报表系统。

## 功能模块

| 模块 | 说明 |
| --- | --- |
| 登录注册 | 基于 Supabase Auth 的邮箱密码登录/注册，自动创建用户资料（profiles） |
| 客户管理 | 客户信息的增删改查、搜索、分页 |
| 供应商管理 | 供应商信息的增删改查、搜索、分页 |
| 商品管理 | 商品（SKU）信息维护，支持上传商品图片至 Supabase Storage |
| 采购管理 | 创建采购单 → 添加采购明细 → 确认 → 入库（自动增加库存并记录流水）→ 可取消 |
| 销售管理 | 创建销售单 → 添加销售明细 → 确认 → 出库（自动扣减库存并记录流水，库存不足会提示）→ 可取消 |
| 库存管理 | 查看各仓库库存、手动调整库存（盘点/损耗）、查看库存变动流水 |
| 报表系统 | 销售报表、采购报表、商品销售排行、库存估值，支持自定义日期范围 |

## 目录结构

```
erp-system/
├── sql/
│   ├── 01_schema.sql        # 数据库表结构、触发器、函数
│   ├── 02_rls_policies.sql  # 行级安全策略 (RLS)
│   └── 03_storage.sql       # Storage 桶与策略
├── src/
│   ├── lib/supabase.js      # Supabase 客户端初始化
│   ├── stores/auth.js        # Pinia 登录状态管理
│   ├── router/index.js       # 路由与登录鉴权守卫
│   ├── components/AppLayout.vue # 主布局（侧边栏 + 顶部栏）
│   └── views/
│       ├── auth/             # 登录、注册
│       ├── customers/        # 客户管理
│       ├── suppliers/        # 供应商管理
│       ├── products/         # 商品管理
│       ├── purchase/          # 采购管理（列表 + 详情）
│       ├── sales/             # 销售管理（列表 + 详情）
│       ├── inventory/         # 库存管理
│       └── reports/           # 报表系统
├── .env.example
├── package.json
└── vite.config.js
```

## 部署步骤

### 1. 创建 Supabase 项目

在 [supabase.com](https://supabase.com) 创建一个新项目，记录下：
- Project URL
- anon public key

### 2. 初始化数据库

在 Supabase 控制台的 **SQL Editor** 中，按顺序执行：
1. `sql/01_schema.sql` —— 创建所有表、触发器、业务函数
2. `sql/02_rls_policies.sql` —— 开启并配置行级安全策略
3. `sql/03_storage.sql` —— 创建 Storage 桶（商品图片、附件）及访问策略

> 注意：`02_rls_policies.sql` 中的 `is_admin()` 函数依赖 `profiles` 表的 `role` 字段。
> 新注册用户默认 `role = 'staff'`，如需管理员权限，可在 `profiles` 表中手动将对应用户的 `role` 改为 `admin`。

### 3. （可选）邮箱验证设置

在 Supabase 控制台 **Authentication -> Providers -> Email** 中：
- 如果不需要邮箱验证，可关闭 "Confirm email"，注册后即可直接登录。
- 如果开启邮箱验证，用户注册后需先点击邮件中的确认链接才能登录。

### 4. 配置前端环境变量

复制 `.env.example` 为 `.env`，并填入你的 Supabase 项目信息：

```
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key
```

### 5. 安装依赖并启动

```bash
npm install
npm run dev
```

访问 `http://localhost:5173`，注册一个账号即可登录使用。

### 6. 构建生产版本

```bash
npm run build
```

构建产物在 `dist/` 目录，可部署到 Vercel / Netlify / Supabase Hosting 等任意静态托管平台。

## 业务流程说明

### 采购流程
1. 在「采购管理」新建采购单，选择供应商、日期 → 创建后进入详情页
2. 添加采购明细（商品、数量、单价），系统自动计算小计与总金额
3. 点击「确认采购单」→ 状态变为「已确认」
4. 点击「确认入库」→ 状态变为「已入库」，触发数据库触发器自动：
   - 增加 `inventory` 表中对应商品库存数量
   - 写入一条 `inventory_transactions` 入库流水
5. 草稿/已确认状态可点击「取消」；已入库状态如被撤销会自动回退库存

### 销售流程
1. 在「销售管理」新建销售单，选择客户、日期 → 创建后进入详情页
2. 添加销售明细（商品、数量、单价）
3. 点击「确认销售单」→ 状态变为「已确认」
4. 点击「确认出库」→ 若库存不足会弹窗提示，确认后状态变为「已出库」，触发器自动：
   - 扣减 `inventory` 表中对应商品库存数量（允许为负，便于追溯超卖）
   - 写入一条 `inventory_transactions` 出库流水

### 库存管理
- 库存数量由采购入库 / 销售出库自动维护
- 也可在「库存管理」页面手动「调整库存」（盘点、损耗等），调用 `apply_inventory_change` 数据库函数，
  确保库存数量与流水记录同步更新
- 「变动记录」可查看某商品近期所有库存变动明细

### 报表系统
- **销售报表**：按日期范围统计销售订单数量与总金额，可查看明细列表
- **采购报表**：按日期范围统计采购订单数量与总金额
- **商品销售排行**：按销售金额排序的商品销量/销售额排行
- **库存估值**：按成本价/销售价计算当前库存总价值

## 权限设计（RLS）

- 所有表均开启 RLS，**未登录用户无任何数据访问权限**
- 已登录用户（任意角色）可以对客户、供应商、商品、采购、销售、库存进行增删改查
- 删除客户 / 供应商 / 商品 / 采购单 / 销售单 等关键数据，仅限 `profiles.role = 'admin'` 的管理员
- `profiles` 表用户只能查看/修改自己的资料，管理员可查看所有用户资料

如需将某用户设为管理员，在 Supabase 控制台 Table Editor 中打开 `profiles` 表，
将该用户记录的 `role` 字段改为 `admin` 即可。

## Storage 配置

- `product-images`：公开读取的桶，用于存放商品图片，登录用户可上传/更新/删除
- `attachments`：私有桶，用于存放采购/销售相关附件等内部文件，仅登录用户可访问

## 自检清单

- [x] 登录注册：注册自动创建 profiles 记录；路由守卫拦截未登录访问
- [x] 客户/供应商/商品管理：增删改查、分页、搜索均已实现，删除受 RLS 限制（仅 admin）
- [x] 采购管理：创建 → 加明细 → 确认 → 入库（自动更新库存与流水）→ 取消（回退库存）
- [x] 销售管理：创建 → 加明细 → 确认 → 出库（自动更新库存与流水，库存不足提示）→ 取消（回退库存）
- [x] 库存管理：库存列表、手动调整（含流水记录）、变动记录查询
- [x] 报表系统：销售/采购报表、商品销售排行、库存估值，均支持日期范围筛选
- [x] RLS 策略覆盖所有业务表与 Storage 桶
- [x] 图标按需导入，避免运行时解析失败
