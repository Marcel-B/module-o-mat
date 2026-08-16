import { createApp } from 'vue'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import ConfirmationService from 'primevue/confirmationservice'
import ToastService from 'primevue/toastservice'
import Tooltip from 'primevue/tooltip'
import 'primeicons/primeicons.css'

import App from './App.vue'
import router from './router'
import ModuleOMatPreset from './theme/preset'
import './style.css'

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(PrimeVue, {
  theme: {
    preset: ModuleOMatPreset,
    options: {
      darkModeSelector: '.p-dark',
      cssLayer: {
        name: 'primevue',
        order: 'theme, base, primevue, utilities',
      },
    },
  },
  locale: {
    accept: 'Ja',
    reject: 'Nein',
    choose: 'Auswählen',
    upload: 'Hochladen',
    cancel: 'Abbrechen',
    dayNames: ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'],
    dayNamesShort: ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'],
    dayNamesMin: ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'],
    monthNames: [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ],
    monthNamesShort: [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ],
    emptyFilterMessage: 'Keine Ergebnisse',
    emptyMessage: 'Keine Einträge',
    emptySearchMessage: 'Keine Ergebnisse gefunden',
    selectionMessage: '{0} Einträge ausgewählt',
  },
})
app.use(ToastService)
app.use(ConfirmationService)
app.directive('tooltip', Tooltip)

app.mount('#app')
