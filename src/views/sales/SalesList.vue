<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../../stores/auth'

const router = useRouter()
const auth = useAuthStore()

const list = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)
const statusFilter = ref('')

const statusMap = {
  draft: { label: '草稿', type: 'info' },
  confirmed: { label: '已确认', type: 'warning' },
  shipped: { label: '已出库', type: 'success' },
  cancelled: { label: '已取消', type: 'danger' }
}

async function fetchList() {
  loading.value = true
  try {
    let query = supabase
      .from('sales_orders')
      .select('*, customers(name)', { count: 'exact' })

    if (statusFilter.value) {
      query = query.eq('status', statusFilter.value)
    }

    const from = (page.value - 1) * pageSize.value
    const to = from + pageSize.value - 1
    query = query.order('created_at', { ascending: false }).range(from, to)

    const { data, error, count } = await query
    if (error) throw error
    list.value = data
    total.value = count || 0
  } catch (err) {
    ElMessage.error(err.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function handlePageChange(p) {
  page.value = p
  fetchList()
}

function handleFilterChange() {
  page.value = 1
  fetchList()
}

function createOrder() {
  router.push('/sales/new')
}

function openDetail(row) {
  router.push(`/sales/${row.id}`)
}

async function changeStatus(row, status) {
  const tips = {
    confirmed: '确认该销售单吗？',
    shipped: '确认出库吗？库存将自动扣减。',
    cancelled: '确认取消该销售单吗？'
  }
  try {
    await ElMessageBox.confirm(tips[status], '提示', { type: 'warning' })
    const { error } = await supabase.from('sales_orders').update({ status }).eq('id', row.id)
    if (error) throw error
    ElMessage.success('操作成功')
    fetchList()
  } catch (err) {
    if (err !== 'cancel') ElMessage.error(err.message || '操作失败')
  }
}

async function handleDelete(row) {
  try {
    await ElMessageBox.confirm('确定删除该销售单吗？', '提示', { type: 'warning' })
    const { error } = await supabase.from('sales_orders').delete().eq('id', row.id)
    if (error) throw error
    ElMessage.success('删除成功')
    fetchList()
  } catch (err) {
    if (err !== 'cancel') ElMessage.error(err.message || '删除失败')
  }
}

onMounted(fetchList)
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>销售管理</h2>
      <el-button type="primary" :icon="Plus" @click="createOrder">新建销售单</el-button>
    </div>

    <div class="search-bar">
      <el-select v-model="statusFilter" placeholder="全部状态" clearable style="width: 160px" @change="handleFilterChange">
        <el-option label="草稿" value="draft" />
        <el-option label="已确认" value="confirmed" />
        <el-option label="已出库" value="shipped" />
        <el-option label="已取消" value="cancelled" />
      </el-select>
    </div>

    <el-table :data="list" v-loading="loading" border stripe>
      <el-table-column prop="order_no" label="销售单号" width="180" />
      <el-table-column label="客户" min-width="160">
        <template #default="{ row }">{{ row.customers?.name || '-' }}</template>
      </el-table-column>
      <el-table-column prop="order_date" label="日期" width="120" />
      <el-table-column prop="total_amount" label="金额" width="120">
        <template #default="{ row }">¥{{ Number(row.total_amount).toFixed(2) }}</template>
      </el-table-column>
      <el-table-column label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="statusMap[row.status]?.type">{{ statusMap[row.status]?.label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="280" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openDetail(row)">详情</el-button>
          <el-button v-if="row.status === 'draft'" link type="success" @click="changeStatus(row, 'confirmed')">确认</el-button>
          <el-button v-if="row.status === 'confirmed'" link type="success" @click="changeStatus(row, 'shipped')">出库</el-button>
          <el-button v-if="['draft','confirmed'].includes(row.status)" link type="warning" @click="changeStatus(row, 'cancelled')">取消</el-button>
          <el-button v-if="row.status === 'draft' && auth.isAdmin" link type="danger" @click="handleDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <div class="pagination-bar">
      <el-pagination
        v-model:current-page="page"
        :page-size="pageSize"
        :total="total"
        layout="total, prev, pager, next"
        @current-change="handlePageChange"
      />
    </div>
  </div>
</template>
