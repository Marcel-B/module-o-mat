import { definePreset } from '@primeuix/themes'
import Aura from '@primeuix/themes/aura'

const ModuleOMatPreset = definePreset(Aura, {
  semantic: {
    primary: {
      50: '#edfff6',
      100: '#d1ffea',
      200: '#a3ffd5',
      300: '#67f5b8',
      400: '#2ee6a0',
      500: '#00c985',
      600: '#00a86d',
      700: '#008456',
      800: '#066847',
      900: '#07553c',
      950: '#003022',
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
        primary: {
          color: '{primary.600}',
          contrastColor: '#052e1c',
          hoverColor: '{primary.700}',
          activeColor: '{primary.800}',
        },
      },
      dark: {
        surface: {
          0: '#0b0d12',
          50: '#11141c',
          100: '#181c26',
          200: '#222734',
          300: '#323848',
          400: '#4b5368',
          500: '#6d758c',
          600: '#9098ad',
          700: '#b4bac9',
          800: '#d5d9e3',
          900: '#eceef4',
          950: '#f7f8fb',
        },
        primary: {
          color: '{primary.400}',
          contrastColor: '#052e1c',
          hoverColor: '{primary.300}',
          activeColor: '{primary.200}',
        },
        highlight: {
          background: 'color-mix(in srgb, {primary.400}, transparent 82%)',
          focusBackground: 'color-mix(in srgb, {primary.400}, transparent 72%)',
          color: '{surface.950}',
          focusColor: '{surface.950}',
        },
        mask: {
          background: 'rgba(6, 8, 12, 0.72)',
          color: '{surface.800}',
        },
        formField: {
          background: '{surface.50}',
          disabledBackground: '{surface.200}',
          filledBackground: '{surface.100}',
          filledHoverBackground: '{surface.100}',
          filledFocusBackground: '{surface.100}',
          borderColor: '{surface.300}',
          hoverBorderColor: '{surface.400}',
          focusBorderColor: '{primary.color}',
          color: '{surface.900}',
          disabledColor: '{surface.500}',
          placeholderColor: '{surface.500}',
          floatLabelColor: '{surface.500}',
          floatLabelFocusColor: '{primary.color}',
          floatLabelActiveColor: '{surface.500}',
          iconColor: '{surface.500}',
        },
        text: {
          color: '{surface.900}',
          hoverColor: '{surface.950}',
          mutedColor: '{surface.500}',
          hoverMutedColor: '{surface.400}',
        },
        content: {
          background: '{surface.50}',
          hoverBackground: '{surface.100}',
          borderColor: '{surface.200}',
          color: '{text.color}',
          hoverColor: '{text.hover.color}',
        },
        overlay: {
          select: {
            background: '{surface.100}',
            borderColor: '{surface.300}',
            color: '{text.color}',
          },
          popover: {
            background: '{surface.100}',
            borderColor: '{surface.300}',
            color: '{text.color}',
          },
          modal: {
            background: '{surface.50}',
            borderColor: '{surface.300}',
            color: '{text.color}',
          },
        },
        list: {
          option: {
            focusBackground: '{surface.200}',
            selectedBackground: '{highlight.background}',
            selectedFocusBackground: '{highlight.focus.background}',
            color: '{text.color}',
            focusColor: '{text.hover.color}',
            selectedColor: '{highlight.color}',
            selectedFocusColor: '{highlight.focus.color}',
            icon: {
              color: '{surface.500}',
              focusColor: '{surface.400}',
            },
          },
          optionGroup: {
            background: 'transparent',
            color: '{text.muted.color}',
          },
        },
        navigation: {
          item: {
            focusBackground: '{surface.200}',
            activeBackground: '{surface.200}',
            color: '{text.color}',
            focusColor: '{text.hover.color}',
            activeColor: '{text.hover.color}',
            icon: {
              color: '{surface.500}',
              focusColor: '{surface.400}',
              activeColor: '{surface.400}',
            },
          },
          submenuLabel: {
            background: 'transparent',
            color: '{text.muted.color}',
          },
          submenuIcon: {
            color: '{surface.500}',
            focusColor: '{surface.400}',
            activeColor: '{surface.400}',
          },
        },
      },
    },
  },
  components: {
    button: {
      colorScheme: {
        dark: {
          root: {
            secondary: {
              background: '{surface.100}',
              hoverBackground: '{surface.200}',
              activeBackground: '{surface.300}',
              borderColor: '{surface.200}',
              hoverBorderColor: '{surface.300}',
              activeBorderColor: '{surface.300}',
              color: '{surface.800}',
              hoverColor: '{surface.900}',
              activeColor: '{surface.950}',
            },
          },
          outlined: {
            secondary: {
              hoverBackground: '{surface.100}',
              activeBackground: '{surface.200}',
              borderColor: '{surface.300}',
              color: '{surface.700}',
            },
          },
          text: {
            secondary: {
              hoverBackground: '{surface.100}',
              activeBackground: '{surface.200}',
              color: '{surface.600}',
            },
          },
        },
      },
    },
    datatable: {
      colorScheme: {
        dark: {
          root: {
            borderColor: '{content.border.color}',
          },
          row: {
            stripedBackground: '{surface.100}',
          },
          bodyCell: {
            selectedBorderColor: '{primary.700}',
          },
        },
      },
    },
  },
})

export default ModuleOMatPreset
