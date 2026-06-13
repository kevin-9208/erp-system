<script setup>
import { computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()

const activeMenu = computed(() => '/' + route.path.split('/')[1])

const menus = [
  { path: '/dashboard', icon: 'Odometer', label: '仪表盘' },
  { path: '/customers', icon: 'User', label: '客户管理' },
  { path: '/suppliers', icon: 'Shop', label: '供应商管理' },
  { path: '/products', icon: 'Goods', label: '商品管理' },
  { path: '/purchase', icon: 'ShoppingCart', label: '采购管理' },
  { path: '/sales', icon: 'Sell', label: '销售管理' },
  { path: '/inventory', icon: 'Box', label: '库存管理' },
  { path: '/reports', icon: 'TrendCharts', label: '报表系统' }
]

function handleMenuSelect(path) {
  router.push(path)
}

async function handleLogout() {
  await auth.logout()
  router.push('/login')
}
</script>

<template>
  <el-container class="layout-container">
    <el-aside width="200px" class="layout-aside">
      <div class="logo">ERP 管理系统</div>
      <el-menu
        :default-active="activeMenu"
        background-color="#001529"
        text-color="rgba(255,255,255,0.85)"
        active-text-color="#ffffff"
        @select="handleMenuSelect"
      >
        <el-menu-item v-for="m in menus" :key="m.path" :index="m.path">
          <el-icon><component :is="m.icon" /></el-icon>
          <span>{{ m.label }}</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="layout-header">
        <div></div>
        <div class="header-right">
          <span class="user-name">
            {{ auth.profile?.full_name || auth.user?.email }}
            <el-tag v-if="auth.isAdmin" size="small" type="warning" style="margin-left: 6px">管理员</el-tag>
          </span>
          <el-button text @click="handleLogout">退出登录</el-button>
        </div>
      </el-header>
      <el-main class="layout-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.layout-container {
  height: 100vh;
}

.layout-aside {
  background-color: #001529;
  overflow: hidden;
}

.logo {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-weight: 700;
  font-size: 16px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.layout-aside :deep(.el-menu) {
  border-right: none;
}

.layout-header {
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e4e7ed;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-name {
  font-size: 14px;
  color: #303133;
}

.layout-main {
  background-color: #f5f7fa;
}
</style>
