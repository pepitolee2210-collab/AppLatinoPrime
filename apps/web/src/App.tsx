import {
  Bell,
  BookOpen,
  CalendarDays,
  CheckSquare,
  ChevronRight,
  ClipboardCheck,
  Cloud,
  CreditCard,
  Database,
  Download,
  ExternalLink,
  FileCheck2,
  FileText,
  Folder,
  Grid2X2,
  Home,
  Landmark,
  Loader2,
  Lock,
  LogIn,
  LogOut,
  MapPin,
  Menu,
  MessageCircle,
  Plus,
  Search,
  ShieldCheck,
  Share2,
  Smartphone,
  Sparkles,
  WalletCards,
  Zap,
  ListChecks
} from "lucide-react";
import { lazy, Suspense, useEffect, useMemo, useState } from "react";
import type {
  Agency,
  AlertKind,
  AutomationFlow,
  CriticalAlert,
  DashboardSummary,
  PremiumService,
  PremiumServiceType,
  SmartFolder,
  StatusSeverity,
  VaultDocument
} from "@usa-latino-prime/shared";
import micasoPrimeLogo from "./assets/landing/micaso-prime-logo.png";
import { resourceRows } from "./data/demo";
import {
  useAppData,
  type ActiveWorkflow,
  type AddCaseInput,
  type AddCriticalDateInput,
  type CaseSummary,
  type CompleteOnboardingInput,
  type DmvAttemptAnswerInput,
  type DmvExamConfig,
  type DmvLearningModule,
  type DmvPracticeQuestion,
  type RecordDmvAttemptInput,
  type StateOfficialSource,
  type UploadDocumentInput,
  type UserProfile
} from "./hooks/useAppData";

const LandingPage = lazy(() => import("./components/LandingPage").then((module) => ({ default: module.LandingPage })));

type TabId = "home" | "documents" | "automation" | "utilities" | "more";
type DataMode = "preview" | "auth_required" | "live";
type GuideStep = {
  action: string;
  body: string;
  icon: typeof Home;
  kicker: string;
  tab: TabId;
  tips: string[];
  title: string;
};
type SectionHelp = {
  body: string;
  kicker: string;
  steps: string[];
  title: string;
};
type PwaInstallChoice = {
  outcome: "accepted" | "dismissed";
  platform?: string;
};
type BeforeInstallPromptEvent = Event & {
  platforms: string[];
  prompt: () => Promise<void>;
  userChoice: Promise<PwaInstallChoice>;
};
type PwaInstallEnvironment = {
  isAndroid: boolean;
  isIos: boolean;
  isMobile: boolean;
  isStandalone: boolean;
};

const GUIDE_STORAGE_KEY = "micaso-prime-guide-dismissed";

const tabs: Array<{ id: TabId; label: string; icon: typeof Home }> = [
  { id: "home", label: "Inicio", icon: Home },
  { id: "documents", label: "Documentos", icon: FileText },
  { id: "automation", label: "Automatiza", icon: Zap },
  { id: "utilities", label: "Utilidades", icon: Grid2X2 },
  { id: "more", label: "Mas", icon: Menu }
];

const tabIds = new Set<TabId>(["home", "documents", "automation", "utilities", "more"]);

const guideSteps: GuideStep[] = [
  {
    action: "Ver mi panel",
    body: "Aqui miras si todo esta en orden, que fechas requieren atencion y cual es el siguiente paso.",
    icon: Home,
    kicker: "Paso 1",
    tab: "home",
    tips: ["Revisa el semaforo primero.", "Agrega fechas o casos cuando recibas un aviso."],
    title: "Empieza por tu estado del dia"
  },
  {
    action: "Abrir documentos",
    body: "Sube pasaporte, I-94, recibos, permisos o cartas de corte. La idea es que nunca dependas de fotos sueltas.",
    icon: Folder,
    kicker: "Paso 2",
    tab: "documents",
    tips: ["Sube primero el documento mas importante.", "Usa nombres claros para encontrarlos rapido."],
    title: "Ordena tus documentos clave"
  },
  {
    action: "Abrir automatizaciones",
    body: "Responde preguntas simples y genera paquetes PDF para revisar antes de firmar o enviar.",
    icon: FileCheck2,
    kicker: "Paso 3",
    tab: "automation",
    tips: ["Completa tu perfil antes de generar.", "Revisa cada PDF antes de usarlo."],
    title: "Prepara formularios guiados"
  },
  {
    action: "Abrir utilidades",
    body: "Estudia para el DMV, practica preguntas y consulta recursos locales segun tu estado.",
    icon: Grid2X2,
    kicker: "Paso 4",
    tab: "utilities",
    tips: ["Empieza por la guia de estudio.", "Luego practica con preguntas del simulador."],
    title: "Aprende y practica por estado"
  },
  {
    action: "Abrir servicios",
    body: "Cuando algo sea complejo, solicita apoyo humano y manten tu historial organizado dentro del mismo sistema.",
    icon: MessageCircle,
    kicker: "Paso 5",
    tab: "more",
    tips: ["Usa soporte para dudas complejas.", "La app organiza, no reemplaza asesoria legal."],
    title: "Pide ayuda cuando la necesites"
  }
];

const documentVaultHelp: SectionHelp = {
  body: "Usa esta pantalla como caja fuerte. Primero guarda los documentos que pueden pedirte en una cita, corte o tramite.",
  kicker: "Boveda",
  steps: [
    "Escribe un nombre simple: Recibo I-765, I-94, Pasaporte o Corte.",
    "Sube una foto clara o PDF completo.",
    "Si tienes texto detectado, pegalo para mejorar la clasificacion."
  ],
  title: "Que debes guardar aqui"
};

const automationHelp: SectionHelp = {
  body: "Cada flujo te hace preguntas y arma un paquete para revisar antes de firmar, enviar o pagar en el portal oficial.",
  kicker: "Automatiza",
  steps: [
    "Elige el tramite que necesitas.",
    "Llena cada campo con datos iguales a tus documentos.",
    "Guarda respuestas, genera PDF y revisa todo antes de usarlo."
  ],
  title: "Como preparar un formulario"
};

const utilityHelp: SectionHelp = {
  body: "Aqui el usuario estudia antes de practicar. La meta es aprender la regla oficial y luego responder como en un simulador.",
  kicker: "Utilidades",
  steps: [
    "Empieza en Estudiar y abre un tema.",
    "Lee claves, error comun y estrategia de respuesta.",
    "Despues practica por tema o examen completo."
  ],
  title: "Como usar el simulador DMV"
};

const servicesHelp: SectionHelp = {
  body: "Estos servicios separan lo automatizable de lo que necesita revision humana, para no prometer asesoria legal automatica.",
  kicker: "Servicios",
  steps: [
    "Activa anualidades para organizar recordatorios y comprobantes.",
    "Solicita revision experta si el caso es delicado.",
    "Revisa el seguimiento especial para ver el progreso."
  ],
  title: "Cuando pedir apoyo adicional"
};

function getPwaInstallEnvironment(): PwaInstallEnvironment {
  if (typeof window === "undefined") {
    return { isAndroid: false, isIos: false, isMobile: false, isStandalone: false };
  }

  const userAgent = window.navigator.userAgent;
  const platform = window.navigator.platform;
  const navigatorWithStandalone = window.navigator as Navigator & { standalone?: boolean; userAgentData?: { mobile?: boolean } };
  const isIos =
    /iPad|iPhone|iPod/.test(userAgent) ||
    (platform === "MacIntel" && window.navigator.maxTouchPoints > 1);
  const isAndroid = /Android/i.test(userAgent);
  const isMobile = Boolean(navigatorWithStandalone.userAgentData?.mobile) || isIos || isAndroid || window.innerWidth <= 768;
  const isStandalone =
    window.matchMedia("(display-mode: standalone)").matches ||
    window.matchMedia("(display-mode: fullscreen)").matches ||
    Boolean(navigatorWithStandalone.standalone);

  return { isAndroid, isIos, isMobile, isStandalone };
}

function usePwaInstallPrompt() {
  const [environment, setEnvironment] = useState<PwaInstallEnvironment>(() => getPwaInstallEnvironment());
  const [installPrompt, setInstallPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [installStatus, setInstallStatus] = useState<"idle" | "accepted" | "dismissed" | "installed">("idle");

  useEffect(() => {
    const refreshEnvironment = () => setEnvironment(getPwaInstallEnvironment());
    const handleBeforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as BeforeInstallPromptEvent);
      setInstallStatus("idle");
    };
    const handleInstalled = () => {
      setInstallPrompt(null);
      setInstallStatus("installed");
      setEnvironment(getPwaInstallEnvironment());
    };

    refreshEnvironment();
    window.addEventListener("resize", refreshEnvironment);
    window.addEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
    window.addEventListener("appinstalled", handleInstalled);

    return () => {
      window.removeEventListener("resize", refreshEnvironment);
      window.removeEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
      window.removeEventListener("appinstalled", handleInstalled);
    };
  }, []);

  const requestInstall = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    const choice = await installPrompt.userChoice;
    setInstallStatus(choice.outcome);
    setInstallPrompt(null);
  };

  return {
    canPrompt: Boolean(installPrompt) && !environment.isIos,
    environment,
    installStatus,
    requestInstall
  };
}

const stateOptions = [
  ["AL", "Alabama"],
  ["AK", "Alaska"],
  ["AZ", "Arizona"],
  ["AR", "Arkansas"],
  ["CA", "California"],
  ["CO", "Colorado"],
  ["CT", "Connecticut"],
  ["DE", "Delaware"],
  ["FL", "Florida"],
  ["GA", "Georgia"],
  ["HI", "Hawaii"],
  ["ID", "Idaho"],
  ["IL", "Illinois"],
  ["IN", "Indiana"],
  ["IA", "Iowa"],
  ["KS", "Kansas"],
  ["KY", "Kentucky"],
  ["LA", "Louisiana"],
  ["ME", "Maine"],
  ["MD", "Maryland"],
  ["MA", "Massachusetts"],
  ["MI", "Michigan"],
  ["MN", "Minnesota"],
  ["MS", "Mississippi"],
  ["MO", "Missouri"],
  ["MT", "Montana"],
  ["NE", "Nebraska"],
  ["NV", "Nevada"],
  ["NH", "New Hampshire"],
  ["NJ", "New Jersey"],
  ["NM", "New Mexico"],
  ["NY", "New York"],
  ["NC", "North Carolina"],
  ["ND", "North Dakota"],
  ["OH", "Ohio"],
  ["OK", "Oklahoma"],
  ["OR", "Oregon"],
  ["PA", "Pennsylvania"],
  ["RI", "Rhode Island"],
  ["SC", "South Carolina"],
  ["SD", "South Dakota"],
  ["TN", "Tennessee"],
  ["TX", "Texas"],
  ["UT", "Utah"],
  ["VT", "Vermont"],
  ["VA", "Virginia"],
  ["WA", "Washington"],
  ["WV", "West Virginia"],
  ["WI", "Wisconsin"],
  ["WY", "Wyoming"]
] as const;

function getInitialTab(): TabId {
  if (typeof window === "undefined") {
    return "home";
  }

  const tab = new URLSearchParams(window.location.search).get("tab");
  return tabIds.has(tab as TabId) ? (tab as TabId) : "home";
}

function shouldShowLanding(): boolean {
  if (typeof window === "undefined") return false;
  const params = new URLSearchParams(window.location.search);
  return window.location.pathname === "/landing" || params.get("landing") === "1";
}

const severityLabel: Record<StatusSeverity, string> = {
  green: "Estatus estable",
  yellow: "Requiere atencion",
  red: "Accion urgente"
};

const severityCopy: Record<StatusSeverity, string> = {
  green: "Sin riesgos criticos ahora.",
  yellow: "Hay fechas proximas que conviene revisar.",
  red: "Revisa y confirma tus acciones pendientes."
};

