/**
 * Template — React list page 加 search box + 2 層 empty state
 *
 * 由 pm-system 2026-06-09 拎出嚟 (ProjectDetailPage / RequirementDetailPage)。
 *
 * 用法:
 * 1. 複製成段 component body
 * 2. 將 "X" 改做你嘅 entity 名 (例如 Task, Bug, User)
 * 3. 將 `x` / `setX` 改做你嘅 state name
 * 4. 將 `x` list 嘅 field (例如 `x.title`) 改做你嘅 primary display field
 */

import { useState, useMemo } from 'react'
import { Plus, Search, /* ... other icons */ } from 'lucide-react'

// ── State ────────────────────────────────────────────────────────
//   const [x, setX] = useState<X[]>([])              // 已有
//   const [searchX, setSearchX] = useState('')         // ← 新加
//   const [showAddX, setShowAddX] = useState(false)    // 已有
//   const [isAddingX, setIsAddingX] = useState(false) // 已有

// ── useMemo filter ──────────────────────────────────────────────
const filteredX = useMemo(() => {
  const q = searchX.trim().toLowerCase()
  if (!q) return x
  return x.filter(item => item.title.toLowerCase().includes(q))
}, [x, searchX])

// ── Render ──────────────────────────────────────────────────────
return (
  <div>
    {/* Header — button 同 search input 並排 (RWD flex-col → sm:flex-row) */}
    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
      {hasAnyPermission(user, ['x.create']) && (
        <button
          onClick={() => { /* reset form fields, then: */ setShowAddX(true) }}
          className="btn-primary flex items-center gap-2 w-full sm:w-auto justify-center"
        >
          <Plus size={20} /><span>新建 X</span>
        </button>
      )}
      <div className="relative w-full sm:w-72">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
        <input
          type="text"
          value={searchX}
          onChange={(e) => setSearchX(e.target.value)}
          placeholder="搜尋 X..."
          aria-label="搜尋 X"
          className="w-full pl-9 pr-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
        />
      </div>
    </div>

    {/* 2 層 empty state ─ 順序重要: ① raw empty 先, ② filter empty 後 */}
    {x.length === 0 ? (
      // ① Raw empty — 真係冇 data
      <div className="card p-12 text-center">
        <YourIcon size={48} className="mx-auto text-gray-400 mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">暫無 X</h3>
        <p className="text-gray-500">為 XX 添加第一個 X</p>
      </div>
    ) : filteredX.length === 0 ? (
      // ② Filter empty — 搜尋無結果
      <div className="card p-12 text-center">
        <Search size={48} className="mx-auto text-gray-400 mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">無符合「{searchX}」嘅 X</h3>
        <p className="text-gray-500">試下其他關鍵字,或清空搜尋框</p>
      </div>
    ) : (
      // ③ 有 results
      <div className="space-y-3">
        {filteredX.map((item) => (
          <YourListItem
            key={item.id}
            item={item}
            onClick={...}
          />
        ))}
      </div>
    )}
  </div>
)

// ── Imports check ───────────────────────────────────────────────
// import { useEffect, useMemo, useState } from 'react'
// import { Plus, Search } from 'lucide-react'
// import { hasAnyPermission } from '../utils/permissions'

// ── 對應 common 嘅 `useMemo` 陷阱 ────────────────────────────────
// ❌ Inline filter — 每次 re-render 都行
//   {x.filter(item => item.title.toLowerCase().includes(searchX)).map(...)}
//
// ✅ useMemo — 只 source data / search string 改先做 work
//   const filteredX = useMemo(() => {...}, [x, searchX])
//   {filteredX.map(...)}

// ── 對應 empty state UX 陷阱 ────────────────────────────────────
// ❌ 合埋一個 empty state
//   {filteredX.length === 0 ? <div>暫無 X</div> : ...}
//
// ✅ 分兩層, 唔同原因用唔同 message
//   {x.length === 0 ? <div>暫無 X</div> : filteredX.length === 0 ? <div>無符合「{searchX}」嘅 X</div> : ...}
