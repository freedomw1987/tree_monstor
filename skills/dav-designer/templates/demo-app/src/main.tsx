// src/main.tsx —— demo app 入口（模板）
// 規則：1) 用 HashRouter（dist/index.html 雙擊 file:// 開得，BrowserRouter 會 SecurityError）
//       2) 每個 surface 一條 route 前綴：/w=web-admin /m=mobile-app /t=cli-terminal
import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { HashRouter, Navigate, Route, Routes } from "react-router-dom"

import { WebAdminLayout } from "@/components/shell/web-admin-layout"
import { MobileLayout } from "@/components/shell/mobile-layout"
import { TerminalLayout } from "@/components/shell/terminal-layout"
import "./index.css"

export default function App() {
  return (
    <HashRouter>
      <Routes>
        {/* 預設入口 → 第一個 surface */}
        <Route path="/" element={<Navigate to="/w/dashboard" replace />} />
        {/* 每個 surface 一條 route 前綴 */}
        <Route path="/w/*" element={<WebAdminLayout />} />
        <Route path="/m/*" element={<MobileLayout />} />
        <Route path="/t/*" element={<TerminalLayout />} />
      </Routes>
    </HashRouter>
  )
}

const root = document.getElementById("root")
if (root) {
  createRoot(root).render(
    <StrictMode>
      <App />
    </StrictMode>,
  )
}