const statusOrder: StatusSeverity[] = ["green", "yellow", "red"];

function getWorstSeverity(alerts: CriticalAlert[]): StatusSeverity {
  if (alerts.some((alert) => alert.severity === "red")) return "red";
  if (alerts.some((alert) => alert.severity === "yellow")) return "yellow";
  return "green";
}

function formCodeForFlow(flow: AutomationFlow): string {
  if (flow.filingType === "ANNUAL_ASYLUM_FEE") return "ANNUAL_ASYLUM_FEE";
  if (flow.filingType === "AR11") return "AR-11";
  if (flow.filingType === "EOIR33") return "EOIR-33";
  if (flow.filingType === "I765_RENEWAL") return "I-765";
  return flow.filingType;
}

export function App() {
  if (shouldShowLanding()) {
    return (
      <Suspense fallback={<div className="landing-loading">Cargando MiCaso Prime...</div>}>
        <LandingPage />
      </Suspense>
    );
  }

  return <PrimeApp />;
}

function PrimeApp() {
  const appData = useAppData();
  const [activeTab, setActiveTab] = useState<TabId>(getInitialTab);
  const [guideOpen, setGuideOpen] = useState(() => {
    if (typeof window === "undefined") return false;
    return window.localStorage.getItem(GUIDE_STORAGE_KEY) !== "1";
  });

  const currentStatus = useMemo(() => getWorstSeverity(appData.dashboard.alerts), [appData.dashboard.alerts]);

  const handleTabChange = (tab: TabId) => {
    setActiveTab(tab);
    const url = new URL(window.location.href);
    if (tab === "home") {
      url.searchParams.delete("tab");
    } else {
      url.searchParams.set("tab", tab);
    }
    window.history.replaceState(null, "", url);
  };

  const closeGuide = () => {
    if (typeof window !== "undefined") {
      window.localStorage.setItem(GUIDE_STORAGE_KEY, "1");
    }
    setGuideOpen(false);
  };

  const renderScreen = () => {
    if (appData.mode === "auth_required") {
      return (
        <AuthScreen
          authBusy={appData.authBusy}
          authMessage={appData.authMessage}
          error={appData.error}
          onSignIn={appData.signInWithPassword}
        />
      );
    }

    if (appData.mode === "live" && appData.loading && !appData.profile) {
      return <LoadingScreen />;
    }

    if (appData.mode === "live" && appData.needsOnboarding) {
      return (
        <OnboardingScreen
          error={appData.error}
          loading={appData.workflowBusy}
          onComplete={appData.completeOnboarding}
          profile={appData.profile}
        />
      );
    }

    switch (activeTab) {
      case "documents":
        return (
          <DocumentVault
            documents={appData.documents}
            folders={appData.folders}
            loading={appData.loading}
            message={appData.packetMessage}
            onCacheDocumentOffline={appData.cacheDocumentOffline}
            onOpenDocument={appData.openDocument}
            onUploadDocument={appData.uploadDocument}
            workflowBusy={appData.workflowBusy}
          />
        );
      case "automation":
        return (
          <AutomationCenter
            activeWorkflow={appData.activeWorkflow}
            flows={appData.automations}
            generatedPacketUrl={appData.generatedPacketUrl}
            loading={appData.loading}
            onGeneratePacket={appData.generatePdfPacket}
            onSaveAnswer={appData.saveFormAnswer}
            onStart={appData.startFormSession}
            packetMessage={appData.packetMessage}
            workflowBusy={appData.workflowBusy}
          />
        );
      case "utilities":
        return (
          <UtilityHub
            dataMode={appData.mode}
            dmvExamConfig={appData.dmvExamConfig}
            dmvLearningModules={appData.dmvLearningModules}
            dmvQuestions={appData.dmvQuestions}
            onRecordDmvAttempt={appData.recordDmvAttempt}
            stateOfficialSource={appData.stateOfficialSource}
          />
        );
      case "more":
        return (
          <MorePanel
            message={appData.packetMessage}
            onRequestService={appData.requestPremiumService}
            services={appData.premiumServices}
            workflowBusy={appData.workflowBusy}
          />
        );
      default:
        return (
          <Dashboard
            alerts={appData.dashboard.alerts}
            cases={appData.cases}
            dataMode={appData.mode}
            error={appData.error}
            loading={appData.loading}
            message={appData.packetMessage}
            onAcknowledge={appData.acknowledgeAlert}
            onAddCase={appData.addCase}
            onAddCriticalDate={appData.addCriticalDate}
            onOpenTab={handleTabChange}
            onRefreshCaseStatus={appData.refreshCaseStatus}
            status={currentStatus}
            summary={appData.dashboard}
            workflowBusy={appData.workflowBusy}
            documentCount={appData.documents.length}
          />
        );
    }
  };

  return (
    <div className="app-frame">
      <div className="phone-shell">
        <AppHeader
          dataMode={appData.mode}
          email={appData.user?.email ?? null}
          onOpenGuide={() => setGuideOpen(true)}
          onSignOut={appData.signOut}
        />
        <div className="screen-content">{renderScreen()}</div>
        <BottomNav activeTab={activeTab} onChange={handleTabChange} />
        {guideOpen && appData.mode !== "auth_required" && !appData.needsOnboarding ? (
          <GuideModal activeTab={activeTab} onClose={closeGuide} onGoToTab={handleTabChange} />
        ) : null}
      </div>
      <aside className="desktop-brief" aria-label="Resumen operativo">
        <div className="brief-panel">
          <p className="brief-kicker">Fundacion productiva</p>
          <h2>Control migratorio, documentos y tramites conectado a Supabase.</h2>
          <p>
            Esta etapa ya usa Auth, RLS, storage privado y catalogo oficial versionado para escalar hacia
            automatizaciones, alertas push y revision humana de prueba.
          </p>
          <div className="brief-grid">
            <span>Supabase Auth</span>
            <span>RLS activo</span>
            <span>Storage privado</span>
            <span>Gratis por ahora</span>
          </div>
        </div>
      </aside>
    </div>
  );
}

function AppHeader({
  dataMode,
  email,
  onOpenGuide,
  onSignOut
}: {
  dataMode: DataMode;
  email: string | null;
  onOpenGuide: () => void;
  onSignOut: () => Promise<void>;
}) {
  return (
    <header className="app-header">
      <button className="icon-button" aria-label="Abrir guia" onClick={onOpenGuide} type="button">
        <Sparkles size={18} />
      </button>
      <div className="brand-lockup">
        <span className="brand-mark product-brand-mark">
          <img alt="" src={micasoPrimeLogo} />
        </span>
        <div>
          <strong>MiCaso</strong>
          <small>Prime</small>
        </div>
      </div>
      <button
        className={`icon-button ${dataMode === "live" ? "" : "alert-dot"}`}
        aria-label={email ? "Cerrar sesion" : "Notificaciones"}
        onClick={() => {
          if (email) void onSignOut();
        }}
      >
        {email ? <LogOut size={18} /> : <Bell size={18} />}
      </button>
    </header>
  );
}

function Dashboard({
  status,
  summary,
  alerts,
  cases,
  dataMode,
  loading,
  error,
  message,
  documentCount,
  onAcknowledge,
  onAddCase,
  onAddCriticalDate,
  onOpenTab,
  onRefreshCaseStatus,
  workflowBusy
}: {
  status: StatusSeverity;
  summary: DashboardSummary;
  alerts: CriticalAlert[];
  cases: CaseSummary[];
  dataMode: DataMode;
  loading: boolean;
  error: string | null;
  message: string | null;
  documentCount: number;
  onAcknowledge: (id: string) => void;
  onAddCase: (input: AddCaseInput) => Promise<void>;
  onAddCriticalDate: (input: AddCriticalDateInput) => Promise<void>;
  onOpenTab: (tab: TabId) => void;
  onRefreshCaseStatus: (caseId: string) => Promise<void>;
  workflowBusy: boolean;
}) {
  return (
    <main className="screen-stack">
      <DataModeBanner error={error} loading={loading} mode={dataMode} />
      {message ? <p className="form-success">{message}</p> : null}
      <PwaInstallCard />

      <section className={`status-panel status-${status}`} aria-label="Semaforo de estatus">
        <div className="traffic-light" aria-hidden="true">
          {statusOrder.map((item) => (
            <span key={item} className={item === status ? "active" : ""} />
          ))}
        </div>
        <div className="status-copy">
          <span>Semaforo de estatus</span>
          <h1>{severityLabel[status]}</h1>
          <p>{severityCopy[status]}</p>
          <button className="text-action">
            Ver detalles <ChevronRight size={16} />
          </button>
        </div>
      </section>

      <SetupChecklist alerts={alerts} cases={cases} documentCount={documentCount} onOpenTab={onOpenTab} />

      <DashboardActionPanel
        onAddCase={onAddCase}
        onAddCriticalDate={onAddCriticalDate}
        workflowBusy={workflowBusy}
      />

      <CaseStatusPanel cases={cases} onRefreshCaseStatus={onRefreshCaseStatus} workflowBusy={workflowBusy} />

      <section className="section-block">
        <div className="section-heading">
          <h2>Proximos eventos</h2>
          <button>Ordenar</button>
        </div>
        <div className="alert-list">
          {alerts.length === 0 ? (
            <div className="empty-state">
              <ShieldCheck size={22} />
              <strong>No hay alertas pendientes.</strong>
              <span>Tu panel queda en verde hasta el proximo cambio.</span>
            </div>
          ) : (
            alerts.map((alert) => (
              <article className={`alert-card alert-${alert.severity}`} key={alert.id}>
                <IconTile severity={alert.severity} kind={alert.kind} />
                <div>
                  <strong>{alert.title}</strong>
                  <p>{alert.detail}</p>
                </div>
                <button onClick={() => void onAcknowledge(alert.id)} aria-label={`Marcar ${alert.title}`}>
                  {alert.dueLabel}
                </button>
              </article>
            ))
          )}
        </div>
      </section>

      <section className="section-block">
        <h2>Resumen rapido</h2>
        <div className="metric-grid">
          <Metric value={summary.totals.documentsExpiring} label="Docs por vencer" />
          <Metric value={summary.totals.pendingTasks} label="Tareas pendientes" />
          <Metric value={summary.totals.activeCases} label="Casos activos" />
          <Metric value={summary.totals.newMessages} label="Mensajes nuevos" />
        </div>
      </section>

      <div className="security-note">
        <Lock size={16} />
        <span>Tus datos estan cifrados y protegidos.</span>
      </div>

      <p className="legal-note">MiCaso Prime no es un bufete de abogados y no brinda asesoria legal.</p>
    </main>
  );
}

