<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()

const stats = ref({
  customers: 0,
  suppliers: 0,
  products: 0,
  inventoryValue: 0,
  monthPurchase: 0,
  monthSales: 0
})

const lowStock = ref([])
const recentSales = ref([])
const loading = ref(false)

function monthStart() {
  const d = new Date()
  return new Date(d.getFullYear(), d.getMonth(), 1).toISOString().slice(0, 10)
}

async function fetchStats() {
  loading.value = true
  try {
    const [{ count: customerCount }, { count: supplierCount }, { count: productCount }] = await Promise.all([
      supabase.from('customers').select('*', { count: 'exact', head: true }),
      supabase.from('suppliers').select('*', { count: 'exact', head: true }),
      supabase.from('products').select('*', { count: 'exact', head: true })
    ])

    stats.value.customers = customerCount || 0
    stats.value.suppliers = supplierCount || 0
    stats.value.products = productCount || 0

    // 库存成本价值
    const { data: invData } = await supabase
      .from('inventory')
      .select('quantity, products(cost_price)')
    stats.value.inventoryValue = (invData || []).reduce(
      (sum, r) => sum + Number(r.quantity) * Number(r.products?.cost_price || 0),
      0
    )

    // 本月采购/销售金额（已确认及以上状态）
    const start = monthStart()
    const { data: poData } = await supabase
      .from('purchase_orders')
      .select('total_amount, status, order_date')
      .gte('order_date', start)
      .neq('status', 'cancelled')
    stats.value.monthPurchase = (poData || []).reduce((s, r) => s + Number(r.total_amount), 0)

    const { data: soData } = await supabase
      .from('sales_orders')
      .select('total_amount, status, order_date')
      .gte('order_date', start)
      .neq('status', 'cancelled')
    stats.value.monthSales = (soData || []).reduce((s, r) => s + Number(r.total_amount), 0)

    // 低库存（数量 <= 10）
    const { data: lowData } = await supabase
      .from('inventory')
      .select('quantity, warehouse, products(sku, name, unit)')
      .lte('quantity', 10)
      .order('quantity')
      .limit(10)
    lowStock.value = lowData || []

    // 最近销售单
    const { data: recentSoData } = await supabase
      .from('sales_orders')
      .select('order_no, total_amount, status, order_date, customers(name)')
      .order('created_at', { ascending: false })
      .limit(5)
    recentSales.value = recentSoData || []
  } finally {
    loading.value = false
  }
}

const statusMap = {
  draft: { label: '草稿', type: 'info' },
  confirmed: { label: '已确认', type: 'warning' },
  shipped: { label: '已出库', type: 'success' },
  cancelled: { label: '已取消', type: 'danger' }
}

onMounted(fetchStats)
</script>

<template>
  <div class="page-container" v-loading="loading">
    <div class="page-header">
      <h2>仪表盘</h2>
    </div>

    <el-row :gutter="16">
      <el-col :span="4">
        <el-card class="stat-card" shadow="hover" @click="router.push('/customers')" style="cursor: pointer">
          <div class="stat-label">客户数量</div>
          <div class="stat-value">{{ stats.customers }}</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card class="stat-card" shadow="hover" @click="router.push('/suppliers')" style="cursor: pointer">
          <div class="stat-label">供应商数量</div>
          <div class="stat-value">{{ stats.suppliers }}</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card class="stat-card" shadow="hover" @click="router.push('/products')" style="cursor: pointer">
          <div class="stat-label">商品种类</div>
          <div class="stat-value">{{ stats.products }}</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card class="stat-card" shadow="hover" @click="router.push('/inventory')" style="cursor: pointer">
          <div class="stat-label">库存成本价值</div>
          <div class="stat-value">¥{{ stats.inventoryValue.toFixed(0) }}</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card class="stat-card" shadow="hover" @click="router.push('/purchase')" style="cursor: pointer">
          <div class="stat-label">本月采购额</div>
          <div class="stat-value">¥{{ stats.monthPurchase.toFixed(0) }}</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card class="stat-card" shadow="hover" @click="router.push('/sales')" style="cursor: pointer">
          <div class="stat-label">本月销售额</div>
          <div class="stat-value">¥{{ stats.monthSales.toFixed(0) }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" style="margin-top: 16px">
      <el-col :span="12">
        <el-card>
          <template #header>低库存预警（≤ 10）</template>
          <el-table :data="lowStock" size="small" border>
            <el-table-column label="商品" min-width="140">
              <template #default="{ row }">{{ row.products?.name }} ({{ row.products?.sku }})</template>
            </el-table-column>
            <el-table-column prop="warehouse" label="仓库" width="100" />
            <el-table-column label="库存" width="80">
              <template #default="{ row }">
                <span :class="Number(row.quantity) <= 0 ? 'amount-negative' : ''">{{ row.quantity }}</span>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>最新销售单</template>
          <el-table :data="recentSales" size="small" border>
            <el-table-column prop="order_no" label="单号" width="160" />
            <el-table-column label="客户" min-width="120">
              <template #default="{ row }">{{ row.customers?.name }}</template>
            </el-table-column>
            <el-table-column label="金额" width="100">
              <template #default="{ row }">¥{{ Number(row.total_amount).toFixed(2) }}</template>
            </el-table-column>
            <el-table-column label="状态" width="90">
              <template #default="{ row }">
                <el-tag size="small" :type="statusMap[row.status]?.type">{{ statusMap[row.status]?.label }}</el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
