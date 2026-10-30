// src/demo/routes.ts —— demo 路線（面板逐步指引用）
// 每 step = 目標 Surface ＋ 目標 route ＋ 一句「要講乜」
export type Surface =
  | "web-admin"
  | "mobile-app"
  | "tablet-app"
  | "cli-terminal"

export type DemoStep = {
  surface: Surface
  route: string
  title: string
  script: string
}

export const DEMO_ROUTES: DemoStep[] = [
  {
    surface: "mobile-app",
    route: "/m/orders/new",
    title: "手機落單",
    script: "客人在手機落單 —— 呢張單下一步就會出現在後台。",
  },
  {
    surface: "web-admin",
    route: "/w/orders",
    title: "後台見到新單",
    script: "切去後台，訂單列表第一行就係啱啱嗰張單（同一個 store）。",
  },
  {
    surface: "web-admin",
    route: "/w/dashboard",
    title: "審批後數字即刻變",
    script: "審批／結算完，儀表板統計即刻反映 —— 呢個就係 demo 嘅高潮。",
  },
]