function SetupChecklist({
  alerts,
  cases,
  documentCount,
  onOpenTab
}: {
  alerts: CriticalAlert[];
  cases: CaseSummary[];
  documentCount: number;
  onOpenTab: (tab: TabId) => void;
}) {
  const steps: Array<{ done: boolean; label: string; detail: string; tab: TabId; icon: typeof Home }> = [
    {
      detail: "Tu panel ya esta creado y listo para organizar informacion.",
      done: true,
      icon: ShieldCheck,
      label: "Perfil base",
      tab: "home"
    },
    {
      detail: "Agrega un recibo USCIS o una fecha importante.",
      done: cases.length > 0 || alerts.length > 0,
      icon: CalendarDays,
      label: "Caso o fecha critica",
      tab: "home"
    },
    {
      detail: "Sube I-94, recibos, permisos o notificaciones.",
      done: documentCount > 0,
      icon: Folder,
      label: "Primer documento",
      tab: "documents"
    },
    {
      detail: "Explora AR-11, I-765, cambio de sede o anualidades.",
      done: false,
      icon: FileCheck2,
      label: "Formulario guiado",
      tab: "automation"
    }
  ];
  const completed = steps.filter((step) => step.done).length;
  const nextStep = steps.find((step) => !step.done) ?? steps[steps.length - 1]!;
  const progress = Math.round((completed / steps.length) * 100);

  return (
    <section className="setup-card" aria-label="Configuracion guiada">
      <div className="setup-heading">
        <div>
          <span>Modo guia</span>
          <h2>Configura tu cuenta paso a paso</h2>
        </div>
        <strong>{progress}%</strong>
      </div>
      <div className="setup-progress" aria-hidden="true">
        <i style={{ width: `${progress}%` }} />
      </div>
      <div className="setup-list">
        {steps.map((step) => {
          const Icon = step.icon;
          return (
            <button
              className={`setup-step ${step.done ? "done" : ""}`}
              key={step.label}
              onClick={() => onOpenTab(step.tab)}
              type="button"
            >
              <span className="setup-step-icon">{step.done ? <CheckSquare size={17} /> : <Icon size={17} />}</span>
              <span>
                <strong>{step.label}</strong>
                <small>{step.detail}</small>
              </span>
            </button>
          );
        })}
      </div>
      <button className="setup-cta" onClick={() => onOpenTab(nextStep.tab)} type="button">
        Continuar: {nextStep.label}
        <ChevronRight size={16} />
      </button>
    </section>
  );
}

function GuideModal({
  activeTab,
  onClose,
  onGoToTab
}: {
  activeTab: TabId;
  onClose: () => void;
  onGoToTab: (tab: TabId) => void;
}) {
  const initialStep = Math.max(
    0,
    guideSteps.findIndex((step) => step.tab === activeTab)
  );
  const [stepIndex, setStepIndex] = useState(initialStep);
  const step = guideSteps[stepIndex] ?? guideSteps[0]!;
  const Icon = step.icon;
  const progress = Math.round(((stepIndex + 1) / guideSteps.length) * 100);
  const isLastStep = stepIndex === guideSteps.length - 1;

  const goToStepTab = () => {
    onGoToTab(step.tab);
    onClose();
  };

  return (
    <div className="guide-overlay" role="dialog" aria-modal="true" aria-labelledby="guide-title">
      <section className="guide-modal">
        <div className="guide-topline">
          <span>{step.kicker}</span>
          <button onClick={onClose} type="button">Omitir guia</button>
        </div>
        <div className="guide-progress" aria-hidden="true">
          <i style={{ width: `${progress}%` }} />
        </div>
        <div className="guide-hero">
          <div className="guide-icon">
            <Icon size={28} />
          </div>
          <div>
            <h2 id="guide-title">{step.title}</h2>
            <p>{step.body}</p>
          </div>
        </div>
        <ul className="guide-tips">
          {step.tips.map((tip) => (
            <li key={tip}>
              <CheckSquare size={15} />
              <span>{tip}</span>
            </li>
          ))}
        </ul>
        <div className="guide-dots" aria-label="Progreso de guia">
          {guideSteps.map((item, index) => (
            <button
              aria-label={`Abrir ${item.title}`}
              className={index === stepIndex ? "active" : ""}
              key={item.title}
              onClick={() => setStepIndex(index)}
              type="button"
            />
          ))}
        </div>
        <div className="guide-actions">
          <button className="secondary-button guide-secondary" onClick={goToStepTab} type="button">
            {step.action}
          </button>
          <button
            className="primary-button guide-primary"
            onClick={() => {
              if (isLastStep) {
                onClose();
                return;
              }
              setStepIndex((current) => current + 1);
            }}
            type="button"
          >
            {isLastStep ? "Terminar guia" : "Siguiente paso"}
            <ChevronRight size={16} />
          </button>
        </div>
      </section>
    </div>
  );
}

function maskReceipt(value: string | null): string {
  if (!value) return "Sin recibo";
  if (value.length <= 6) return value;
  return `${value.slice(0, 3)}...${value.slice(-4)}`;
}

function CaseStatusPanel({
  cases,
  onRefreshCaseStatus,
  workflowBusy
}: {
  cases: CaseSummary[];
  onRefreshCaseStatus: (caseId: string) => Promise<void>;
  workflowBusy: boolean;
}) {
  return (
    <section className="section-block">
      <div className="section-heading">
        <h2>Casos rastreados</h2>
        <span className="mini-status">USCIS</span>
      </div>
      <div className="case-list">
        {cases.length === 0 ? (
          <div className="empty-state compact-empty">
            <Landmark size={22} />
            <strong>No hay casos guardados.</strong>
            <span>Agrega un numero de recibo para iniciar seguimiento.</span>
          </div>
        ) : (
          cases.map((item) => (
            <article className="case-row" key={item.id}>
              <div className="case-icon">
                <Landmark size={20} />
              </div>
              <div>
                <strong>{item.formCode || item.agency}</strong>
                <span>
                  {maskReceipt(item.receiptNumber)} . {item.status.replaceAll("_", " ")}
                </span>
                <small>
                  {item.lastCheckedAt
                    ? `Consultado ${new Date(item.lastCheckedAt).toLocaleDateString("es-US")}`
                    : "Pendiente de consulta oficial"}
                </small>
              </div>
              <button className="mini-action" disabled={workflowBusy} onClick={() => void onRefreshCaseStatus(item.id)}>
                Refrescar
              </button>
            </article>
          ))
        )}
      </div>
    </section>
  );
}

function LoadingScreen() {
  return (
    <main className="screen-stack auth-screen">
      <section className="auth-panel">
        <div className="auth-hero">
          <div className="auth-icon">
            <Loader2 className="spin" size={34} />
          </div>
          <div>
            <span>Sesion protegida</span>
            <h1>Cargando tu panel</h1>
            <p>Estamos preparando tus documentos, alertas y servicios conectados a Supabase.</p>
          </div>
        </div>
      </section>
    </main>
  );
}

function OnboardingScreen({
  error,
  loading,
  onComplete,
  profile
}: {
  error: string | null;
  loading: boolean;
  onComplete: (input: CompleteOnboardingInput) => Promise<void>;
  profile: UserProfile | null;
}) {
  const [fullName, setFullName] = useState(profile?.full_name ?? "");
  const [stateCode, setStateCode] = useState(profile?.state_code ?? "UT");
  const [accepted, setAccepted] = useState(false);

  return (
    <main className="screen-stack auth-screen">
      <section className="onboarding-panel">
        <div className="auth-hero">
          <div className="auth-icon">
            <ShieldCheck size={34} />
          </div>
          <div>
            <span>Primer acceso</span>
            <h1>Configura tu cuenta</h1>
            <p>Esto activa la boveda privada, alertas y formularios con tu estado base.</p>
          </div>
        </div>

        <form
          className="field-grid"
          onSubmit={(event) => {
            event.preventDefault();
            void onComplete({ fullName, stateCode });
          }}
        >
          <label htmlFor="onboarding-name">
            Nombre completo
            <input
              autoComplete="name"
              id="onboarding-name"
              onChange={(event) => setFullName(event.target.value)}
              required
              type="text"
              value={fullName}
            />
          </label>

          <label htmlFor="onboarding-state">
            Estado principal
            <select id="onboarding-state" onChange={(event) => setStateCode(event.target.value)} value={stateCode}>
              {stateOptions.map(([code, name]) => (
                <option key={code} value={code}>
                  {name}
                </option>
              ))}
            </select>
          </label>

          <label className="consent-row" htmlFor="legal-consent">
            <input
              checked={accepted}
              id="legal-consent"
              onChange={(event) => setAccepted(event.target.checked)}
              required
              type="checkbox"
            />
            <span>
              Entiendo que esta app organiza documentos y formularios, pero no reemplaza asesoria legal.
            </span>
          </label>

          <button className="primary-button" disabled={loading || !accepted} type="submit">
            {loading ? <Loader2 className="spin" size={16} /> : <ShieldCheck size={16} />}
            Activar mi panel
          </button>
        </form>

        {error ? <p className="form-error">{error}</p> : null}
      </section>
    </main>
  );
}

function DashboardActionPanel({
  onAddCase,
  onAddCriticalDate,
  workflowBusy
}: {
  onAddCase: (input: AddCaseInput) => Promise<void>;
  onAddCriticalDate: (input: AddCriticalDateInput) => Promise<void>;
  workflowBusy: boolean;
}) {
  const [mode, setMode] = useState<"date" | "case">("date");

  return (
    <section className="action-panel">
      <div className="action-segment" aria-label="Acciones rapidas">
        <button className={mode === "date" ? "active" : ""} onClick={() => setMode("date")} type="button">
          <CalendarDays size={15} />
          Fecha
        </button>
        <button className={mode === "case" ? "active" : ""} onClick={() => setMode("case")} type="button">
          <Landmark size={15} />
          Caso USCIS
        </button>
      </div>
      {mode === "date" ? (
        <CriticalDateForm onSubmit={onAddCriticalDate} saving={workflowBusy} />
      ) : (
        <CaseForm onSubmit={onAddCase} saving={workflowBusy} />
      )}
    </section>
  );
}

function CriticalDateForm({
  onSubmit,
  saving
}: {
  onSubmit: (input: AddCriticalDateInput) => Promise<void>;
  saving: boolean;
}) {
  const [title, setTitle] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [kind, setKind] = useState<AlertKind>("filing_deadline");
  const [source, setSource] = useState<Agency>("USCIS");
  const [severity, setSeverity] = useState<StatusSeverity>("yellow");
  const [details, setDetails] = useState("");

  return (
    <form
      className="field-grid compact"
      onSubmit={(event) => {
        event.preventDefault();
        void onSubmit({ details, dueDate, kind, severity, source, title }).then(() => {
          setTitle("");
          setDueDate("");
          setDetails("");
        });
      }}
    >
      <label htmlFor="date-title">
        Titulo
        <input
          id="date-title"
          onChange={(event) => setTitle(event.target.value)}
          placeholder="Audiencia, biometria, vencimiento..."
          required
          type="text"
          value={title}
        />
      </label>
      <label htmlFor="date-due">
        Fecha
        <input
          id="date-due"
          inputMode="numeric"
          maxLength={10}
          onChange={(event) => setDueDate(event.target.value)}
          pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}"
          placeholder="AAAA-MM-DD"
          required
          title="Usa el formato AAAA-MM-DD"
          type="text"
          value={dueDate}
        />
      </label>
      <label htmlFor="date-kind">
        Tipo
        <select id="date-kind" onChange={(event) => setKind(event.target.value as AlertKind)} value={kind}>
          <option value="court_hearing">Audiencia</option>
          <option value="ead_expiration">Vence permiso</option>
          <option value="biometrics">Biometria</option>
          <option value="filing_deadline">Fecha limite</option>
          <option value="address_change">Cambio direccion</option>
        </select>
      </label>
      <label htmlFor="date-severity">
        Urgencia
        <select id="date-severity" onChange={(event) => setSeverity(event.target.value as StatusSeverity)} value={severity}>
          <option value="green">Verde</option>
          <option value="yellow">Amarillo</option>
          <option value="red">Rojo</option>
        </select>
      </label>
      <label htmlFor="date-source">
        Agencia
        <select id="date-source" onChange={(event) => setSource(event.target.value as Agency)} value={source}>
          <option value="USCIS">USCIS</option>
          <option value="EOIR">EOIR</option>
          <option value="CBP">CBP</option>
          <option value="DMV">DMV</option>
          <option value="OTHER">Otra</option>
        </select>
      </label>
      <label className="wide-field" htmlFor="date-details">
        Detalle
        <textarea
          id="date-details"
          onChange={(event) => setDetails(event.target.value)}
          placeholder="Notas utiles para recordar la accion"
          rows={2}
          value={details}
        />
      </label>
      <button className="primary-button wide-field" disabled={saving} type="submit">
        {saving ? <Loader2 className="spin" size={16} /> : <Plus size={16} />}
        Agregar fecha
      </button>
    </form>
  );
}

