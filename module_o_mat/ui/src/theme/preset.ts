import { definePreset } from '@primeuix/themes'
import Aura from '@primeuix/themes/aura'

const ModuleOMatPreset = definePreset(Aura, {
  semantic: {
    primary: {
      50: '#fff4ed',
      100: '#ffe6d4',
      200: '#ffc9a8',
      300: '#ffa371',
      400: '#ff7438',
      500: '#fd4f00',
      600: '#e04300',
      700: '#ba3302',
      800: '#942a0c',
      900: '#78260d',
      950: '#411005',
    },
    colorScheme: {
      light: {
        surface: {
          0: '#ffffff',
          50: '#f8f7f6',
          100: '#f1efed',
          200: '#e7e4e1',
          300: '#d4cfc9',
          400: '#b4ada4',
          500: '#8a8278',
          600: '#6b645c',
          700: '#524c46',
          800: '#3a3632',
          900: '#1c1917',
          950: '#12100e',
        },
      },
      dark: {
        surface: {
          0: '#12141a',
          50: '#1a1d24',
          100: '#22262f',
          200: '#2c313c',
          300: '#3a4150',
          400: '#5b6475',
          500: '#8891a3',
          600: '#b4bccb',
          700: '#d5dae3',
          800: '#eceff4',
          900: '#f7f8fb',
          950: '#ffffff',
        },
      },
    },
  },
})

export default ModuleOMatPreset
