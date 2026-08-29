import { FilterMatchMode, FilterOperator } from "@primevue/core/api";

export type TableFilters = {
  global: { value: string | null; matchMode: string };
  type: { value: string | null; matchMode: string };
  manufacturer: { value: string | null; matchMode: string };
  hp: {
    operator: string;
    constraints: [
      { value: number | null; matchMode: string },
      { value: number | null; matchMode: string },
    ];
  };
};

export function emptyTableFilters(): TableFilters {
  return {
    global: { value: null, matchMode: FilterMatchMode.CONTAINS },
    type: { value: null, matchMode: FilterMatchMode.EQUALS },
    manufacturer: { value: null, matchMode: FilterMatchMode.EQUALS },
    hp: {
      operator: FilterOperator.AND,
      constraints: [
        { value: null, matchMode: FilterMatchMode.GREATER_THAN_OR_EQUAL_TO },
        { value: null, matchMode: FilterMatchMode.LESS_THAN_OR_EQUAL_TO },
      ],
    },
  };
}
