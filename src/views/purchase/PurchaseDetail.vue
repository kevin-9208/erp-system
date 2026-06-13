<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import { supabase } from '../../lib/supabase'

const route = useRoute()
const router = useRouter()

const isNew = computed(() => route.params.id === 'new')
const orderId = ref(route.params.id)

const suppliers = ref([])
const products = ref([])
const order = ref(null)
const items = ref([])
const loading = ref(false)

const statusMap = {
  draft: { label: '草稿', type: 'info' },
  confirmed: { label: '已确认', type: 'warning' },
  received: { label: '已入库', type: 'success' },
  cancelled: { label: '已取消', type: 'danger' }
}

// 新建表单
const createForm = ref({
  supplier_id: '',
  order_date: new Date().toISOString().slice(0, 10),
  notes: ''
})

// 添加明细对话框
const itemDialogVisible = ref(false)
const itemForm = ref({ product_id: '', quantity: 1, unit_price: 0 })

const isEditable = computed(() => order.value?.status === 'draft')

function genOrderNo() {
  const now = new Date()
  const ymd = now.toISOString().slice(0, 10).replace(/-/g, '')
  const rand = Math.floor(Math.random() * 9000 + 1000)
  return `PO${ymd}${rand}`
}

async function fetchSuppliers() {
  const { data, error } = await supabase.from('suppliers').select('id, name').order('name')
  if (!error) suppliers.value = data
}

async function fetchProducts() {
  const { data, error } = await supabase.from('products').select('id, sku, name, unit, cost_price').eq('is_active', true).order('name')
  if (!error) products.value = data
}

