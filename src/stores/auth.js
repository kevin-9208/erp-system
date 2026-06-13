import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    profile: null,
    initialized: false
  }),

  getters: {
    isLoggedIn: (state) => !!state.user,
    isAdmin: (state) => state.profile?.role === 'admin'
  },

  actions: {
    async init() {
      const { data } = await supabase.auth.getSession()
      this.user = data.session?.user || null
      if (this.user) {
        await this.fetchProfile()
      }
      this.initialized = true

      supabase.auth.onAuthStateChange(async (_event, session) => {
        this.user = session?.user || null
        if (this.user) {
          await this.fetchProfile()
        } else {
          this.profile = null
        }
      })
    },

    async fetchProfile() {
      if (!this.user) return
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', this.user.id)
        .single()
      if (!error) this.profile = data
    },

    async login(email, password) {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      this.user = data.user
      await this.fetchProfile()
      return data
    },

    async register(email, password, fullName) {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: { full_name: fullName }
        }
      })
      if (error) throw error
      return data
    },

    async logout() {
      await supabase.auth.signOut()
      this.user = null
      this.profile = null
    }
  }
})