function CaseForm({ onSubmit, saving }: { onSubmit: (input: AddCaseInput) => Promise<void>; saving: boolean }) {
  const [receiptNumber, setReceiptNumber] = useState("");
  const [formCode, setFormCode] = useState("");

  return (
    <form
      className="field-grid compact"
      onSubmit={(event) => {
        event.preventDefault();
        void onSubmit({ agency: "USCIS", formCode, receiptNumber }).then(() => {
          setReceiptNumber("");
          setFormCode("");
        });
      }}
    >
      <label className="wide-field" htmlFor="case-receipt">
        Numero de recibo USCIS
        <input
          id="case-receipt"
          onChange={(event) => setReceiptNumber(event.target.value)}
          placeholder="IOE1234567890"
          required
          type="text"
          value={receiptNumber}
        />
      </label>
      <label className="wide-field" htmlFor="case-form">
        Formulario opcional
        <input
          id="case-form"
          onChange={(event) => setFormCode(event.target.value)}
          placeholder="I-765, I-130, I-485..."
          type="text"
          value={formCode}
        />
      </label>
      <button className="primary-button wide-field" disabled={saving} type="submit">
        {saving ? <Loader2 className="spin" size={16} /> : <Plus size={16} />}
        Guardar caso
      </button>
    </form>
  );
}

function AuthScreen({
  authBusy,
  authMessage,
  error,
  onSignIn
}: {
  authBusy: boolean;
  authMessage: string | null;
  error: string | null;
  onSignIn: (email: string, password: string, fullName?: string, intent?: "signin" | "signup") => Promise<void>;
}) {
  const [email, setEmail] = useState("");
  const [fullName, setFullName] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [localError, setLocalError] = useState<string | null>(null);
  const [authMode, setAuthMode] = useState<"signin" | "signup">("signup");

  return (
    <main className="screen-stack auth-screen">
      <section className="auth-panel">
        <div className="auth-hero">
          <div className="auth-icon">
            <ShieldCheck size={34} />
          </div>
          <div>
            <span>Centro de Control Migratorio</span>
            <h1>{authMode === "signup" ? "Crea tu cuenta segura" : "Entra a tu cuenta"}</h1>
            <p>Usa tu correo y contrasena. Sin enlaces de confirmacion.</p>
          </div>
        </div>

        <div className="auth-segment" role="tablist" aria-label="Modo de acceso">
          <button className={authMode === "signup" ? "active" : ""} onClick={() => setAuthMode("signup")} type="button">
            Crear cuenta
          </button>
          <button className={authMode === "signin" ? "active" : ""} onClick={() => setAuthMode("signin")} type="button">
            Ya tengo cuenta
          </button>
        </div>

        <div className="auth-benefits" aria-label="Beneficios de cuenta">
          <span>
            <Lock size={14} />
            Boveda privada
          </span>
          <span>
            <Bell size={14} />
            Alertas criticas
          </span>
          <span>
            <FileCheck2 size={14} />
            PDFs oficiales
          </span>
        </div>

        <PwaInstallCard variant="auth" />

        <form
          onSubmit={(event) => {
            event.preventDefault();
            setLocalError(null);
            if (password.length < 8) {
              setLocalError("La contrasena debe tener al menos 8 caracteres.");
              return;
            }
            if (authMode === "signup" && password !== confirmPassword) {
              setLocalError("Las contrasenas no coinciden.");
              return;
            }
            void onSignIn(email, password, fullName, authMode);
          }}
        >
          {authMode === "signup" ? (
            <>
              <label htmlFor="full-name">Nombre completo</label>
              <input
                autoComplete="name"
                id="full-name"
                onChange={(event) => setFullName(event.target.value)}
                placeholder="Tu nombre legal"
                required
                type="text"
                value={fullName}
              />
            </>
          ) : null}
          <label htmlFor="email">Correo electronico</label>
          <input
            autoComplete="email"
            id="email"
            inputMode="email"
            onChange={(event) => setEmail(event.target.value)}
            placeholder="tu@email.com"
            required
            type="email"
            value={email}
          />
          <label htmlFor="password">Contrasena</label>
          <input
            autoComplete={authMode === "signup" ? "new-password" : "current-password"}
            id="password"
            minLength={8}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="Minimo 8 caracteres"
            required
            type="password"
            value={password}
          />
          {authMode === "signup" ? (
            <>
              <label htmlFor="confirm-password">Confirmar contrasena</label>
              <input
                autoComplete="new-password"
                id="confirm-password"
                minLength={8}
                onChange={(event) => setConfirmPassword(event.target.value)}
                placeholder="Repite tu contrasena"
                required
                type="password"
                value={confirmPassword}
              />
            </>
          ) : null}
          <button className="primary-button" disabled={authBusy} type="submit">
            {authBusy ? <Loader2 className="spin" size={16} /> : <LogIn size={16} />}
            {authMode === "signup" ? "Crear acceso seguro" : "Entrar"}
          </button>
        </form>
        {authMessage ? <p className="form-success">{authMessage}</p> : null}
        {localError || error ? <p className="form-error">{localError ?? error}</p> : null}
      </section>
    </main>
  );
}

function DataModeBanner({ mode, loading, error }: { mode: DataMode; loading: boolean; error: string | null }) {
  if (error) {
    return (
      <div className="data-banner error">
        <Database size={16} />
        <span>{error}</span>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="data-banner">
        <Loader2 className="spin" size={16} />
        <span>Cargando datos protegidos...</span>
      </div>
    );
  }

  return (
    <div className={`data-banner ${mode}`}>
      <Cloud size={16} />
      <span>{mode === "live" ? "Conectado a Supabase" : "Vista local de previsualizacion"}</span>
    </div>
  );
}

