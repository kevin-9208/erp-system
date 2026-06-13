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
const dialogTitle = ref('新增客户')
const formRef = ref(null)
const form = ref(emptyForm())

function emptyForm() {
  return {
    id: null,
    code: '',
    name: '',
    contact_person: '',
    phone: '',
    email: '',
    address: '',
    notes: ''
  }
}

const rules = {
  name: [{ required: true, message: '请输入客户名称', trigger: 'blur' }]
}

async function fetchList() {
  loading.value = true
  try {
    let query = supabase.from('customers').select('*', { count: 'exact' })
    if (keyword.value) {
      query = query.or(`name.ilike.%${keyword.value}%,code.ilike.%${keyword.value}%,phone.ilike.%${keyword.value}%`)
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
  dialogTitle.value = '新增客户'
  form.value = emptyForm()
  dialogVisible.value = true
}

function openEdit(row) {
  dialogTitle.value = '编辑客户'
  form.value = { ...row }
  dialogVisible.value = true
}

async function handleSubmit() {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  try {
    if (form.value.id) {
      const { id, created_by, created_at, updated_at, ...payload } = form.value
      const { error } = await supabase.from('customers').update(payload).eq('id', id)
      if (error) throw error
      ElMessage.success('更新成功')
    } else {
      const { id, ...payload } = form.value
      const { error } = await supabase.from('customers').insert(payload)
      if (error) throw error
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
    await ElMessageBox.confirm(`确定删除客户「${row.name}」吗？`, '提示', { type: 'warning' })
    const { error } = await supabase.from('customers').delete().eq('id', row.id)
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
      <h2>客户管理</h2>
      <el-button type="primary" :icon="Plus" @click="openCreate">新增客户</el-button>
    </div>

    <div class="search-bar">
      <el-input v-model="keyword" placeholder="搜索客户名称/编号/电话" style="width: 260px" clearable @keyup.enter="handleSearch" />
      <el-button :icon="Search" @click="handleSearch">搜索</el-button>
    </div>

    <el-table :data="list" v-loading="loading" border stripe>
      <el-table-column prop="code" label="编号" width="120" />
      <el-table-column prop="name" label="客户名称" min-width="160" />
      <el-table-column prop="contact_person" label="联系人" width="120" />
      <el-table-column prop="phone" label="电话" width="140" />
      <el-table-column prop="email" label="邮箱" min-width="160" />
      <el-table-column prop="address" label="地址" min-width="200" show-overflow-tooltip />
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

    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="500px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="客户编号" prop="code">
          <el-input v-model="form.code" placeholder="如 CUS-001" />
        </el-form-item>
        <el-form-item label="客户名称" prop="name">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="联系人" prop="contact_person">
          <el-input v-model="form.contact_person" />
        </el-form-item>
        <el-form-item label="电话" prop="phone">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="form.email" />
        </el-form-item>
        <el-form-item label="地址" prop="address">
          <el-input v-model="form.address" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="备注" prop="notes">
          <el-input v-model="form.notes" type="textarea" :rows="2" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
