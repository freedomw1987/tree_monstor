// src/mock/store.ts —— 單一 mock store（跨 Module、跨 Surface 共用同一真相源）
// 規則：所有畫面經 action 改資料；唔准各自 local state 改，否則跨 surface 串連會斷
import { create } from "zustand"
import { persist } from "zustand/middleware"

import { seedOrders, type Order } from "./db"

export type DemoState = {
  orders: Order[]
  addOrder: (order: Order) => void
  approveOrder: (id: string) => void
  // 一鍵重設：每次示範都由同一個起點，唔會留低上次 demo 嘅髒資料
  reset: () => void
}

export const useDemoStore = create<DemoState>()(
  persist(
    (set) => ({
      orders: seedOrders,
      addOrder: (order) => set((s) => ({ orders: [order, ...s.orders] })),
      approveOrder: (id) =>
        set((s) => ({
          orders: s.orders.map((o) =>
            o.id === id ? { ...o, status: "approved" } : o,
          ),
        })),
      reset: () => set({ orders: seedOrders }),
    }),
    { name: "demo-store" },
  ),
)