function PwaInstallCard({ variant = "default" }: { variant?: "auth" | "default" }) {
  const { canPrompt, environment, installStatus, requestInstall } = usePwaInstallPrompt();
  const [showSteps, setShowSteps] = useState(false);

  useEffect(() => {
    if (canPrompt && !environment.isIos) {
      setShowSteps(false);
      return;
    }
    if (environment.isIos || (!canPrompt && !environment.isAndroid)) {
      setShowSteps(true);
    }
  }, [canPrompt, environment.isAndroid, environment.isIos]);

  if (environment.isStandalone || (!environment.isMobile && !canPrompt)) {
    return null;
  }

  const platformLabel = environment.isIos ? "iPhone" : environment.isAndroid ? "Android" : "este dispositivo";
  const shouldShowSteps = showSteps;
  const steps = environment.isIos
    ? [
        "Abre esta pagina en Safari si no ves la opcion.",
        "Toca el boton Compartir.",
        "Elige Agregar a pantalla de inicio y confirma MiCaso Prime."
      ]
    : [
        "Toca el menu del navegador.",
        "Elige Instalar app o Agregar a pantalla principal.",
        "Confirma MiCaso Prime para abrirlo como aplicacion."
      ];

  return (
    <section className={`pwa-install-card ${variant}`} aria-label="Instalar MiCaso Prime">
      <div className="pwa-install-top">
        <span className="pwa-install-icon">
          {environment.isIos ? <Share2 size={20} /> : <Download size={20} />}
        </span>
        <div>
          <strong>Instala MiCaso Prime en {platformLabel}</strong>
          <p>Abre la app desde tu pantalla principal, con menos distracciones y acceso rapido.</p>
        </div>
      </div>
      {shouldShowSteps ? (
        <ol className="pwa-install-steps">
          {steps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      ) : null}
      <div className="pwa-install-actions">
        {canPrompt ? (
          <button className="primary-button pwa-install-primary" onClick={() => void requestInstall()} type="button">
            <Download size={16} />
            Instalar ahora
          </button>
        ) : (
          <button className="primary-button pwa-install-primary" onClick={() => setShowSteps((current) => !current)} type="button">
            <Smartphone size={16} />
            {shouldShowSteps ? "Ocultar pasos" : "Ver pasos"}
          </button>
        )}
        {installStatus === "dismissed" ? <span>Tambien puedes instalarlo desde el menu del navegador.</span> : null}
        {installStatus === "accepted" ? <span>Instalacion aceptada. Revisa tu pantalla principal.</span> : null}
        {installStatus === "installed" ? <span>App instalada correctamente.</span> : null}
      </div>
    </section>
  );
}

function DocumentVault({
  documents,
  folders,
  loading,
  message,
  onCacheDocumentOffline,
  onOpenDocument,
  onUploadDocument,
  workflowBusy
}: {
  documents: VaultDocument[];
  folders: SmartFolder[];
  loading: boolean;
  message: string | null;
  onCacheDocumentOffline: (documentId: string) => Promise<void>;
  onOpenDocument: (documentId: string) => Promise<string | null>;
  onUploadDocument: (input: UploadDocumentInput) => Promise<void>;
  workflowBusy: boolean;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState("");
  const [ocrText, setOcrText] = useState("");

  return (
    <main className="screen-stack light-screen">
      <TopBar guide={documentVaultHelp} title="Mis documentos" />
      <section className="vault-banner">
        <ShieldCheck size={30} />
        <div>
          <strong>Boveda segura</strong>
          <span>Tus documentos cifrados y disponibles.</span>
        </div>
        <Lock size={18} />
      </section>

      <section className="upload-panel">
        <div className="section-heading">
          <h2>Agregar documento</h2>
          <span className="mini-status">Storage privado</span>
        </div>
        <form
          className="field-grid compact"
          onSubmit={(event) => {
            event.preventDefault();
            if (!file) return;
            void onUploadDocument({ file, ocrText, title }).then(() => {
              setFile(null);
              setTitle("");
              setOcrText("");
              event.currentTarget.reset();
            });
          }}
        >
          <label className="wide-field" htmlFor="document-title">
            Nombre para la boveda
            <input
              id="document-title"
              onChange={(event) => setTitle(event.target.value)}
              placeholder="Ej. Recibo I-765"
              type="text"
              value={title}
            />
          </label>
          <label className="wide-field file-drop" htmlFor="document-file">
            <FileText size={20} />
            <span>{file ? file.name : "Seleccionar PDF o imagen"}</span>
            <input
              accept="application/pdf,image/*"
              id="document-file"
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
              required
              type="file"
            />
          </label>
          <label className="wide-field" htmlFor="document-ocr">
            Texto detectado opcional
            <textarea
              id="document-ocr"
              onChange={(event) => setOcrText(event.target.value)}
              placeholder="Pega texto si lo tienes. Ayuda a clasificar I-94, I-797, I-765 o corte."
              rows={2}
              value={ocrText}
            />
          </label>
          <button className="primary-button wide-field" disabled={workflowBusy || !file} type="submit">
            {workflowBusy ? <Loader2 className="spin" size={16} /> : <Cloud size={16} />}
            Subir y clasificar
          </button>
        </form>
        {message ? <p className="form-success">{message}</p> : null}
      </section>

      <section className="section-block">
        <div className="section-heading">
          <h2>Carpetas inteligentes</h2>
          <button>Ver todas</button>
        </div>
        <div className="folder-list">
          {folders.map((folder) => (
            <button className="folder-row" key={folder.id}>
              <Folder fill={folder.color} color={folder.color} size={30} />
              <span>
                <strong>{folder.label}</strong>
                <small>{folder.count} documentos</small>
              </span>
              <ChevronRight size={18} />
            </button>
          ))}
        </div>
      </section>

      <section className="section-block">
        <div className="section-heading">
          <h2>Documentos recientes</h2>
          <button>Ver todos</button>
        </div>
        <div className="document-list">
          {loading ? (
            <div className="empty-state">
              <Loader2 className="spin" size={22} />
              <strong>Cargando documentos.</strong>
              <span>Validando tu sesion segura.</span>
            </div>
          ) : documents.length === 0 ? (
            <div className="empty-state">
              <FileText size={22} />
              <strong>No hay documentos cargados.</strong>
              <span>Escanea tu primer documento desde la boveda.</span>
            </div>
          ) : (
            documents.map((doc) => (
              <article className="document-row" key={doc.id}>
                <FileText size={28} />
                <div>
                  <strong>{doc.title}</strong>
                  <span>
                    {doc.agency} . {new Date(doc.capturedAt).toLocaleDateString("es-US")}
                  </span>
                </div>
                <small className={`status-chip ${doc.status}`}>{doc.agency}</small>
                <div className="document-actions">
                  <button
                    className="mini-action"
                    disabled={workflowBusy}
                    onClick={() => {
                      void onOpenDocument(doc.id).then((url) => {
                        if (url) window.open(url, "_blank", "noopener,noreferrer");
                      });
                    }}
                  >
                    Abrir
                  </button>
                  <button
                    className="mini-action"
                    disabled={workflowBusy}
                    onClick={() => void onCacheDocumentOffline(doc.id)}
                  >
                    Offline
                  </button>
                </div>
              </article>
            ))
          )}
        </div>
      </section>
    </main>
  );
}

function AutomationCenter({
  activeWorkflow,
  flows,
  generatedPacketUrl,
  loading,
  onGeneratePacket,
  onSaveAnswer,
  onStart,
  packetMessage,
  workflowBusy
}: {
  activeWorkflow: ActiveWorkflow | null;
  flows: AutomationFlow[];
  generatedPacketUrl: string | null;
  loading: boolean;
  onGeneratePacket: (sessionId: string) => Promise<void>;
  onSaveAnswer: (sessionId: string, questionKey: string, answer: unknown) => Promise<void>;
  onStart: (formCode: string) => Promise<void>;
  packetMessage: string | null;
  workflowBusy: boolean;
}) {
  return (
    <main className="screen-stack light-screen">
      <TopBar guide={automationHelp} title="Automatizaciones" />
      <p className="screen-subtitle">Prepara, revisa y exporta tus formularios.</p>
      <section className="annuality-brief" aria-label="Pago de anualidades">
        <CreditCard size={24} />
        <div>
          <strong>Pago de anualidades USCIS</strong>
          <span>
            Prepara la Tarifa Anual de Asilo con A-Number, recibo I-589, fecha limite y comprobante interno.
          </span>
        </div>
      </section>
      {activeWorkflow ? (
        <FormWorkflowPanel
          activeWorkflow={activeWorkflow}
          generatedPacketUrl={generatedPacketUrl}
          onGeneratePacket={onGeneratePacket}
          onSaveAnswer={onSaveAnswer}
          packetMessage={packetMessage}
          saving={workflowBusy}
        />
      ) : null}
      <div className="stepper" aria-label="Progreso de formulario">
        {["Preparar", "Revisar", "Firmar", "Exportar"].map((step, index) => (
          <span className={index === 0 ? "active" : ""} key={step}>
            <b>{index + 1}</b>
            {step}
          </span>
        ))}
      </div>

      <section className="section-block">
        <h2>Flujos disponibles</h2>
        <div className="automation-list">
          {loading ? (
            <div className="empty-state">
              <Loader2 className="spin" size={22} />
              <strong>Cargando formularios.</strong>
              <span>Consultando el catalogo oficial.</span>
            </div>
          ) : (
            flows.map((flow) => (
              <AutomationCard
                disabled={workflowBusy}
                flow={flow}
                key={flow.id}
                onStart={() => onStart(formCodeForFlow(flow))}
              />
            ))
          )}
        </div>
      </section>

      <div className="info-callout">
        <ShieldCheck size={24} />
        <div>
          <strong>Automatiza sin perder control.</strong>
          <span>Los casos complejos pasan por revision humana antes de generar el paquete final.</span>
        </div>
      </div>
    </main>
  );
}

function FormWorkflowPanel({
  activeWorkflow,
  generatedPacketUrl,
  onGeneratePacket,
  onSaveAnswer,
  packetMessage,
  saving
}: {
  activeWorkflow: ActiveWorkflow;
  generatedPacketUrl: string | null;
  onGeneratePacket: (sessionId: string) => Promise<void>;
  onSaveAnswer: (sessionId: string, questionKey: string, answer: unknown) => Promise<void>;
  packetMessage: string | null;
  saving: boolean;
}) {
  const [answers, setAnswers] = useState<Record<string, string | boolean>>({});

  const saveAnswers = async () => {
    const entries = Object.entries(answers);
    for (const [questionKey, answer] of entries) {
      await onSaveAnswer(activeWorkflow.sessionId, questionKey, answer);
    }
  };

  return (
    <section className="workflow-panel">
      <div className="workflow-panel-heading">
        <div>
          <strong>Sesion {activeWorkflow.formCode}</strong>
          <span>Estado: {activeWorkflow.status.replaceAll("_", " ")}</span>
        </div>
        <span>{activeWorkflow.questions.length} campos</span>
      </div>
      {activeWorkflow.formCode === "ANNUAL_ASYLUM_FEE" ? <AnnualAsylumFeeGuidance /> : null}
      <div className="workflow-fields">
        {activeWorkflow.questions.map((question) => {
          const id = `${activeWorkflow.sessionId}-${question.question_key}`;
          const isBoolean = question.data_type === "boolean";
          const isSelect = question.data_type === "select";
          const placeholder =
            question.data_type === "date"
              ? "AAAA-MM-DD"
              : question.help_text_es ?? "";

          return (
            <label className={isBoolean ? "workflow-check" : "workflow-field"} htmlFor={id} key={question.question_key}>
              <span>
                {question.label_es}
                {question.required ? " *" : ""}
              </span>
              {isBoolean ? (
                <input
                  checked={Boolean(answers[question.question_key])}
                  id={id}
                  onChange={(event) => {
                    const value = event.target.checked;
                    setAnswers((current) => ({ ...current, [question.question_key]: value }));
                  }}
                  type="checkbox"
                />
              ) : isSelect ? (
                <select
                  id={id}
                  onChange={(event) => {
                    setAnswers((current) => ({ ...current, [question.question_key]: event.target.value }));
                  }}
                  value={String(answers[question.question_key] ?? "")}
                >
                  <option value="">Seleccionar</option>
                  {(question.validation_rule.options ?? []).map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label_es}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  id={id}
                  inputMode={question.data_type === "date" ? "numeric" : undefined}
                  maxLength={question.data_type === "date" ? 10 : undefined}
                  onChange={(event) => {
                    setAnswers((current) => ({ ...current, [question.question_key]: event.target.value }));
                  }}
                  pattern={question.data_type === "date" ? "[0-9]{4}-[0-9]{2}-[0-9]{2}" : undefined}
                  placeholder={placeholder}
                  title={question.data_type === "date" ? "Usa el formato AAAA-MM-DD" : undefined}
                  type="text"
                  value={String(answers[question.question_key] ?? "")}
                />
              )}
            </label>
          );
        })}
      </div>
      <div className="workflow-actions">
        <button
          className="primary-button"
          disabled={saving}
          onClick={() => {
            void saveAnswers();
          }}
        >
          {saving ? <Loader2 className="spin" size={16} /> : <FileCheck2 size={16} />}
          Guardar respuestas
        </button>
        <button
          className="secondary-action"
          disabled={saving}
          onClick={() => {
            void saveAnswers().then(() => onGeneratePacket(activeWorkflow.sessionId));
          }}
        >
          Generar paquete PDF
        </button>
      </div>
      {packetMessage ? <p className="form-success">{packetMessage}</p> : null}
      {generatedPacketUrl ? (
        <a className="packet-link" href={generatedPacketUrl} rel="noreferrer" target="_blank">
          Abrir PDF generado
        </a>
      ) : null}
      <p className="legal-note">
        La app prepara el paquete; el usuario debe revisar y presentar o pagar por el canal oficial.
      </p>
    </section>
  );
}

function AnnualAsylumFeeGuidance() {
  return (
    <div className="official-guidance">
      <CreditCard size={18} />
      <div>
        <strong>Pago real solo en USCIS</strong>
        <span>
          Este flujo organiza la informacion y el comprobante. El pago se completa en el portal oficial con A-Number y
          numero de recibo.
        </span>
        <a href="https://my.uscis.gov/accounts/annual-asylum-fee/start/overview" rel="noreferrer" target="_blank">
          Abrir portal oficial <ChevronRight size={15} />
        </a>
      </div>
    </div>
  );
}

function AutomationCard({ disabled, flow, onStart }: { disabled: boolean; flow: AutomationFlow; onStart: () => void }) {
  const icon =
    flow.filingType === "ANNUAL_ASYLUM_FEE"
      ? CreditCard
      : flow.filingType === "CHANGE_OF_VENUE"
        ? Landmark
        : flow.filingType === "I765_RENEWAL"
          ? FileCheck2
          : MapPin;
  const Icon = icon;

  return (
    <article className="automation-card">
      <div className={`automation-icon ${flow.filingType.toLowerCase()}`}>
        <Icon size={24} />
      </div>
      <div>
        <strong>{flow.title}</strong>
        <p>{flow.description}</p>
        <div className="progress-track">
          <span style={{ width: `${flow.progress}%` }} />
        </div>
      </div>
      <span className="flow-chip">{flow.status.replaceAll("_", " ")}</span>
      <button className="mini-action" disabled={disabled} onClick={onStart}>
        {flow.status === "not_started" ? "Comenzar" : "Abrir"}
      </button>
      <ChevronRight size={18} />
    </article>
  );
}

const UTAH_DLD_WRITTEN_TEST_URL = "https://dld.utah.gov/written-knowledge-test/";
const UTAH_DLD_PRACTICE_TEST_URL = "https://dld.utah.gov/practice-test/";
const UTAH_DLD_HANDBOOK_ES_URL = "https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf";

type DmvStudyGuide = {
  answerStrategy: string;
  commonMistake: string;
  keyPoints: string[];
  objective: string;
  sourceLabel: string;
  sourceUrl: string;
};

const utahStudyGuides: Record<string, DmvStudyGuide> = {
  "alcohol-drugs": {
    answerStrategy:
      "Cuando una opcion minimiza el efecto de alcohol, drogas o medicinas, descartala. La respuesta segura siempre evita manejar afectado.",
    commonMistake: "Creer que solo el alcohol ilegal cuenta. El manual tambien incluye drogas ilegales, medicamentos recetados y de venta libre.",
    keyPoints: [
      "El alcohol y las drogas reducen juicio, vision, reflejos, estado de alerta y tiempo de reaccion.",
      "El deterioro comienza con el primer trago; Utah recomienda no conducir si consumiste alcohol u otras drogas.",
      "Utah aplica limite legal de 0.05 BAC para conductores no comerciales, y tambien sanciona si no es seguro operar el vehiculo.",
      "Para menores de 21 anos, las reglas oficiales son mas estrictas y pueden negar privilegios de conducir."
    ],
    objective: "Identificar respuestas donde el conductor elimina el riesgo antes de manejar.",
    sourceLabel: "Manual del Conductor de Utah, Alcohol/Drogas y Conduccion",
    sourceUrl: UTAH_DLD_HANDBOOK_ES_URL
  },
  "night-driving": {
    answerStrategy:
      "Busca la opcion que aumenta visibilidad sin afectar a otros conductores: bajar luces altas, reducir velocidad y anticipar fatiga.",
    commonMistake: "Pensar que las luces altas se mantienen encendidas siempre que la carretera este oscura.",
    keyPoints: [
      "Las luces altas deben bajarse cuando hay trafico cercano para evitar encandilar.",
      "De noche se reduce la visibilidad; conviene bajar velocidad y ampliar distancia de seguimiento.",
      "La fatiga y la poca visibilidad son riesgos de conduccion que el manual separa como desafios reales.",
      "En condiciones dificiles, la velocidad segura puede ser menor que el limite publicado."
    ],
    objective: "Responder como conductor defensivo cuando la visibilidad baja.",
    sourceLabel: "Manual del Conductor de Utah, Conduccion nocturna",
    sourceUrl: UTAH_DLD_HANDBOOK_ES_URL
  },
  "right-of-way": {
    answerStrategy:
      "Si una respuesta protege peatones, emergencia o trafico con derecho de paso, normalmente es la correcta.",
    commonMistake: "Confundir ceder el paso con detenerse solo cuando otro vehiculo ya esta encima.",
    keyPoints: [
      "Ante vehiculos de emergencia con sirena o luces, debes ceder, moverte al lado derecho y detenerte hasta que pasen.",
      "La ley move over exige reducir velocidad, dar espacio y cambiar de carril si es seguro ante vehiculos detenidos con luces.",
      "Debes ceder a peatones que entran o estan en un cruce peatonal, incluso si no esta marcado.",
      "Si los semaforos no funcionan, primero debes detenerte por completo y ceder segun corresponda."
    ],
    objective: "Practicar decisiones donde otra persona o vehiculo tiene prioridad legal.",
    sourceLabel: "Manual del Conductor de Utah, Derecho de paso y vehiculos de emergencia",
    sourceUrl: UTAH_DLD_HANDBOOK_ES_URL
  },
  signals: {
    answerStrategy:
      "Traduce cada color a accion: rojo detiene, amarillo prepara, verde permite solo si el camino esta despejado.",
    commonMistake: "Leer verde como permiso absoluto. El manual exige precaucion y camino despejado.",
    keyPoints: [
      "Semaforo verde: puedes avanzar con precaucion si el camino esta despejado.",
      "Semaforo amarillo: la luz esta por cambiar a rojo.",
      "Amarillo intermitente: reduce velocidad, procede con cautela y preparate para detenerte.",
      "Rojo: detente antes de entrar a la interseccion, linea de detencion o cruce peatonal."
    ],
    objective: "Reconocer la accion correcta ante luces, flechas y senales.",
    sourceLabel: "Manual del Conductor de Utah, Semaforos y senales",
    sourceUrl: UTAH_DLD_HANDBOOK_ES_URL
  },
  speed: {
    answerStrategy:
      "Primero revisa si hay senal. Si no hay, aplica los limites basicos y luego reduce por clima, visibilidad, trafico o peligro.",
    commonMistake: "Memorizar el numero y olvidar la regla basica: nunca manejar mas rapido de lo razonablemente seguro.",
    keyPoints: [
      "20 mph al pasar por escuela durante recreo, entrada/salida o cuando las luces intermitentes funcionan.",
      "25 mph en areas comerciales o residenciales sin senal.",
      "55 mph en autopistas principales cuando este publicado; interestatales rurales pueden publicar 65/70/75/80 mph.",
      "Debes reducir ante intersecciones, curvas, cima de colinas, vias estrechas, clima adverso, mala visibilidad y zonas de trabajo."
    ],
    objective: "Aprender limites base y cuando bajar la velocidad aunque la senal permita mas.",
    sourceLabel: "Manual del Conductor de Utah, Velocidad",
    sourceUrl: UTAH_DLD_HANDBOOK_ES_URL
  },
  "test-process": {
    answerStrategy:
      "Prioriza respuestas que remiten al manual oficial, al sitio .gov y a reglas confirmadas por Utah DLD.",
    commonMistake: "Confiar en bancos privados como si fueran el examen real. Utah DLD advierte estudiar el manual oficial.",
    keyPoints: [
      "Utah DLD indica que todas las preguntas se basan en el Manual del Conductor de Utah.",
      "Primera licencia: examen cerrado de 50 preguntas; licencia previa: examen abierto de 25 preguntas.",
      "La practica oficial en linea tiene 30 preguntas, 30 minutos, puntaje y retroalimentacion.",
      "El examen puede estar disponible en espanol con audio y texto, segun Utah DLD."
    ],
    objective: "Entender como se evalua antes de practicar preguntas.",
    sourceLabel: "Utah DLD, Written Knowledge Test y Practice Test",
    sourceUrl: UTAH_DLD_WRITTEN_TEST_URL
  }
};

function getDmvStudyGuide(module: DmvLearningModule, stateOfficialSource: StateOfficialSource | null): DmvStudyGuide {
  const guide = utahStudyGuides[module.moduleKey];
  if (guide) return guide;

  return {
    answerStrategy:
      "Lee la pregunta buscando la accion mas segura y confirmala contra la fuente oficial del estado antes de tomarla como regla.",
    commonMistake:
      "Usar reglas de otro estado. Cada estado puede cambiar formato, puntaje, documentos y detalles del manual.",
    keyPoints: [
      module.summaryEs,
      "Este modulo esta registrado como contenido oficial, pero el banco de preguntas puede estar pendiente.",
      "Para produccion, cada pregunta debe enlazarse a manual, pagina oficial o practica publica del estado."
    ],
    objective: `Estudiar ${module.titleEs.toLowerCase()} con fuente oficial verificada.`,
    sourceLabel: stateOfficialSource?.sourceTitle ?? "Fuente oficial del estado",
    sourceUrl: stateOfficialSource?.sourceUrl ?? UTAH_DLD_PRACTICE_TEST_URL
  };
}

const fallbackUtahDmvQuestions: DmvPracticeQuestion[] = [
  {
    answerKey: "b",
    choices: [
      { key: "a", label: "35 mph" },
      { key: "b", label: "25 mph" },
      { key: "c", label: "45 mph" }
    ],
    difficulty: "standard",
    displayOrder: 10,
    explanation: "El manual de Utah indica 25 mph en areas residenciales o comerciales sin senal.",
    id: "fallback-ut-speed-residential",
    moduleKey: "speed",
    prompt: "Si no hay senal, cual es el limite en una zona residencial o comercial de Utah?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "speed"
  },
  {
    answerKey: "a",
    choices: [
      { key: "a", label: "20 mph" },
      { key: "b", label: "30 mph" },
      { key: "c", label: "55 mph" }
    ],
    difficulty: "standard",
    displayOrder: 20,
    explanation: "El manual de Utah lista 20 mph al pasar una escuela durante recreo, entrada/salida o luces.",
    id: "fallback-ut-speed-school",
    moduleKey: "speed",
    prompt: "Cual es la velocidad indicada al pasar por una escuela durante entrada, salida o luces intermitentes?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "speed"
  },
  {
    answerKey: "c",
    choices: [
      { key: "a", label: "Seguir si no viene nadie" },
      { key: "b", label: "Tocar bocina y avanzar" },
      { key: "c", label: "Detenerse antes de entrar y esperar hasta que sea permitido" }
    ],
    difficulty: "intro",
    displayOrder: 30,
    explanation: "Ante luz roja debes detenerte antes de entrar a la interseccion.",
    id: "fallback-ut-red-light",
    moduleKey: "signals",
    prompt: "Que exige una luz roja antes de entrar a una interseccion?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "signals"
  },
  {
    answerKey: "b",
    choices: [
      { key: "a", label: "Acelerar para no bloquear" },
      { key: "b", label: "Reducir velocidad y proceder con cautela" },
      { key: "c", label: "Detenerse siempre 10 segundos" }
    ],
    difficulty: "intro",
    displayOrder: 40,
    explanation: "Una luz amarilla intermitente requiere reducir velocidad y proceder con cautela.",
    id: "fallback-ut-flashing-yellow",
    moduleKey: "signals",
    prompt: "Que debe hacer ante una luz amarilla intermitente?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "signals"
  },
  {
    answerKey: "c",
    choices: [
      { key: "a", label: "Usarlas siempre en ciudad" },
      { key: "b", label: "Apagarlas solo si hay niebla" },
      { key: "c", label: "Bajarlas ante trafico cercano" }
    ],
    difficulty: "standard",
    displayOrder: 50,
    explanation: "El manual indica bajar luces altas ante trafico cercano para no encandilar.",
    id: "fallback-ut-high-beams",
    moduleKey: "night-driving",
    prompt: "Que regla aplica con luces altas cuando hay vehiculos aproximandose?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "night-driving"
  },
  {
    answerKey: "b",
    choices: [
      { key: "a", label: "Seguir en tu carril a la misma velocidad" },
      { key: "b", label: "Moverte a la derecha y detenerte hasta que pase" },
      { key: "c", label: "Frenar en medio del carril izquierdo" }
    ],
    difficulty: "standard",
    displayOrder: 60,
    explanation:
      "Utah exige ceder el paso, moverse de inmediato al lado derecho de la via y detenerse hasta que pase el vehiculo de emergencia.",
    id: "fallback-ut-emergency-vehicle",
    moduleKey: "right-of-way",
    prompt: "Cuando se acerca una patrulla, ambulancia o camion de bomberos con sirena o luces, que debes hacer?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "right-of-way"
  },
  {
    answerKey: "a",
    choices: [
      { key: "a", label: "Reducir velocidad y dar espacio; cambiar de carril si es seguro" },
      { key: "b", label: "Mantener velocidad porque el vehiculo esta detenido" },
      { key: "c", label: "Usar la bocina para avisar que pasaras" }
    ],
    difficulty: "hard",
    displayOrder: 70,
    explanation:
      "La regla move over busca dar mas espacio y bajar la velocidad al pasar vehiculos detenidos con luces de emergencia.",
    id: "fallback-ut-move-over",
    moduleKey: "right-of-way",
    prompt: "Que resume mejor la ley move over al acercarte a un vehiculo detenido con luces de emergencia?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "right-of-way"
  },
  {
    answerKey: "a",
    choices: [
      { key: "a", label: "Fallar en mantenerse en el carril correcto" },
      { key: "b", label: "Usar luces bajas de dia" },
      { key: "c", label: "Estacionar en una pendiente" }
    ],
    difficulty: "standard",
    displayOrder: 80,
    explanation:
      "El manual lista fallar en mantenerse en el carril correcto entre las principales causas de choques en Utah.",
    id: "fallback-ut-lane-crash-stat",
    moduleKey: "right-of-way",
    prompt: "Que factor aparece entre las principales causas de choques en carreteras de Utah?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "safe-driving"
  },
  {
    answerKey: "b",
    choices: [
      { key: "a", label: "Mejoran el tiempo de reaccion" },
      { key: "b", label: "Reducen juicio, vision y tiempo de reaccion" },
      { key: "c", label: "Solo afectan si el viaje es largo" }
    ],
    difficulty: "standard",
    displayOrder: 90,
    explanation: "El manual explica que alcohol y drogas reducen juicio, vision y respuesta ante el manejo.",
    id: "fallback-ut-alcohol-drugs",
    moduleKey: "alcohol-drugs",
    prompt: "Que efecto pueden tener el alcohol y otras drogas al manejar?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "alcohol-drugs"
  },
  {
    answerKey: "a",
    choices: [
      { key: "a", label: "Usar solo sitios que terminen en .gov para informacion DLD" },
      { key: "b", label: "Cualquier pagina con logo sirve" },
      { key: "c", label: "Los sitios privados reemplazan al manual oficial" }
    ],
    difficulty: "intro",
    displayOrder: 100,
    explanation: "El manual advierte tener cuidado con sitios imitadores que no terminan en .gov.",
    id: "fallback-ut-official-sites",
    moduleKey: "test-process",
    prompt: "Que advertencia oficial da Utah DLD sobre sitios imitadores?",
    questionSetId: "fallback-utah",
    sourceRef: "Manual del Conductor de Utah.",
    topic: "test-process"
  }
];

const fallbackDmvModules: DmvLearningModule[] = [
  {
    displayOrder: 10,
    id: "fallback-module-test-process",
    moduleKey: "test-process",
    summaryEs: "Formato del examen, idiomas, practica oficial y reglas basadas en el manual.",
    titleEn: "Exam format",
    titleEs: "Formato del examen"
  },
  {
    displayOrder: 20,
    id: "fallback-module-speed",
    moduleKey: "speed",
    summaryEs: "Limites sin senal, escuelas y velocidad segura para condiciones reales.",
    titleEn: "Speed",
    titleEs: "Velocidad y zonas escolares"
  },
  {
    displayOrder: 30,
    id: "fallback-module-signals",
    moduleKey: "signals",
    summaryEs: "Luces rojas, amarillas, flechas y senales que aparecen en el manual.",
    titleEn: "Signals",
    titleEs: "Semaforos y senales"
  },
  {
    displayOrder: 40,
    id: "fallback-module-right-of-way",
    moduleKey: "right-of-way",
    summaryEs: "Emergencias, intersecciones, ceder el paso y ley move over.",
    titleEn: "Right of way",
    titleEs: "Derecho de paso"
  },
  {
    displayOrder: 50,
    id: "fallback-module-night-driving",
    moduleKey: "night-driving",
    summaryEs: "Luces altas, visibilidad, fatiga y conduccion en condiciones dificiles.",
    titleEn: "Night driving",
    titleEs: "Manejo nocturno"
  },
  {
    displayOrder: 60,
    id: "fallback-module-alcohol-drugs",
    moduleKey: "alcohol-drugs",
    summaryEs: "Efectos de alcohol y drogas, DUI, interlock y decisiones seguras.",
    titleEn: "Alcohol and drugs",
    titleEs: "Alcohol, drogas y seguridad"
  }
];

const fallbackDmvExamConfig: DmvExamConfig = {
  availableLanguages: ["Spanish", "English"],
  deliveryModes: ["in_person", "online_practice"],
  examName: "Utah escrito - primera licencia",
  id: "fallback-utah-exam",
  licenseType: "standard_operator_never_licensed",
  mustCorrectRules: {},
  notes: "Vista de demostracion basada en fuentes oficiales de Utah DLD.",
  openBook: false,
  passingScore: null,
  passingScorePercent: null,
  questionCount: 50,
  timeLimitMinutes: null
};

function UtilityHub({
  dataMode,
  dmvExamConfig,
  dmvLearningModules,
  dmvQuestions,
  onRecordDmvAttempt,
  stateOfficialSource
}: {
  dataMode: DataMode;
  dmvExamConfig: DmvExamConfig | null;
  dmvLearningModules: DmvLearningModule[];
  dmvQuestions: DmvPracticeQuestion[];
  onRecordDmvAttempt: (input: RecordDmvAttemptInput) => Promise<void>;
  stateOfficialSource: StateOfficialSource | null;
}) {
  const usePreviewFallback = dataMode !== "live" && dmvQuestions.length === 0;
  const questions = useMemo(
    () => (dmvQuestions.length > 0 ? dmvQuestions : usePreviewFallback ? fallbackUtahDmvQuestions : []),
    [dmvQuestions, usePreviewFallback]
  );
  const modules = useMemo(
    () => (dmvLearningModules.length > 0 ? dmvLearningModules : usePreviewFallback ? fallbackDmvModules : []),
    [dmvLearningModules, usePreviewFallback]
  );
  const examConfig = dmvExamConfig ?? (usePreviewFallback ? fallbackDmvExamConfig : null);
  const hasPractice = questions.length > 0;
  const stateName = stateOfficialSource?.stateName ?? "Utah";
  const [utilityMode, setUtilityMode] = useState<"study" | "practice">("study");
  const [selectedModuleKey, setSelectedModuleKey] = useState<string | null>(null);
  const [practiceModuleKey, setPracticeModuleKey] = useState<string | null>(null);
  const [quizStarted, setQuizStarted] = useState(false);
  const [questionIndex, setQuestionIndex] = useState(0);
  const [selectedChoice, setSelectedChoice] = useState<string | null>(null);
  const [score, setScore] = useState(0);
  const [quizAnswers, setQuizAnswers] = useState<DmvAttemptAnswerInput[]>([]);
  const [quizStartedAt, setQuizStartedAt] = useState<string | null>(null);
  const [attemptMessage, setAttemptMessage] = useState<string | null>(null);
  const moduleQuestionCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const question of questions) {
      if (!question.moduleKey) continue;
      counts.set(question.moduleKey, (counts.get(question.moduleKey) ?? 0) + 1);
    }
    return counts;
  }, [questions]);
  const moduleTitleByKey = useMemo(() => new Map(modules.map((module) => [module.moduleKey, module.titleEs])), [modules]);
  const activeModule = modules.find((module) => module.moduleKey === selectedModuleKey) ?? modules[0] ?? null;
  const activeGuide = activeModule ? getDmvStudyGuide(activeModule, stateOfficialSource) : null;
  const activeModuleQuestionCount = activeModule ? (moduleQuestionCounts.get(activeModule.moduleKey) ?? 0) : 0;
  const practiceQuestions = useMemo(() => {
    if (!practiceModuleKey) return questions;
    return questions.filter((question) => question.moduleKey === practiceModuleKey);
  }, [practiceModuleKey, questions]);
  const practiceQuestionCount = practiceQuestions.length;
  const practiceScopeLabel = practiceModuleKey ? (moduleTitleByKey.get(practiceModuleKey) ?? "Tema seleccionado") : "Practica completa";
  const currentQuestion =
    hasPractice && practiceQuestionCount > 0 ? practiceQuestions[Math.min(questionIndex, practiceQuestionCount - 1)]! : null;
  const answered = selectedChoice !== null;
  const completed = hasPractice && quizStarted && practiceQuestionCount > 0 && questionIndex >= practiceQuestionCount;
  const passingScore = examConfig?.passingScore
    ? Math.min(examConfig.passingScore, practiceQuestionCount || questions.length)
    : Math.ceil((practiceQuestionCount || questions.length) * 0.8);
  const passText =
    examConfig?.passingScore && examConfig.questionCount
      ? `${examConfig.passingScore}/${examConfig.questionCount}`
      : examConfig?.passingScorePercent
        ? `${examConfig.passingScorePercent}%`
        : "Practica recomendada 80%";
  const questionCountText = examConfig?.questionCount ? `${examConfig.questionCount} preguntas oficiales` : "Conteo oficial pendiente";
  const deliveryText = examConfig?.deliveryModes.length ? examConfig.deliveryModes.join(", ").replaceAll("_", " ") : "Segun estado";
  const languageText = examConfig?.availableLanguages.length ? examConfig.availableLanguages.slice(0, 4).join(", ") : "Ver fuente oficial";
  const officialSourceUrl = stateOfficialSource?.stateCode === "UT" ? UTAH_DLD_WRITTEN_TEST_URL : (stateOfficialSource?.sourceUrl ?? UTAH_DLD_WRITTEN_TEST_URL);

  const resetQuiz = (scopeModuleKey: string | null = null) => {
    if (!hasPractice) return;
    setPracticeModuleKey(scopeModuleKey);
    setQuizStarted(true);
    setQuestionIndex(0);
    setSelectedChoice(null);
    setScore(0);
    setQuizAnswers([]);
    setQuizStartedAt(new Date().toISOString());
    setAttemptMessage(null);
  };

  const startPractice = (scopeModuleKey: string | null = null) => {
    setUtilityMode("practice");
    resetQuiz(scopeModuleKey);
  };

  const advanceQuiz = async () => {
    if (!currentQuestion || selectedChoice === null) return;

    const correct = selectedChoice === currentQuestion.answerKey;
    const nextScore = score + (correct ? 1 : 0);
    const nextAnswers = [
      ...quizAnswers,
      {
        correct,
        questionId: currentQuestion.id,
        selectedOptionKey: selectedChoice
      }
    ];

    setScore(nextScore);
    setQuizAnswers(nextAnswers);
    setSelectedChoice(null);
    setQuestionIndex((current) => current + 1);

    if (questionIndex === practiceQuestionCount - 1 && dataMode === "live") {
      try {
        const startedAt = quizStartedAt ?? new Date().toISOString();
        const durationSeconds = Math.max(0, Math.round((Date.now() - new Date(startedAt).getTime()) / 1000));
        await onRecordDmvAttempt({
          answers: nextAnswers,
          durationSeconds,
          examConfigId: examConfig?.id ?? null,
          mode: "practice",
          passed: nextScore >= passingScore,
          questionSetId: currentQuestion.questionSetId,
          scoreCorrect: nextScore,
          startedAt,
          totalQuestions: practiceQuestionCount
        });
        setAttemptMessage("Resultado guardado en tu progreso.");
      } catch {
        setAttemptMessage("No se pudo guardar el resultado, pero tu practica termino.");
      }
    }
  };

  return (
    <main className="screen-stack light-screen">
      <TopBar guide={utilityHelp} title="Utilidades" />
      <p className="screen-subtitle">Herramientas y recursos para tu camino.</p>
      <section className="dmv-card">
        <div className="steering-wheel">
          <WalletCards size={34} />
        </div>
        <div>
          <strong>{hasPractice ? `Simulador DMV ${stateName}` : `Portal oficial DMV ${stateName}`}</strong>
          <span>
            {hasPractice
              ? `${questions.length} preguntas de practica, guias de estudio y explicaciones basadas en fuentes oficiales.`
              : "Fuente oficial verificada. El simulador se activa cuando importemos el manual de este estado."}
          </span>
          {hasPractice ? (
            <button className="primary-button" onClick={() => startPractice(null)}>
              {quizStarted ? "Reiniciar practica completa" : "Comenzar practica"} <ChevronRight size={16} />
            </button>
          ) : stateOfficialSource ? (
            <a className="dmv-source-link" href={stateOfficialSource.sourceUrl} rel="noreferrer" target="_blank">
              Abrir fuente oficial <ChevronRight size={16} />
            </a>
          ) : null}
        </div>
      </section>

      <div className="utility-mode-switch" aria-label="Modo del simulador de manejo">
        <button className={utilityMode === "study" ? "active" : ""} onClick={() => setUtilityMode("study")} type="button">
          <BookOpen size={16} /> Estudiar
        </button>
        <button className={utilityMode === "practice" ? "active" : ""} onClick={() => setUtilityMode("practice")} type="button">
          <ClipboardCheck size={16} /> Practicar
        </button>
      </div>

      <section className="dmv-meta-grid">
        <article>
          <span>Examen</span>
          <strong>{examConfig?.examName ?? "Pendiente de importar"}</strong>
          <small>{questionCountText}</small>
        </article>
        <article>
          <span>Aprobacion</span>
          <strong>{passText}</strong>
          <small>{examConfig?.openBook === null ? "Ver regla oficial" : examConfig?.openBook ? "Libro abierto" : "Libro cerrado"}</small>
        </article>
        <article>
          <span>Modalidad</span>
          <strong>{deliveryText}</strong>
          <small>{languageText}</small>
        </article>
      </section>

      {utilityMode === "study" && modules.length > 0 ? (
        <section className="section-block dmv-study-section">
          <div className="section-heading">
            <h2>Estudia antes de practicar</h2>
            <a className="dmv-source-link compact" href={officialSourceUrl} rel="noreferrer" target="_blank">
              Fuente oficial <ExternalLink size={14} />
            </a>
          </div>
          <div className="dmv-study-layout">
            <div className="dmv-module-list" aria-label="Temas de estudio">
              {modules.map((module) => {
                const questionTotal = moduleQuestionCounts.get(module.moduleKey) ?? 0;
                return (
                  <button
                    className={`dmv-module selectable ${activeModule?.moduleKey === module.moduleKey ? "selected" : ""}`}
                    key={module.id}
                    onClick={() => setSelectedModuleKey(module.moduleKey)}
                    type="button"
                  >
                    <span>{String(module.displayOrder).padStart(2, "0")}</span>
                    <div>
                      <strong>{module.titleEs}</strong>
                      <small>{module.summaryEs}</small>
                      <em>{questionTotal > 0 ? `${questionTotal} preguntas de practica` : "Lectura oficial pendiente de banco"}</em>
                    </div>
                  </button>
                );
              })}
            </div>

            {activeModule && activeGuide ? (
              <article className="study-guide-panel">
                <div className="study-guide-heading">
                  <span className="quiz-topic">{activeModule.moduleKey.replaceAll("-", " ")}</span>
                  <strong>{activeModule.titleEs}</strong>
                  <p>{activeGuide.objective}</p>
                </div>
                <div className="study-guide-body">
                  <div>
                    <div className="study-subheading">
                      <ListChecks size={17} />
                      <strong>Claves para responder</strong>
                    </div>
                    <ul className="study-key-points">
                      {activeGuide.keyPoints.map((point) => (
                        <li key={point}>{point}</li>
                      ))}
                    </ul>
                  </div>
                  <aside className="study-answer-notes">
                    <span>Error comun</span>
                    <p>{activeGuide.commonMistake}</p>
                    <span>Estrategia</span>
                    <p>{activeGuide.answerStrategy}</p>
                  </aside>
                </div>
                <div className="study-guide-actions">
                  <button
                    className="primary-button"
                    disabled={activeModuleQuestionCount === 0}
                    onClick={() => startPractice(activeModule.moduleKey)}
                  >
                    Practicar este tema <ChevronRight size={16} />
                  </button>
                  <a className="dmv-source-link compact" href={activeGuide.sourceUrl} rel="noreferrer" target="_blank">
                    {activeGuide.sourceLabel} <ExternalLink size={14} />
                  </a>
                </div>
              </article>
            ) : null}
          </div>
        </section>
      ) : null}

      {utilityMode === "practice" ? (
        <section className="section-block dmv-practice-section">
          <div className="section-heading">
            <h2>Practica interactiva</h2>
            <button className="study-return-button" onClick={() => setUtilityMode("study")} type="button">
              Volver a estudiar
            </button>
          </div>
          <div className="practice-scope-row" aria-label="Tipo de practica">
            <button className={!practiceModuleKey ? "active" : ""} onClick={() => resetQuiz(null)} type="button">
              Completa <span>{questions.length}</span>
            </button>
            {modules.map((module) => {
              const questionTotal = moduleQuestionCounts.get(module.moduleKey) ?? 0;
              return (
                <button
                  className={practiceModuleKey === module.moduleKey ? "active" : ""}
                  disabled={questionTotal === 0}
                  key={module.id}
                  onClick={() => resetQuiz(module.moduleKey)}
                  type="button"
                >
                  {module.titleEs} <span>{questionTotal}</span>
                </button>
              );
            })}
          </div>

          {!quizStarted ? (
            <section className="quiz-panel quiz-start-panel">
              <div className="quiz-result">
                <strong>Elige practica completa o por tema.</strong>
                <span>Primero estudia las claves, despues responde. La explicacion aparece al seleccionar cada respuesta.</span>
              </div>
              <button className="primary-button" disabled={!hasPractice} onClick={() => resetQuiz(null)}>
                Iniciar practica completa
              </button>
            </section>
          ) : null}

          {quizStarted && currentQuestion ? (
            <section className="quiz-panel">
              {completed ? (
                <>
                  <div className="quiz-result">
                    <strong>
                      Resultado {practiceScopeLabel}: {score}/{practiceQuestionCount}
                    </strong>
                    <span>
                      {score >= passingScore
                        ? "Buen resultado para seguir reforzando por temas."
                        : "Repasa los modulos marcados y repite la practica."}
                    </span>
                  </div>
                  {attemptMessage ? <span className="quiz-explanation">{attemptMessage}</span> : null}
                  <button className="primary-button" onClick={() => resetQuiz(practiceModuleKey)}>
                    Repetir practica
                  </button>
                </>
              ) : (
                <>
                  <div className="quiz-heading">
                    <strong>
                      {practiceScopeLabel}: pregunta {questionIndex + 1}/{practiceQuestionCount}
                    </strong>
                    <a href={officialSourceUrl} rel="noreferrer" target="_blank">
                      Fuente oficial
                    </a>
                  </div>
                  {currentQuestion.moduleKey ? (
                    <span className="quiz-topic">{moduleTitleByKey.get(currentQuestion.moduleKey) ?? currentQuestion.moduleKey.replaceAll("-", " ")}</span>
                  ) : null}
                  <p>{currentQuestion.prompt}</p>
                  <div className="quiz-options">
                    {currentQuestion.choices.map((choice) => {
                      const isCorrect = answered && choice.key === currentQuestion.answerKey;
                      const isWrong = answered && choice.key === selectedChoice && choice.key !== currentQuestion.answerKey;
                      return (
                        <button
                          className={`${isCorrect ? "correct" : ""} ${isWrong ? "wrong" : ""}`}
                          disabled={answered}
                          key={choice.key}
                          onClick={() => setSelectedChoice(choice.key)}
                        >
                          {choice.label}
                        </button>
                      );
                    })}
                  </div>
                  {answered && currentQuestion.explanation ? (
                    <span className="quiz-explanation">
                      {currentQuestion.explanation}
                      {currentQuestion.sourceRef ? ` Fuente: ${currentQuestion.sourceRef}` : ""}
                    </span>
                  ) : null}
                  {answered ? (
                    <button className="primary-button" onClick={() => void advanceQuiz()}>
                      {questionIndex === practiceQuestionCount - 1 ? "Ver resultado" : "Siguiente"}
                    </button>
                  ) : null}
                </>
              )}
            </section>
          ) : null}
        </section>
      ) : null}

      <section className="tool-grid" aria-label="Herramientas destacadas">
        <ToolButton icon={CalendarDays} label="Fechas clave" />
        <ToolButton icon={Grid2X2} label="Calculadora de dias" />
        <ToolButton icon={CheckSquare} label="Checklist personal" />
        <ToolButton icon={Lock} label="Notas seguras" />
      </section>

      <section className="section-block">
        <h2>Recursos locales . Utah</h2>
        <div className="resource-list">
          {resourceRows.map((row) => (
            <button className="resource-row" key={row.id}>
              <MapPin size={20} />
              <span>
                <strong>{row.label}</strong>
                <small>{row.detail}</small>
              </span>
              <ChevronRight size={18} />
            </button>
          ))}
        </div>
      </section>

      <div className="trust-strip">
        <ShieldCheck size={28} />
        <div>
          <strong>Informacion confiable.</strong>
          <span>Comunidad que te respalda.</span>
        </div>
      </div>
    </main>
  );
}

