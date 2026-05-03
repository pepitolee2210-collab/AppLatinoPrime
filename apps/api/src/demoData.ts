import type { AutomationFlow, DashboardSummary, PremiumService, VaultDocument } from "@usa-latino-prime/shared";

export const demoUserId = "11111111-1111-4111-8111-111111111111";

export const demoDashboard: DashboardSummary = {
  userName: "Marisol",
  tier: "base",
  status: "yellow",
  totals: {
    documentsExpiring: 4,
    pendingTasks: 2,
    activeCases: 1,
    newMessages: 0
  },
  alerts: [
    {
      id: "court-1",
      kind: "court_hearing",
      title: "Audiencia en corte",
      detail: "EOIR: 19 de mayo de 2026. Confirma sala, hora y direccion.",
      dueAt: "2026-05-19T09:00:00-06:00",
      dueLabel: "17 dias",
      severity: "yellow",
      source: "EOIR"
    },
    {
      id: "ead-1",
      kind: "ead_expiration",
      title: "Expira tu EAD",
      detail: "I-765 (C09). Preparar renovacion con margen.",
      dueAt: "2026-06-30T17:00:00-06:00",
      dueLabel: "59 dias",
      severity: "yellow",
      source: "USCIS"
    },
    {
      id: "address-1",
      kind: "address_change",
      title: "Cambio de direccion pendiente",
      detail: "AR-11 listo para firma. EOIR-33 requiere revision si tienes corte.",
      dueAt: "2026-05-05T17:00:00-06:00",
      dueLabel: "3 dias",
      severity: "red",
      source: "USCIS"
    }
  ]
};

export const demoDocuments: VaultDocument[] = [
  {
    id: "doc-1",
    title: "I-797C Notice of Action",
    agency: "USCIS",
    docType: "I797C",
    capturedAt: "2026-04-27",
    offlineAvailable: true,
    status: "classified"
  },
  {
    id: "doc-2",
    title: "EAD I-766 Card",
    agency: "USCIS",
    docType: "EAD_CARD",
    capturedAt: "2026-04-12",
    offlineAvailable: true,
    status: "classified"
  }
];

export const demoAutomations: AutomationFlow[] = [
  {
    id: "auto-aaf",
    filingType: "ANNUAL_ASYLUM_FEE",
    title: "Pago Tarifa Anual de Asilo",
    description: "Prepara datos y comprobante para el portal oficial USCIS.",
    status: "not_started",
    progress: 0,
    legalReviewRequired: false
  },
  {
    id: "auto-1",
    filingType: "AR11",
    title: "AR-11 Cambio de direccion",
    description: "Actualiza tu direccion con USCIS.",
    status: "ready_to_sign",
    progress: 82,
    legalReviewRequired: false
  },
  {
    id: "auto-2",
    filingType: "CHANGE_OF_VENUE",
    title: "Mocion para cambio de sede",
    description: "Prepara borrador para revision humana.",
    status: "draft",
    progress: 35,
    legalReviewRequired: true
  }
];

export const demoPremiumServices: PremiumService[] = [
  {
    id: "77777777-7777-4777-8777-777777777771",
    serviceType: "ANNUALITY_PAYMENT",
    title: "Pago de anualidades",
    description: "Prueba gratis: administra anualidades, comprobantes y recordatorios sin pago.",
    priceMode: "free",
    enabled: true
  },
  {
    id: "77777777-7777-4777-8777-777777777772",
    serviceType: "EXPERT_REVIEW",
    title: "Revision experta",
    description: "Acompanamiento humano para casos de alta complejidad.",
    priceMode: "free",
    enabled: true
  }
];
