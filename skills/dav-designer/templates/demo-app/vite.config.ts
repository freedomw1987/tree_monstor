import path from "node:path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"
import { viteSingleFile } from "vite-plugin-singlefile"

// Demo app 專用：Tailwind v4 ＋ "@/" alias ＋ build 成單檔 dist/index.html
// ⚠️ `viteSingleFile()` 唔加就 build 出多檔，拎唔走做 demo
export default defineConfig({
  plugins: [react(), tailwindcss(), viteSingleFile()],
  resolve: { alias: { "@": path.resolve(import.meta.dirname, "./src") } },
})