function MorePanel({
  message,
  onRequestService,
  services,
  workflowBusy
}: {
  message: string | null;
  onRequestService: (serviceType: PremiumServiceType) => Promise<void>;
  services: PremiumService[];
  workflowBusy: boolean;
}) {
  const annuality = services.find((service) => service.serviceType === "ANNUALITY_PAYMENT");
  const expert = services.find((service) => service.serviceType === "EXPERT_REVIEW");

  return (
    <main className="screen-stack light-screen">
      <TopBar guide={servicesHelp} title="Servicios premium" />
      <section className="premium-panel">
        <Sparkles size={30} />
        <h1>Servicios de prueba</h1>
        <p>Activa solicitudes gratis mientras validamos el flujo completo antes de implementar pagos.</p>
        <button
          className="primary-button"
          disabled={workflowBusy}
          onClick={() => void onRequestService("EXPERT_REVIEW")}
        >
          Solicitar revision <MessageCircle size={16} />
        </button>
      </section>
      <PwaInstallCard />
      {message ? <p className="form-success">{message}</p> : null}

      <section className="section-block">
        <h2>Servicios disponibles</h2>
        <div className="service-list">
          <article className="service-card annuality">
            <div className="service-icon">
              <CreditCard size={24} />
            </div>
            <div>
              <strong>{annuality?.title ?? "Pago de anualidades"}</strong>
              <p>{annuality?.description ?? "Administra pagos anuales, comprobantes y recordatorios de renovacion."}</p>
              <span>Gratis por ahora . comprobante interno</span>
            </div>
            <button
              className="secondary-button"
              disabled={workflowBusy}
              onClick={() => void onRequestService("ANNUALITY_PAYMENT")}
            >
              Activar gratis
            </button>
          </article>

          <article className="service-card">
            <div className="service-icon expert">
              <MessageCircle size={24} />
            </div>
            <div>
              <strong>{expert?.title ?? "Revision experta"}</strong>
              <p>{expert?.description ?? "Un especialista revisa tu caso antes de avanzar con tramites delicados."}</p>
              <span>Gratis durante prueba</span>
            </div>
            <button
              className="secondary-button"
              disabled={workflowBusy}
              onClick={() => void onRequestService("EXPERT_REVIEW")}
            >
              Solicitar gratis
            </button>
          </article>
        </div>
      </section>

      <section className="section-block">
        <h2>Seguimiento especial</h2>
        <div className="timeline">
          <span />
          <div>
            <strong>Consulta inicial</strong>
            <small>Completada</small>
          </div>
          <span />
          <div>
            <strong>Revision documental</strong>
            <small>En progreso</small>
          </div>
          <span />
          <div>
            <strong>Paquete final</strong>
            <small>Pendiente</small>
          </div>
        </div>
      </section>
    </main>
  );
}

