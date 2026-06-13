<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search } from '@element-plus/icons-vue'
import { supabase } from '../../lib/supabase'

const list = ref([])
const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)

const dialogVisible = ref(false)
const dialogTitle = ref('新增商品')
const formRef = ref(null)
const uploading = ref(false)
const form = ref(emptyForm())

function emptyForm() {
  return {
    id: null,
    sku: '',
    name: '',
    category: '',
    unit: '个',
    cost_price: 0,
    sale_price: 0,
    image_url: '',
    description: '',
    is_active: true
  }
}

const rules = {
  sku: [{ required: true, message: '请输入商品编码', trigger: 'blur' }],
  name: [{ required: true, message: '请输入商品名称', trigger: 'blur' }]
}

async function fetchList() {
  loading.value = true
  try {
    let query = supabase.from('products').select('*', { count: 'exact' })
    if (keyword.value) {
      query = query.or(`name.ilike.%${keyword.value}%,sku.ilike.%${keyword.value}%,category.ilike.%${keyword.value}%`)
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

function handleSearch() {
  page.value = 1
  fetchList()
}

function handlePageChange(p) {
  page.value = p
  fetchList()
}

function openCreate() {
  dialogTitle.value = '新增商品'
  form.value = emptyForm()
  dialogVisible.value = true
}

function openEdit(row) {
  dialogTitle.value = '编辑商品'
  form.value = { ...row }
  dialogVisible.value = true
}

async function handleImageChange(uploadFile) {
  const file = uploadFile.raw
  if (!file) return

  uploading.value = true
  try {
    const ext = file.name.split('.').pop()
    const path = `${form.value.sku || 'tmp'}_${Date.now()}.${ext}`
    const { error: uploadError } = await supabase.storage
      .from('product-images')
      .upload(path, file, { upsert: true })
    if (uploadError) throw uploadError

    const { data } = supabase.storage.from('product-images').getPublicUrl(path)
    form.value.image_url = data.publicUrl
    ElMessage.success('图片上传成功')
  } catch (err) {
    ElMessage.error(err.message || '图片上传失败')
  } finally {
    uploading.value = false
  }
}

async function handleSubmit() {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  try {
    if (form.value.id) {
      const { id, created_by, created_at, updated_at, ...payload } = form.value
      const { error } = await supabase.from('products').update(payload).eq('id', id)
      if (error) throw error
      ElMessage.success('更新成功')
    } else {
      const { id, ...payload } = form.value
      const { data, error } = await supabase.from('products').insert(payload).select().single()
      if (error) throw error
      // 初始化库存记录
      await supabase.from('inventory').insert({ product_id: data.id, warehouse: '主仓库', quantity: 0 })
      ElMessage.success('新增成功')
    }
    dialogVisible.value = false
    fetchList()
  } catch (err) {
    ElMessage.error(err.message || '保存失败')
  }
}

async function handleDelete(row) {
  try {
    await ElMessageBox.confirm(`确定删除商品「${row.name}」吗？`, '提示', { type: 'warning' })
    const { error } = await supabase.from('products').delete().eq('id', row.id)
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
      <h2>商品管理</h2>
      <el-button type="primary" :icon="Plus" @click="openCreate">新增商品</el-button>
    </div>

    <div class="search-bar">
      <el-input v-model="keyword" placeholder="搜索商品名称/编码/分类" style="width: 260px" clearable @keyup.enter="handleSearch" />
      <el-button :icon="Search" @click="handleSearch">搜索</el-button>
    </div>

    <el-table :data="list" v-loading="loading" border stripe>
      <el-table-column label="图片" width="80">
        <template #default="{ row }">
          <el-image v-if="row.image_url" :src="row.image_url" style="width: 40px; height: 40px" fit="cover" />
          <span v-else style="color: #c0c4cc">无</span>
        </template>
      </el-table-column>
      <el-table-column prop="sku" label="编码" width="120" />
      <el-table-column prop="name" label="商品名称" min-width="160" />
      <el-table-column prop="category" label="分类" width="120" />
      <el-table-column prop="unit" label="单位" width="80" />
      <el-table-column prop="cost_price" label="成本价" width="100">
        <template #default="{ row }">¥{{ Number(row.cost_price).toFixed(2) }}</template>
      </el-table-column>
      <el-table-column prop="sale_price" label="销售价" width="100">
        <template #default="{ row }">¥{{ Number(row.sale_price).toFixed(2) }}</template>
      </el-table-column>
      <el-table-column prop="is_active" label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '停用' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="160" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link type="danger" @click="handleDelete(row)">删除</el-button>
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

    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="520px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="商品编码" prop="sku">
          <el-input v-model="form.sku" placeholder="如 SKU-001" />
        </el-form-item>
        <el-form-item label="商品名称" prop="name">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="分类" prop="category">
          <el-input v-model="form.category" />
        </el-form-item>
        <el-form-item label="单位" prop="unit">
          <el-input v-model="form.unit" style="width: 120px" />
        </el-form-item>
        <el-form-item label="成本价" prop="cost_price">
          <el-input-number v-model="form.cost_price" :min="0" :precision="2" style="width: 160px" />
        </el-form-item>
        <el-form-item label="销售价" prop="sale_price">
          <el-input-number v-model="form.sale_price" :min="0" :precision="2" style="width: 160px" />
        </el-form-item>
        <el-form-item label="图片">
          <el-upload
            :auto-upload="false"
            :show-file-list="false"
            accept="image/*"
            :on-change="handleImageChange"
          >
            <el-button :loading="uploading">上传图片</el-button>
          </el-upload>
          <el-image v-if="form.image_url" :src="form.image_url" style="width: 60px; height: 60px; margin-left: 12px" fit="cover" />
        </el-form-item>
        <el-form-item label="描述" prop="description">
          <el-input v-model="form.description" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="状态">
          <el-switch v-model="form.is_active" active-text="启用" inactive-text="停用" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
