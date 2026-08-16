export type ModuleFilters = {
  q: string
  type: string
  minHp: string | number
  maxHp: string | number
}

export type YoutubeVideo = {
  id?: number
  url: string
  position?: number
}

export type PriceRange = {
  min: number
  max: number
  count: number
  last_observed_on: string
} | null

export type PriceObservation = {
  id: number
  amount: number
  currency: string
  source: string
  source_url: string | null
  observed_on: string
  notes: string | null
}

export type Module = {
  id: number
  manufacturer: string
  name: string
  hp: number
  type: string
  subtypes: string[]
  current_draw_plus12v_ma: number | null
  current_draw_minus12v_ma: number | null
  current_draw_plus5v_ma: number | null
  depth_mm: number | null
  description: string | null
  manual_url: string | null
  purchase_price: number | null
  current_value: number | null
  has_manual: boolean
  manual_pdf_filename: string | null
  manual_pdf_content_type: string | null
  manual_pdf_size_bytes: number | null
  youtube_videos: YoutubeVideo[]
  price_range: PriceRange
  price_observations?: PriceObservation[]
  inserted_at: string
  updated_at: string
}

export type InventoryStats = {
  count: number
  total_hp: number
  total_width_mm: number
  total_width_cm: number
  total_width_m: number
  total_purchase_price: number
  total_current_value: number
}

export type ModuleType = {
  id: number
  name: string
  fallback: boolean
  used: boolean
}

export type ModulePayload = {
  manufacturer: string
  name: string
  hp: number
  type: string
  subtypes: string[]
  current_draw_plus12v_ma: number | null
  current_draw_minus12v_ma: number | null
  current_draw_plus5v_ma: number | null
  depth_mm: number | null
  description: string | null
  manual_url: string | null
  purchase_price: number | null
  current_value: number | null
  youtube_videos: Array<{ url: string }>
}

export type ModuleFormValues = {
  manufacturer: string
  name: string
  hp: number | null
  type: string
  subtypes: string[]
  current_draw_plus12v_ma: number | null
  current_draw_minus12v_ma: number | null
  current_draw_plus5v_ma: number | null
  depth_mm: number | null
  description: string
  manual_url: string
  purchase_price: number | null
  current_value: number | null
  youtube_videos: YoutubeVideo[]
}

export type ModuleFormSubmit = {
  payload: ModulePayload
  pdfFile: File | null
  removeManual: boolean
  copyManual: boolean
}

export type ModuleFormMode = 'new' | 'edit' | 'duplicate' | 'show'

export type ModuleGroup = {
  type: string
  modules: Module[]
}

export type ModuleListResponse = {
  modules: Module[]
  stats: InventoryStats
}

export type ModuleResponse = {
  module: Module
}

export type ModuleTypeListResponse = {
  module_types: ModuleType[]
}

export type ModuleTypeResponse = {
  module_type: ModuleType
}

export type ManufacturersResponse = {
  manufacturers: string[]
}

export type BackupImportResponse = {
  imported: boolean
}

export type ApiErrorBody = {
  error?: string
  details?: Record<string, string[] | string> | null
}
