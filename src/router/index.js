import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/auth/Login.vue'),
    meta: { public: true }
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('../views/auth/Register.vue'),
    meta: { public: true }
  },
  {
    path: '/',
    component: () => import('../components/AppLayout.vue'),
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('../views/Dashboard.vue')
      },
      {
        path: 'customers',
        name: 'customers',
        component: () => import('../views/customers/CustomerList.vue')
      },
      {
        path: 'suppliers',
        name: 'suppliers',
        component: () => import('../views/suppliers/SupplierList.vue')
      },
      {
        path: 'products',
        name: 'products',
        component: () => import('../views/products/ProductList.vue')
      },
      {
        path: 'purchase',
        name: 'purchase',
        component: () => import('../views/purchase/PurchaseList.vue')
      },
      {
        path: 'purchase/:id',
        name: 'purchase-detail',
        component: () => import('../views/purchase/PurchaseDetail.vue')
      },
      {
        path: 'sales',
        name: 'sales',
        component: () => import('../views/sales/SalesList.vue')
      },
      {
        path: 'sales/:id',
        name: 'sales-detail',
        component: () => import('../views/sales/SalesDetail.vue')
      },
      {
        path: 'inventory',
        name: 'inventory',
        component: () => import('../views/inventory/InventoryList.vue')
      },
      {
        path: 'reports',
        name: 'reports',
        component: () => import('../views/reports/Reports.vue')
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach(async (to) => {
  // 确保 session 已知（刷新页面时）
  const { data } = await supabase.auth.getSession()
  const isLoggedIn = !!data.session

  if (!to.meta.public && !isLoggedIn) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.meta.public && isLoggedIn) {
    return { name: 'dashboard' }
  }
  return true
})

export default router