function BottomNav({ activeTab, onChange }: { activeTab: TabId; onChange: (tab: TabId) => void }) {
  return (
    <nav className="bottom-nav" aria-label="Navegacion principal">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        return (
          <button className={activeTab === tab.id ? "active" : ""} onClick={() => onChange(tab.id)} key={tab.id}>
            <Icon size={19} />
            <span>{tab.label}</span>
          </button>
        );
      })}
    </nav>
  );
}

function TopBar({ guide, title }: { guide?: SectionHelp; title: string }) {
  const [helpOpen, setHelpOpen] = useState(false);

  return (
    <>
      <div className="top-bar">
        <h1>{title}</h1>
        <div>
          <button className="icon-button light" aria-label="Buscar" type="button">
            <Search size={18} />
          </button>
          <button
            className="icon-button light"
            aria-label={guide ? "Ayuda de esta pantalla" : "Menu"}
            onClick={guide ? () => setHelpOpen(true) : undefined}
            type="button"
          >
            {guide ? <Sparkles size={18} /> : <Menu size={18} />}
          </button>
        </div>
      </div>
      {guide && helpOpen ? <SectionHelpModal guide={guide} onClose={() => setHelpOpen(false)} /> : null}
    </>
  );
}

function SectionHelpModal({ guide, onClose }: { guide: SectionHelp; onClose: () => void }) {
  return (
    <div className="section-help-overlay" role="dialog" aria-modal="true" aria-labelledby="section-help-title">
      <section className="section-help-modal">
        <div className="section-help-top">
          <span>{guide.kicker}</span>
          <button onClick={onClose} type="button">Cerrar</button>
        </div>
        <div className="section-help-hero">
          <div className="section-help-icon">
            <Sparkles size={24} />
          </div>
          <div>
            <h2 id="section-help-title">{guide.title}</h2>
            <p>{guide.body}</p>
          </div>
        </div>
        <ol className="section-help-steps">
          {guide.steps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
        <button className="primary-button section-help-action" onClick={onClose} type="button">
          Entendido
        </button>
      </section>
    </div>
  );
}

function IconTile({ severity, kind }: { severity: StatusSeverity; kind: string }) {
  const Icon = kind === "court_hearing" ? CalendarDays : kind === "ead_expiration" ? WalletCards : ShieldCheck;
  return (
    <div className={`icon-tile ${severity}`}>
      <Icon size={22} />
    </div>
  );
}

function Metric({ value, label }: { value: number; label: string }) {
  return (
    <article className="metric-card">
      <strong>{value}</strong>
      <span>{label}</span>
    </article>
  );
}

function ToolButton({ icon: Icon, label }: { icon: typeof CalendarDays; label: string }) {
  return (
    <button className="tool-button">
      <Icon size={24} />
      <span>{label}</span>
    </button>
  );
}
