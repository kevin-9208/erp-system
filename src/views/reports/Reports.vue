<script setup>
import { ref, onMounted, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { supabase } from '../../lib/supabase'

const activeTab = ref('sales')
const loading = ref(false)

const dateRange = ref([
  new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10),
  new Date().toISOString().slice(0, 10)
])

// 销售 / 采购订单明细
const salesOrders = ref([])
const purchaseOrders = ref([])

// 商品销售排行
const productRanking = ref([])

// 库存估值
const inventoryValuation = ref([])

const statusMapSO = {
  draft: '草稿', confirmed: '已确认', shipped: '已出库', cancelled: '已取消'
}
const statusMapPO = {
  draft: '草稿', confirmed: '已确认', received: '已入库', cancelled: '已取消'
}

const salesSummary = computed(() => {
  const valid = salesOrders.value.filter((o) => o.status !== 'cancelled')
  return {
    count: valid.length,
    total: valid.reduce((s, o) => s + Number(o.total_amount), 0)
  }
})

const purchaseSummary = computed(() => {
  const valid = purchaseOrders.value.filter((o) => o.status !== 'cancelled')
  return {
    count: valid.length,
    total: valid.reduce((s, o) => s + Number(o.total_amount), 0)
  }
})

const inventorySummary = computed(() => {
  return {
    skuCount: inventoryValuation.value.length,
    totalQty: inventoryValuation.value.reduce((s, r) => s + Number(r.quantity), 0),
    costValue: inventoryValuation.value.reduce((s, r) => s + Number(r.quantity) * Number(r.cost_price), 0),
    saleValue: inventoryValuation.value.reduce((s, r) => s + Number(r.quantity) * Number(r.sale_price), 0)
  }
})

async function fetchSalesReport() {
  const { data, error } = await supabase
    .from('sales_orders')
    .select('order_no, order_date, status, total_amount, customers(name)')
    .gte('order_date', dateRange.value[0])
    .lte('order_date', dateRange.value[1])
    .order('order_date', { ascending: false })
  if (error) throw error
  salesOrders.value = data
}

async function fetchPurchaseReport() {
  const { data, error } = await supabase
    .from('purchase_orders')
    .select('order_no, order_date, status, total_amount, suppliers(name)')
    .gte('order_date', dateRange.value[0])
    .lte('order_date', dateRange.value[1])
    .order('order_date', { ascending: false })
  if (error) throw error
  purchaseOrders.value = data
}

async function fetchProductRanking() {
  // 取出指定日期范围内非取消状态的销售单 id
  const { data: orders, error: orderErr } = await supabase
    .from('sales_orders')
    .select('id')
    .gte('order_date', dateRange.value[0])
    .lte('order_date', dateRange.value[1])
    .neq('status', 'cancelled')
  if (orderErr) throw orderErr
  const orderIds = orders.map((o) => o.id)
  if (orderIds.length === 0) {
    productRanking.value = []
    return
  }

  const { data: items, error: itemErr } = await supabase
    .from('sales_order_items')
    .select('product_id, quantity, subtotal, products(sku, name, unit)')
    .in('sales_order_id', orderIds)
  if (itemErr) throw itemErr

  const map = {}
  items.forEach((it) => {
    const key = it.product_id
    if (!map[key]) {
      map[key] = {
        sku: it.products?.sku,
        name: it.products?.name,
        unit: it.products?.unit,
        quantity: 0,
        amount: 0
      }
    }
    map[key].quantity += Number(it.quantity)
    map[key].amount += Number(it.subtotal)
  })

  productRanking.value = Object.values(map).sort((a, b) => b.amount - a.amount)
}

async function fetchInventoryValuation() {
  const { data, error } = await supabase
    .from('inventory')
    .select('quantity, warehouse, products(sku, name, unit, cost_price, sale_price)')
  if (error) throw error
  inventoryValuation.value = data.map((r) => ({
    sku: r.products?.sku,
    name: r.products?.name,
    unit: r.products?.unit,
    warehouse: r.warehouse,
    quantity: Number(r.quantity),
    cost_price: Number(r.products?.cost_price || 0),
    sale_price: Number(r.products?.sale_price || 0)
  }))
}

async function refreshAll() {
  loading.value = true
  try {
    await Promise.all([
      fetchSalesReport(),
      fetchPurchaseReport(),
      fetchProductRanking(),
      fetchInventoryValuation()
    ])
  } catch (err) {
    ElMessage.error(err.message || '加载报表失败')
  } finally {
    loading.value = false
  }
}

