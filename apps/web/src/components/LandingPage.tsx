import { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  Bell,
  CalendarDays,
  Check,
  ChevronRight,
  FileCheck2,
  FolderLock,
  Landmark,
  LockKeyhole,
  MapPin,
  MessageCircle,
  ShieldCheck,
  WalletCards
} from "lucide-react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import heroKeyframe from "../assets/landing/micaso-hero-keyframe.png";
import micasoPrimeLogo from "../assets/landing/micaso-prime-logo.png";
import heroVideoDesktop from "../assets/landing/hero-video-desktop.mp4";
import heroVideoMobile from "../assets/landing/hero-video-mobile.mp4";
import alertsTrackerKeyframe from "../assets/landing/video-keyframes/alerts-tracker-1x1.png";
import automationKeyframe from "../assets/landing/video-keyframes/automation-pdf-1x1.png";
import dmvKeyframe from "../assets/landing/video-keyframes/dmv-resources-1x1.png";
import finalKeyframe from "../assets/landing/video-keyframes/final-constellation-16x9.png";
import supportKeyframe from "../assets/landing/video-keyframes/expert-support-1x1.png";
import stickyKeyframe from "../assets/landing/video-keyframes/sticky-control-center-1x1.png";
import vaultKeyframe from "../assets/landing/video-keyframes/secure-vault-1x1.png";
import alertsTrackerVideo from "../assets/landing/videos/alerts-tracker.mp4";
import automationVideo from "../assets/landing/videos/automation-pdf.mp4";
import dmvVideo from "../assets/landing/videos/dmv-resources.mp4";
import finalVideoDesktop from "../assets/landing/videos/final-constellation-16x9.mp4";
import finalVideoMobile from "../assets/landing/videos/final-constellation-1x1.mp4";
import supportVideo from "../assets/landing/videos/expert-support.mp4";
import stickyVideo from "../assets/landing/videos/sticky-control-center.mp4";
import vaultVideo from "../assets/landing/videos/secure-vault.mp4";
import "../styles/landing.css";

gsap.registerPlugin(ScrollTrigger);

const painPoints = [
  "Fotos de documentos en lugares distintos",
  "Fechas de corte y permisos en la memoria",
  "Formularios difíciles de preparar sin orden",
  "DMV y recursos que cambian por estado"
];

const scrollChapters = [
  {
    icon: FolderLock,
    kicker: "01 / Boveda",
    stat: "Documentos localizables",
    title: "Sube tus documentos.",
    copy: "Pasaporte, I-94, recibos, permisos y notificaciones quedan organizados por tipo, agencia, fecha y prioridad."
  },
  {
    icon: Bell,
    kicker: "02 / Alertas",
    stat: "Semaforo migratorio",
    title: "Detecta fechas criticas.",
    copy: "Audiencias, permisos por vencer y proximos pasos aparecen en un panel claro para que no dependas de tu memoria."
  },
  {
    icon: FileCheck2,
    kicker: "03 / Formularios",
    stat: "PDF listo para revisar",
    title: "Prepara paquetes guiados.",
    copy: "Tu perfil alimenta flujos para AR-11, I-765, cambio de sede y anualidades. Tu revisas antes de firmar o enviar."
  },
  {
    icon: WalletCards,
    kicker: "04 / Adaptacion",
    stat: "DMV y recursos",
    title: "Activa herramientas locales.",
    copy: "Estudia para el DMV, practica por estado y encuentra recursos comunitarios desde el mismo centro de control."
  }
];

