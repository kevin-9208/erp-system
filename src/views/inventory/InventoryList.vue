<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { supabase } from '../../lib/supabase'

const list = ref([])
const loading = ref(false)
const keyword = ref('')

const adjustDialogVisible = ref(false)
const adjustForm = ref({ product_id: '', warehouse: '主仓库', current: 0, delta: 0, note: '' })

const txnDialogVisible = ref(false)
const txnList = ref([])
const txnLoading = ref(false)

async function fetchList() {
  loading.value = true
  try {
    let query = supabase
      .from('inventory')
      .select('*, products(sku, name, unit, cost_price, sale_price, is_active)')

    const { data, error } = await query.order('updated_at', { ascending: false })
    if (error) throw error

    let result = data
    if (keyword.value) {
      const kw = keyword.value.toLowerCase()
      result = result.filter(
        (r) =>
          r.products?.name?.toLowerCase().includes(kw) ||
          r.products?.sku?.toLowerCase().includes(kw)
      )
    }
    list.value = result
  } catch (err) {
    ElMessage.error(err.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function openAdjust(row) {
  adjustForm.value = {
    product_id: row.product_id,
    warehouse: row.warehouse,
    current: Number(row.quantity),
    delta: 0,
    note: ''
  }
  adjustDialogVisible.value = true
}

async function handleAdjustSubmit() {
  if (adjustForm.value.delta === 0) {
    ElMessage.warning('请输入调整数量（正数为增加，负数为减少）')
    return
  }
  try {
    const { error } = await supabase.rpc('apply_inventory_change', {
      p_product_id: adjustForm.value.product_id,
      p_warehouse: adjustForm.value.warehouse,
      p_qty_delta: adjustForm.value.delta,
      p_type: 'adjust',
      p_ref_type: 'manual',
      p_ref_id: null,
      p_note: adjustForm.value.note || '手动调整库存'
    })
    if (error) throw error
    ElMessage.success('调整成功')
    adjustDialogVisible.value = false
    fetchList()
  } catch (err) {
    ElMessage.error(err.message || '调整失败')
  }
}

async function openTxnHistory(row) {
  txnDialogVisible.value = true
  txnLoading.value = true
  try {
    const { data, error } = await supabase
      .from('inventory_transactions')
      .select('*')
      .eq('product_id', row.product_id)
      .order('created_at', { ascending: false })
      .limit(50)
    if (error) throw error
    txnList.value = data
  } catch (err) {
    ElMessage.error(err.message || '加载失败')
  } finally {
    txnLoading.value = false
  }
}

const typeMap = {
  in: { label: '入库', type: 'success' },
  out: { label: '出库', type: 'danger' },
  adjust: { label: '调整', type: 'warning' }
}

onMounted(fetchList)
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>库存管理</h2>
    </div>

    <div class="search-bar">
      <el-input v-model="keyword" placeholder="搜索商品名称/编码" style="width: 260px" clearable @keyup.enter="fetchList" />
      <el-button :icon="Search" @click="fetchList">搜索</el-button>
    </div>

    <el-table :data="list" v-loading="loading" border stripe>
      <el-table-column label="商品编码" width="120">
        <template #default="{ row }">{{ row.products?.sku }}</template>
      </el-table-column>
      <el-table-column label="商品名称" min-width="160">
        <template #default="{ row }">{{ row.products?.name }}</template>
      </el-table-column>
      <el-table-column prop="warehouse" label="仓库" width="120" />
      <el-table-column label="单位" width="80">
        <template #default="{ row }">{{ row.products?.unit }}</template>
      </el-table-column>
      <el-table-column prop="quantity" label="库存数量" width="120">
        <template #default="{ row }">
          <span :class="Number(row.quantity) < 0 ? 'amount-negative' : ''">{{ row.quantity }}</span>
        </template>
      </el-table-column>
      <el-table-column label="库存成本价值" width="140">
        <template #default="{ row }">¥{{ (Number(row.quantity) * Number(row.products?.cost_price || 0)).toFixed(2) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="180">
        <template #default="{ row }">
          <el-button link type="primary" @click="openAdjust(row)">调整库存</el-button>
          <el-button link @click="openTxnHistory(row)">变动记录</el-button>
        </template>
      </el-table-column>
    </el-table>

    <!-- 调整库存对话框 -->
    <el-dialog v-model="adjustDialogVisible" title="调整库存" width="420px">
      <el-form label-width="100px">
        <el-form-item label="当前库存">
          <span>{{ adjustForm.current }}</span>
        </el-form-item>
        <el-form-item label="调整数量">
          <el-input-number v-model="adjustForm.delta" :precision="2" style="width: 100%" />
          <div style="font-size: 12px; color: #909399">正数表示增加库存，负数表示减少库存</div>
        </el-form-item>
        <el-form-item label="调整后库存">
          <span>{{ (adjustForm.current + adjustForm.delta).toFixed(2) }}</span>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="adjustForm.note" type="textarea" :rows="2" placeholder="盘点、损耗等原因" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="adjustDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleAdjustSubmit">确认调整</el-button>
      </template>
    </el-dialog>

    <!-- 变动记录对话框 -->
    <el-dialog v-model="txnDialogVisible" title="库存变动记录" width="600px">
      <el-table :data="txnList" v-loading="txnLoading" border size="small" max-height="400">
        <el-table-column label="时间" width="160">
          <template #default="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
        </el-table-column>
        <el-table-column label="类型" width="80">
          <template #default="{ row }">
            <el-tag :type="typeMap[row.type]?.type" size="small">{{ typeMap[row.type]?.label }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="quantity" label="数量变化" width="100">
          <template #default="{ row }">
            <span :class="Number(row.quantity) >= 0 ? 'amount-positive' : 'amount-negative'">
              {{ Number(row.quantity) > 0 ? '+' : '' }}{{ row.quantity }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="note" label="备注" min-width="160" show-overflow-tooltip />
      </el-table>
    </el-dialog>
  </div>
</template>
