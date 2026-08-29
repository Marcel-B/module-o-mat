import * as yup from 'yup'
import type { Module, ModuleFormValues, ModulePayload } from '../types'
import { isValidYoutubeUrl } from '../utils/youtube'

function emptyToUndefined(value: unknown, originalValue: unknown): unknown {
  if (originalValue === '' || originalValue === null || originalValue === undefined) {
    return undefined
  }
  return value
}

const optionalNonNegativeInteger = yup
  .number()
  .transform(emptyToUndefined)
  .integer('muss eine ganze Zahl sein')
  .min(0, 'darf nicht negativ sein')
  .nullable()
  .optional()

const optionalNonNegativeNumber = yup
  .number()
  .transform(emptyToUndefined)
  .min(0, 'darf nicht negativ sein')
  .nullable()
  .optional()

export const moduleSchema = yup.object({
  manufacturer: yup.string().trim().required('muss ausgefuellt werden'),
  name: yup.string().trim().required('muss ausgefuellt werden'),
  hp: yup
    .number()
    .transform(emptyToUndefined)
    .typeError('muss ausgefuellt werden')
    .integer('muss eine ganze Zahl sein')
    .moreThan(0, 'muss groesser als 0 sein')
    .required('muss ausgefuellt werden'),
  type: yup.string().trim().required('muss ausgefuellt werden'),
  subtypes: yup.array().of(yup.string().required()).default([]),
  current_draw_plus12v_ma: optionalNonNegativeInteger,
  current_draw_minus12v_ma: optionalNonNegativeInteger,
  current_draw_plus5v_ma: optionalNonNegativeInteger,
  depth_mm: optionalNonNegativeInteger,
  description: yup.string().nullable().optional(),
  manual_url: yup.string().trim().nullable().optional(),
  purchase_price: optionalNonNegativeNumber,
  current_value: optionalNonNegativeNumber,
  youtube_videos: yup
    .array()
    .of(
      yup.object({
        id: yup.mixed<number | string>().optional(),
        url: yup
          .string()
          .trim()
          .required('muss ausgefuellt werden')
          .test('youtube', 'muss eine gueltige YouTube-URL sein', isValidYoutubeUrl),
      }),
    )
    .default([]),
})

export const moduleTypeSchema = yup.object({
  name: yup.string().trim().required('muss ausgefuellt werden'),
})

export type ModuleSchema = yup.InferType<typeof moduleSchema>
export type ModuleTypeSchema = yup.InferType<typeof moduleTypeSchema>

export function emptyModuleValues(): ModuleFormValues {
  return {
    manufacturer: '',
    name: '',
    hp: null,
    type: '',
    subtypes: [],
    current_draw_plus12v_ma: null,
    current_draw_minus12v_ma: null,
    current_draw_plus5v_ma: null,
    depth_mm: null,
    description: '',
    manual_url: '',
    purchase_price: null,
    current_value: null,
    youtube_videos: [],
  }
}

export function moduleToFormValues(module: Module): ModuleFormValues {
  return {
    ...emptyModuleValues(),
    manufacturer: module.manufacturer || '',
    name: module.name || '',
    hp: module.hp ?? null,
    type: module.type || '',
    subtypes: [...(module.subtypes || [])],
    current_draw_plus12v_ma: module.current_draw_plus12v_ma ?? null,
    current_draw_minus12v_ma: module.current_draw_minus12v_ma ?? null,
    current_draw_plus5v_ma: module.current_draw_plus5v_ma ?? null,
    depth_mm: module.depth_mm ?? null,
    description: module.description || '',
    manual_url: module.manual_url || '',
    purchase_price: module.purchase_price ?? null,
    current_value: module.current_value ?? null,
    youtube_videos: (module.youtube_videos || []).map((video) => ({
      id: video.id,
      url: video.url,
    })),
  }
}

export function formValuesToPayload(values: ModuleFormValues): ModulePayload {
  const youtubeVideos = (values.youtube_videos || [])
    .map((video) => ({ url: (video.url || '').trim() }))
    .filter((video) => video.url)

  return {
    manufacturer: values.manufacturer.trim(),
    name: values.name.trim(),
    hp: values.hp as number,
    type: values.type,
    subtypes: (values.subtypes || []).filter((subtype) => subtype && subtype !== values.type),
    current_draw_plus12v_ma: values.current_draw_plus12v_ma ?? null,
    current_draw_minus12v_ma: values.current_draw_minus12v_ma ?? null,
    current_draw_plus5v_ma: values.current_draw_plus5v_ma ?? null,
    depth_mm: values.depth_mm ?? null,
    description: values.description?.trim() || null,
    manual_url: values.manual_url?.trim() || null,
    purchase_price: values.purchase_price ?? null,
    current_value: values.current_value ?? null,
    youtube_videos: youtubeVideos,
  }
}