onMounted(refreshAll)
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>报表系统</h2>
    </div>

    <div class="search-bar">
      <el-date-picker
        v-model="dateRange"
        type="daterange"
        value-format="YYYY-MM-DD"
        start-placeholder="开始日期"
        end-placeholder="结束日期"
      />
      <el-button type="primary" :icon="Refresh" :loading="loading" @click="refreshAll">查询</el-button>
    </div>

    <el-tabs v-model="activeTab">
      <el-tab-pane label="销售报表" name="sales">
        <el-row :gutter="16" style="margin-bottom: 12px">
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">订单数（不含取消）</div>
              <div class="stat-value">{{ salesSummary.count }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">销售总额</div>
              <div class="stat-value">¥{{ salesSummary.total.toFixed(2) }}</div>
            </el-card>
          </el-col>
        </el-row>
        <el-table :data="salesOrders" v-loading="loading" border stripe max-height="450">
          <el-table-column prop="order_no" label="单号" width="160" />
          <el-table-column label="客户" min-width="140">
            <template #default="{ row }">{{ row.customers?.name }}</template>
          </el-table-column>
          <el-table-column prop="order_date" label="日期" width="110" />
          <el-table-column label="金额" width="110">
            <template #default="{ row }">¥{{ Number(row.total_amount).toFixed(2) }}</template>
          </el-table-column>
          <el-table-column label="状态" width="90">
            <template #default="{ row }">{{ statusMapSO[row.status] }}</template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <el-tab-pane label="采购报表" name="purchase">
        <el-row :gutter="16" style="margin-bottom: 12px">
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">订单数（不含取消）</div>
              <div class="stat-value">{{ purchaseSummary.count }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">采购总额</div>
              <div class="stat-value">¥{{ purchaseSummary.total.toFixed(2) }}</div>
            </el-card>
          </el-col>
        </el-row>
        <el-table :data="purchaseOrders" v-loading="loading" border stripe max-height="450">
          <el-table-column prop="order_no" label="单号" width="160" />
          <el-table-column label="供应商" min-width="140">
            <template #default="{ row }">{{ row.suppliers?.name }}</template>
          </el-table-column>
          <el-table-column prop="order_date" label="日期" width="110" />
          <el-table-column label="金额" width="110">
            <template #default="{ row }">¥{{ Number(row.total_amount).toFixed(2) }}</template>
          </el-table-column>
          <el-table-column label="状态" width="90">
            <template #default="{ row }">{{ statusMapPO[row.status] }}</template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <el-tab-pane label="商品销售排行" name="ranking">
        <el-table :data="productRanking" v-loading="loading" border stripe max-height="500">
          <el-table-column type="index" label="排名" width="70" />
          <el-table-column prop="sku" label="编码" width="120" />
          <el-table-column prop="name" label="商品名称" min-width="160" />
          <el-table-column prop="unit" label="单位" width="80" />
          <el-table-column label="销售数量" width="120">
            <template #default="{ row }">{{ row.quantity }}</template>
          </el-table-column>
          <el-table-column label="销售金额" width="140">
            <template #default="{ row }">¥{{ row.amount.toFixed(2) }}</template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <el-tab-pane label="库存估值" name="inventory">
        <el-row :gutter="16" style="margin-bottom: 12px">
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">商品种类</div>
              <div class="stat-value">{{ inventorySummary.skuCount }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">库存总数量</div>
              <div class="stat-value">{{ inventorySummary.totalQty }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">成本价值合计</div>
              <div class="stat-value">¥{{ inventorySummary.costValue.toFixed(2) }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card class="stat-card">
              <div class="stat-label">销售价值合计</div>
              <div class="stat-value">¥{{ inventorySummary.saleValue.toFixed(2) }}</div>
            </el-card>
          </el-col>
        </el-row>
        <el-table :data="inventoryValuation" v-loading="loading" border stripe max-height="450">
          <el-table-column prop="sku" label="编码" width="120" />
          <el-table-column prop="name" label="商品名称" min-width="160" />
          <el-table-column prop="warehouse" label="仓库" width="100" />
          <el-table-column prop="quantity" label="数量" width="100" />
          <el-table-column label="成本价值" width="120">
            <template #default="{ row }">¥{{ (row.quantity * row.cost_price).toFixed(2) }}</template>
          </el-table-column>
          <el-table-column label="销售价值" width="120">
            <template #default="{ row }">¥{{ (row.quantity * row.sale_price).toFixed(2) }}</template>
          </el-table-column>
        </el-table>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>