async function fetchOrder() {
  if (isNew.value) return
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('purchase_orders')
      .select('*, suppliers(name)')
      .eq('id', orderId.value)
      .single()
    if (error) throw error
    order.value = data

    const { data: itemData, error: itemError } = await supabase
      .from('purchase_order_items')
      .select('*, products(name, sku, unit)')
      .eq('purchase_order_id', orderId.value)
      .order('id')
    if (itemError) throw itemError
    items.value = itemData
  } catch (err) {
    ElMessage.error(err.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function handleCreate() {
  if (!createForm.value.supplier_id) {
    ElMessage.warning('请选择供应商')
    return
  }
  try {
    const { data, error } = await supabase
      .from('purchase_orders')
      .insert({
        order_no: genOrderNo(),
        supplier_id: createForm.value.supplier_id,
        order_date: createForm.value.order_date,
        notes: createForm.value.notes,
        status: 'draft'
      })
      .select()
      .single()
    if (error) throw error
    ElMessage.success('创建成功，请添加采购明细')
    router.replace(`/purchase/${data.id}`)
    orderId.value = data.id
    await fetchOrder()
  } catch (err) {
    ElMessage.error(err.message || '创建失败')
  }
}

function openItemDialog() {
  itemForm.value = { product_id: '', quantity: 1, unit_price: 0 }
  itemDialogVisible.value = true
}

function onProductChange(productId) {
  const p = products.value.find((x) => x.id === productId)
  if (p) itemForm.value.unit_price = p.cost_price || 0
}

async function handleAddItem() {
  if (!itemForm.value.product_id || itemForm.value.quantity <= 0) {
    ElMessage.warning('请选择商品并填写数量')
    return
  }
  try {
    const { error } = await supabase.from('purchase_order_items').insert({
      purchase_order_id: orderId.value,
      product_id: itemForm.value.product_id,
      quantity: itemForm.value.quantity,
      unit_price: itemForm.value.unit_price
    })
    if (error) throw error
    ElMessage.success('添加成功')
    itemDialogVisible.value = false
    await fetchOrder()
  } catch (err) {
    ElMessage.error(err.message || '添加失败')
  }
}

async function handleDeleteItem(row) {
  try {
    await ElMessageBox.confirm('确定删除该明细吗？', '提示', { type: 'warning' })
    const { error } = await supabase.from('purchase_order_items').delete().eq('id', row.id)
    if (error) throw error
    await fetchOrder()
  } catch (err) {
    if (err !== 'cancel') ElMessage.error(err.message || '删除失败')
  }
}

async function changeStatus(status) {
  const tips = {
    confirmed: '确认该采购单吗？',
    received: '确认入库吗？库存将自动增加。',
    cancelled: '确认取消该采购单吗？'
  }
  if (status === 'confirmed' && items.value.length === 0) {
    ElMessage.warning('请先添加采购明细')
    return
  }
  try {
    await ElMessageBox.confirm(tips[status], '提示', { type: 'warning' })
    const { error } = await supabase.from('purchase_orders').update({ status }).eq('id', orderId.value)
    if (error) throw error
    ElMessage.success('操作成功')
    await fetchOrder()
  } catch (err) {
    if (err !== 'cancel') ElMessage.error(err.message || '操作失败')
  }
}

async function saveNotes() {
  try {
    const { error } = await supabase.from('purchase_orders').update({ notes: order.value.notes }).eq('id', orderId.value)
    if (error) throw error
    ElMessage.success('已保存')
  } catch (err) {
    ElMessage.error(err.message || '保存失败')
  }
}

onMounted(async () => {
  await Promise.all([fetchSuppliers(), fetchProducts(), fetchOrder()])
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>{{ isNew ? '新建采购单' : `采购单详情 - ${order?.order_no}` }}</h2>
      <el-button @click="router.push('/purchase')">返回列表</el-button>
    </div>

    <!-- 新建表单 -->
    <el-card v-if="isNew">
      <el-form label-width="100px" style="max-width: 480px">
        <el-form-item label="供应商" required>
          <el-select v-model="createForm.supplier_id" placeholder="请选择供应商" filterable style="width: 100%">
            <el-option v-for="s in suppliers" :key="s.id" :label="s.name" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="采购日期">
          <el-date-picker v-model="createForm.order_date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="createForm.notes" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleCreate">创建采购单</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 详情 -->
    <template v-else>
      <el-card v-loading="loading" style="margin-bottom: 16px">
        <el-descriptions :column="3" border>
          <el-descriptions-item label="采购单号">{{ order?.order_no }}</el-descriptions-item>
          <el-descriptions-item label="供应商">{{ order?.suppliers?.name }}</el-descriptions-item>
          <el-descriptions-item label="日期">{{ order?.order_date }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="statusMap[order?.status]?.type">{{ statusMap[order?.status]?.label }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="总金额">¥{{ Number(order?.total_amount || 0).toFixed(2) }}</el-descriptions-item>
          <el-descriptions-item label="备注" :span="3">
            <el-input v-if="isEditable" v-model="order.notes" type="textarea" :rows="1" @blur="saveNotes" />
            <span v-else>{{ order?.notes || '-' }}</span>
          </el-descriptions-item>
        </el-descriptions>

        <div style="margin-top: 16px">
          <el-button v-if="order?.status === 'draft'" type="success" @click="changeStatus('confirmed')">确认采购单</el-button>
          <el-button v-if="order?.status === 'confirmed'" type="success" @click="changeStatus('received')">确认入库</el-button>
          <el-button v-if="['draft','confirmed'].includes(order?.status)" type="warning" @click="changeStatus('cancelled')">取消采购单</el-button>
        </div>
      </el-card>

      <el-card>
        <div class="page-header">
          <h3 style="margin: 0">采购明细</h3>
          <el-button v-if="isEditable" type="primary" :icon="Plus" @click="openItemDialog">添加商品</el-button>
        </div>

        <el-table :data="items" border stripe>
          <el-table-column label="商品编码" width="120">
            <template #default="{ row }">{{ row.products?.sku }}</template>
          </el-table-column>
          <el-table-column label="商品名称" min-width="160">
            <template #default="{ row }">{{ row.products?.name }}</template>
          </el-table-column>
          <el-table-column label="单位" width="80">
            <template #default="{ row }">{{ row.products?.unit }}</template>
          </el-table-column>
          <el-table-column prop="quantity" label="数量" width="100" />
          <el-table-column prop="unit_price" label="单价" width="100">
            <template #default="{ row }">¥{{ Number(row.unit_price).toFixed(2) }}</template>
          </el-table-column>
          <el-table-column prop="subtotal" label="小计" width="120">
            <template #default="{ row }">¥{{ Number(row.subtotal).toFixed(2) }}</template>
          </el-table-column>
          <el-table-column v-if="isEditable" label="操作" width="100">
            <template #default="{ row }">
              <el-button link type="danger" @click="handleDeleteItem(row)">删除</el-button>
            </template>
          </el-table-column>
        </el-table>
      </el-card>
    </template>

    <!-- 添加商品明细对话框 -->
    <el-dialog v-model="itemDialogVisible" title="添加采购明细" width="420px">
      <el-form label-width="80px">
        <el-form-item label="商品">
          <el-select v-model="itemForm.product_id" placeholder="请选择商品" filterable style="width: 100%" @change="onProductChange">
            <el-option v-for="p in products" :key="p.id" :label="`${p.name} (${p.sku})`" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="数量">
          <el-input-number v-model="itemForm.quantity" :min="0.01" :precision="2" style="width: 100%" />
        </el-form-item>
        <el-form-item label="单价">
          <el-input-number v-model="itemForm.unit_price" :min="0" :precision="2" style="width: 100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="itemDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleAddItem">添加</el-button>
      </template>
    </el-dialog>
  </div>
</template>