const serviceSections = [
  {
    accent: "lime",
    detail:
      "Guarda pasaporte, I-94, recibos USCIS, permisos, notificaciones de corte y documentos clave con carpetas inteligentes y acceso offline.",
    image: vaultKeyframe,
    kicker: "Boveda segura",
    points: ["Clasificacion documental", "Acceso offline", "Carpetas por agencia"],
    title: "Tus documentos dejan de estar regados.",
    video: vaultVideo
  },
  {
    accent: "blue",
    detail:
      "Centraliza fechas de corte, vencimientos de permisos, recibos y proximas acciones con un semaforo verde, amarillo o rojo.",
    image: alertsTrackerKeyframe,
    kicker: "Alertas y tracker",
    points: ["Audiencias", "Vencimientos", "Semaforo de estatus"],
    title: "No dependas de tu memoria para fechas importantes.",
    video: alertsTrackerVideo
  },
  {
    accent: "orange",
    detail:
      "Convierte datos del perfil en paquetes guiados para revisar, firmar y enviar. La app prepara y organiza; no reemplaza asesoria legal.",
    image: automationKeyframe,
    kicker: "Automatizacion guiada",
    points: ["AR-11", "I-765", "Cambio de sede", "Anualidades"],
    title: "De tu perfil a formularios listos para revisar.",
    video: automationVideo
  },
  {
    accent: "lilac",
    detail:
      "Estudia con contenido por estado, practica respuestas y consulta recursos locales como clinicas, asistencia alimentaria y servicios comunitarios.",
    image: dmvKeyframe,
    kicker: "DMV y recursos",
    points: ["Estudio por estado", "Practica interactiva", "Recursos locales"],
    title: "Tambien te ayuda a adaptarte al estado donde vives.",
    video: dmvVideo
  },
  {
    accent: "support",
    detail:
      "Cuando el caso requiere criterio humano, solicita acompañamiento para asilo, SIJS, apelaciones o casos especiales sin perder tu historial.",
    image: supportKeyframe,
    kicker: "Soporte experto",
    points: ["Casos especiales", "Historial organizado", "Dashboard de progreso"],
    title: "Cuando tu caso pesa, entra el equipo.",
    video: supportVideo
  }
];

const pricingItems = [
  "Boveda segura de documentos",
  "Alertas criticas y semaforo",
  "Formularios guiados y PDF",
  "DMV, estudio y recursos",
  "Soporte experto bajo solicitud"
];

function useHeroVideoSource() {
  return useResponsiveVideoSource(heroVideoDesktop, heroVideoMobile);
}

function useFinalVideoSource() {
  return useResponsiveVideoSource(finalVideoDesktop, finalVideoMobile);
}

function useResponsiveVideoSource(desktopSource: string, mobileSource: string) {
  const [videoSource, setVideoSource] = useState(desktopSource);

  useEffect(() => {
    const mediaQuery = window.matchMedia("(max-width: 620px)");
    const updateVideoSource = () => {
      setVideoSource(mediaQuery.matches ? mobileSource : desktopSource);
    };

    updateVideoSource();
    mediaQuery.addEventListener("change", updateVideoSource);

    return () => {
      mediaQuery.removeEventListener("change", updateVideoSource);
    };
  }, [desktopSource, mobileSource]);

  return videoSource;
}

function MediaObject({
  alt,
  className = "",
  image,
  label,
  meta,
  video
}: {
  alt: string;
  className?: string;
  image: string;
  label: string;
  meta: string;
  video?: string;
}) {
  return (
    <div className={`lp-media-object ${className}`}>
      {video ? (
        <video
          aria-label={alt}
          autoPlay
          className="lp-stage-video"
          loop
          muted
          playsInline
          poster={image}
          preload="metadata"
        >
          <source src={video} type="video/mp4" />
        </video>
      ) : (
        <img alt={alt} loading="lazy" src={image} />
      )}
      <div className="lp-media-overlay" aria-hidden="true" />
      <div className="lp-media-caption">
        <span>{label}</span>
        <strong>{meta}</strong>
      </div>
    </div>
  );
}

function ModularConstellation() {
  return (
    <div className="lp-mini-constellation" aria-hidden="true">
      <span className="lime" />
      <span className="blue" />
      <span className="orange" />
      <span className="lilac" />
      <span className="white" />
    </div>
  );
}

export function LandingPage() {
  const landingRef = useRef<HTMLDivElement | null>(null);
  const heroVideoSource = useHeroVideoSource();
  const finalVideoSource = useFinalVideoSource();

  useLayoutEffect(() => {
    if (!landingRef.current) return;

    if ("scrollRestoration" in window.history) {
      window.history.scrollRestoration = "manual";
    }
    window.scrollTo({ left: 0, top: 0 });
    ScrollTrigger.clearScrollMemory();

    const resetScroll = window.setTimeout(() => {
      window.scrollTo({ left: 0, top: 0 });
      ScrollTrigger.refresh();
    }, 80);

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const context = gsap.context(() => {
      gsap.set(".lp-scroll-step", { autoAlpha: 0, y: 22, yPercent: -50 });
      gsap.set(".lp-scroll-step[data-step='1']", { autoAlpha: 1, y: 0, yPercent: -50 });

      if (reduceMotion) return;

      gsap.from(".lp-hero-copy > *", {
        duration: 0.9,
        ease: "power3.out",
        stagger: 0.08,
        y: 22
      });

      gsap.from(".lp-hero-cinema", {
        duration: 1.05,
        ease: "power3.out",
        scale: 1.025,
        y: 26
      });

      gsap.to(".lp-hero-keyframe", {
        ease: "none",
        scale: 1.08,
        scrollTrigger: {
          end: "bottom top",
          scrub: 0.8,
          start: "top top",
          trigger: ".lp-hero"
        }
      });

      const storyTimeline = gsap.timeline({
        defaults: { ease: "none" },
        scrollTrigger: {
          end: "+=2800",
          pin: ".lp-scroll-showcase",
          scrub: 0.75,
          start: "top top"
        }
      });

      storyTimeline
        .to(".lp-sticky-media .lp-stage-video", { scale: 1.08, xPercent: -3, yPercent: -2 }, 0)
        .to(".lp-scroll-orbit", { rotation: 52, scale: 1.08 }, 0)
        .to(".lp-scroll-step[data-step='1']", { autoAlpha: 0, y: -24 }, 0.18)
        .to(".lp-scroll-step[data-step='2']", { autoAlpha: 1, y: 0 }, 0.22)
        .to(".lp-scroll-step[data-step='2']", { autoAlpha: 0, y: -24 }, 0.42)
        .to(".lp-scroll-step[data-step='3']", { autoAlpha: 1, y: 0 }, 0.48)
        .to(".lp-sticky-media .lp-stage-video", { scale: 1.13, xPercent: 3, yPercent: 2 }, 0.5)
        .to(".lp-scroll-step[data-step='3']", { autoAlpha: 0, y: -24 }, 0.68)
        .to(".lp-scroll-step[data-step='4']", { autoAlpha: 1, y: 0 }, 0.74)
        .to(".lp-scroll-rail i", { height: "100%" }, 0);

      gsap.utils.toArray<HTMLElement>(".lp-reveal").forEach((element) => {
        gsap.from(element, {
          autoAlpha: 0,
          duration: 0.75,
          ease: "power3.out",
          scrollTrigger: {
            start: "top 78%",
            trigger: element
          },
          y: 28
        });
      });
    }, landingRef);

    return () => {
      window.clearTimeout(resetScroll);
      context.revert();
    };
  }, []);

  return (
    <div className="lp-page" ref={landingRef}>
      <header className="lp-nav">
        <a className="lp-brand" href="#inicio" aria-label="MiCaso Prime inicio">
          <span className="lp-brand-mark" aria-hidden="true">
            <img alt="" src={micasoPrimeLogo} />
          </span>
          <span>
            <strong>MiCaso Prime</strong>
            <small>by UsaLatino Prime</small>
          </span>
        </a>
        <nav aria-label="Landing">
          <a href="#problema">Problema</a>
          <a href="#producto">Producto</a>
          <a href="#servicios">Servicios</a>
          <a href="#precio">Precio</a>
        </nav>
        <a className="lp-nav-cta" href="/">
          Entrar a la app <ChevronRight size={16} />
        </a>
      </header>

      <main>
        <section className="lp-hero" id="inicio">
          <div className="lp-hero-copy">
            <span className="lp-product-line">MiCaso Prime · $14/mes</span>
            <h1>Tu proceso migratorio, en una sola vista.</h1>
            <p>
              Organiza documentos, fechas criticas, formularios, DMV y soporte experto en un centro de control diseñado
              para inmigrantes en Estados Unidos.
            </p>
            <div className="lp-hero-actions">
              <a className="lp-primary" href="/">
                Empezar por $14/mes <ChevronRight size={18} />
              </a>
              <a className="lp-secondary" href="#producto">
                Ver como funciona
              </a>
            </div>
            <div className="lp-hero-proof" aria-label="Resumen de confianza">
              <span><ShieldCheck size={16} /> Fuentes oficiales</span>
              <span><LockKeyhole size={16} /> Boveda privada</span>
              <span><MessageCircle size={16} /> Soporte humano</span>
            </div>
          </div>
          <div className="lp-hero-cinema" aria-label="Video principal de MiCaso Prime">
            <video
              key={heroVideoSource}
              className="lp-hero-keyframe"
              autoPlay
              loop
              muted
              playsInline
              poster={heroKeyframe}
              preload="auto"
              aria-label="Video cinematografico de MiCaso Prime"
            >
              <source src={heroVideoSource} type="video/mp4" />
            </video>
            <div className="lp-video-meta">
              <span>Centro de control</span>
              <strong>Boveda · Alertas · Formularios</strong>
            </div>
          </div>
        </section>

        <section className="lp-problem-section" id="problema">
          <div className="lp-problem-copy lp-reveal">
            <h2>El problema no es solo el tramite. Es el desorden.</h2>
            <p>
              Fotos sueltas, correos, recibos, permisos, fechas de corte y formularios viven en lugares distintos.
              MiCaso Prime convierte ese caos en un sistema claro.
            </p>
          </div>
          <div className="lp-chaos-board lp-reveal" aria-label="Documentos dispersos antes de organizarse">
            {painPoints.map((point, index) => (
              <div className={`lp-chaos-card card-${index + 1}`} key={point}>
                <span>{`0${index + 1}`}</span>
                <strong>{point}</strong>
              </div>
            ))}
            <div className="lp-order-core">
              <FolderLock size={24} />
              <strong>MiCaso Prime</strong>
              <span>Orden migratorio</span>
            </div>
          </div>
        </section>

        <section className="lp-scroll-showcase" id="producto">
          <div className="lp-scroll-copy">
            {scrollChapters.map((chapter, index) => {
              const Icon = chapter.icon;
              return (
                <article className="lp-scroll-step" data-step={index + 1} key={chapter.title}>
                  <span>{chapter.kicker}</span>
                  <h2>{chapter.title}</h2>
                  <p>{chapter.copy}</p>
                  <strong><Icon size={16} /> {chapter.stat}</strong>
                </article>
              );
            })}
          </div>
          <div className="lp-sticky-media" aria-label="Demo visual de scroll">
            <video
              aria-label="Centro de control MiCaso Prime"
              autoPlay
              className="lp-stage-video"
              loop
              muted
              playsInline
              poster={stickyKeyframe}
              preload="metadata"
            >
              <source src={stickyVideo} type="video/mp4" />
            </video>
            <div className="lp-scroll-orbit" aria-hidden="true">
              <span>I-94</span>
              <span>Corte</span>
              <span>PDF</span>
              <span>DMV</span>
            </div>
          </div>
          <div className="lp-scroll-rail" aria-hidden="true">
            <i />
          </div>
        </section>

        <section className="lp-services-intro" id="servicios">
          <div className="lp-section-heading lp-reveal">
            <h2>Un SaaS para ordenar lo que mas miedo da perder.</h2>
            <p>
              La landing debe vender claridad: cada modulo resuelve una parte concreta del proceso, sin prometer asesoria
              legal automatica.
            </p>
          </div>
        </section>

        <div className="lp-service-stack">
          {serviceSections.map((service, index) => (
            <section className={`lp-service-section ${index % 2 === 1 ? "reverse" : ""}`} key={service.title}>
              <div className="lp-service-copy lp-reveal">
                <span className={`lp-kicker ${service.accent}`}>{service.kicker}</span>
                <h2>{service.title}</h2>
                <p>{service.detail}</p>
                <div className="lp-service-points">
                  {service.points.map((point) => (
                    <span key={point}><Check size={15} /> {point}</span>
                  ))}
                </div>
              </div>
              <MediaObject
                alt={`${service.kicker} en MiCaso Prime`}
                className={`lp-reveal ${service.accent}`}
                image={service.image}
                label={service.kicker}
                meta="Video component"
                video={service.video}
              />
            </section>
          ))}
        </div>

        <section className="lp-price-section" id="precio">
          <div className="lp-price-copy lp-reveal">
            <span className="lp-kicker lime">Membresia mensual</span>
            <h2>Todo tu proceso en orden por $14 al mes.</h2>
            <p>
              Una membresia para organizar documentos, recibir alertas, preparar formularios guiados, estudiar DMV y
              acceder a recursos clave.
            </p>
          </div>
          <div className="lp-price-card lp-reveal">
            <div>
              <span>MiCaso Prime</span>
              <strong>$14<small>/mes</small></strong>
            </div>
            <ul>
              {pricingItems.map((item) => (
                <li key={item}><Check size={16} /> {item}</li>
              ))}
            </ul>
            <a className="lp-primary" href="/">
              Empezar por $14 <ChevronRight size={18} />
            </a>
            <p>La app organiza y prepara. No reemplaza asesoria legal.</p>
          </div>
        </section>

        <section className="lp-trust-section" id="confianza">
          <div className="lp-trust-copy lp-reveal">
            <span className="lp-kicker blue">Confianza responsable</span>
            <h2>Tecnologia clara. Fuentes oficiales. Soporte humano.</h2>
            <p>
              MiCaso Prime organiza informacion, versiones y proximos pasos para que tengas control antes de revisar,
              firmar o pedir ayuda profesional.
            </p>
            <strong>No somos una agencia gubernamental.</strong>
          </div>
          <div className="lp-trust-grid">
            <article className="lp-trust-card lp-reveal">
              <Landmark size={22} />
              <strong>Fuentes oficiales</strong>
              <span>Contenido versionado por estado y por tipo de tramite.</span>
            </article>
            <article className="lp-trust-card lp-reveal">
              <LockKeyhole size={22} />
              <strong>Privacidad</strong>
              <span>Boveda privada y documentos organizados por prioridad.</span>
            </article>
            <article className="lp-trust-card lp-reveal">
              <CalendarDays size={22} />
              <strong>Historial organizado</strong>
              <span>Fechas, acciones y comprobantes reunidos en un mismo lugar.</span>
            </article>
            <article className="lp-trust-card lp-reveal">
              <MapPin size={22} />
              <strong>Contenido por estado</strong>
              <span>DMV, recursos locales y flujos pensados para escalar a EE. UU.</span>
            </article>
          </div>
        </section>

        <section className="lp-final-cta">
          <div className="lp-final-copy lp-reveal">
            <span className="lp-kicker orange">Empieza hoy</span>
            <h2>Empieza ordenando tu proceso hoy.</h2>
            <p>
              Por $14 al mes, MiCaso Prime te ayuda a mantener documentos, fechas, formularios, DMV y recursos en un
              solo centro de control.
            </p>
            <div className="lp-hero-actions">
              <a className="lp-primary" href="/">
                Crear mi cuenta por $14/mes <ChevronRight size={18} />
              </a>
              <a className="lp-secondary dark" href="#servicios">
                Revisar servicios
              </a>
            </div>
          </div>
          <div className="lp-final-visual lp-reveal">
            <video
              aria-label="Constelacion final de servicios MiCaso Prime"
              autoPlay
              className="lp-stage-video"
              key={finalVideoSource}
              loop
              muted
              playsInline
              poster={finalKeyframe}
              preload="metadata"
            >
              <source src={finalVideoSource} type="video/mp4" />
            </video>
            <ModularConstellation />
          </div>
        </section>
      </main>
    </div>
  );
}
