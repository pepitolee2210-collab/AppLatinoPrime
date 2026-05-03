# USA Latino Prime: investigacion y plan de implementacion

## Principio operativo

La app debe automatizar organizacion, recordatorios, prellenado, validacion y exportacion. No debe presentar casos ni dar asesoria legal automatica sin control humano. Los flujos complejos, como cambio de sede, asilo, SIJS y apelaciones, pasan por revision experta.

## Fuentes oficiales iniciales

- USCIS Developer Portal: https://developer.uscis.gov/
- USCIS Case Status API: https://developer.uscis.gov/apis
- USCIS Change of Address: https://www.uscis.gov/addresschange
- USCIS Form I-765: https://www.uscis.gov/i-765
- USCIS Form AR-11: https://www.uscis.gov/ar-11
- EOIR Case Information: https://www.justice.gov/eoir/eoir-case-information
- EOIR Respondent Access: https://respondentaccess.eoir.justice.gov/
- EOIR Immigration Court: https://www.justice.gov/eoir/learn-about-immigration-court
- CBP I-94: https://i94.cbp.dhs.gov/
- Utah Driver License Division: https://dld.utah.gov/
- Utah written knowledge test: https://dld.utah.gov/written-knowledge-test/
- Stripe subscriptions: https://docs.stripe.com/billing/subscriptions/overview
- Web Push API: https://developer.mozilla.org/en-US/docs/Web/API/Push_API

## Complejidad por modulo

### 1. Boveda de seguridad

Nivel: alto.

Razon: maneja datos sensibles, PDFs oficiales, OCR, clasificacion, cifrado, retencion, auditoria y acceso offline. La PWA no debe guardar documentos sin cifrado en cache comun. El app shell puede usar service worker; los documentos offline deben ir en IndexedDB cifrado con llave derivada del usuario o KMS envelope encryption.

MVP:

- Subida y clasificacion inicial.
- OCR asincrono.
- Carpetas inteligentes por agencia y tipo.
- Marcado de documentos disponibles offline.

Escala:

- Object storage para archivos.
- PostgreSQL solo para metadata.
- Cola de workers para OCR y extraccion.
- Auditoria por cada acceso/descarga.

### 2. Tracker de casos y alertas

Nivel: alto.

USCIS: usar API oficial con credenciales backend. No exponer secretos en frontend.

EOIR: modelar como fuente externa/manual hasta confirmar disponibilidad formal de API para el caso de uso. La app debe permitir guardar fechas desde Notice of Hearing, EOIR-33 y confirmaciones del usuario.

MVP:

- Guardar receipt number USCIS.
- Snapshot de estatus.
- Fechas criticas.
- Alertas push/email/SMS.

Escala:

- Jobs por prioridad.
- Backoff por rate limit.
- No consultar todos los usuarios cada minuto.
- Tabla de snapshots particionable.

### 3. Automatizacion de tramites

Nivel: medio-alto.

AR-11: puede automatizarse como prellenado y guia de envio.

EOIR-33: requiere distinguir corte vs BIA y mantener prueba de servicio.

Change of Venue: requiere criterio legal y no cancela audiencia hasta aprobacion; debe tener revision humana.

I-765: depende de categoria, elegibilidad, tarifas, edicion vigente, direccion de filing y evidencia. Debe ser generador asistido con checklist y revision.

MVP:

- Generador de borradores.
- Validacion de campos.
- Export PDF.
- Evento de firma/envio por usuario.

Escala:

- Versionado de formularios.
- Motor de reglas por formulario y categoria.
- Reglas por estado/corte.
- Validacion contra edicion vigente de USCIS.

### 4. Utility Hub

Nivel: medio.

Utah DMV es buen primer estado. Debe usar contenido oficial del handbook y versionarlo por estado/idioma. Para los 50 estados, cada banco de preguntas debe tener fuente, version y fecha de verificacion.

MVP:

- Utah question set.
- Test de practica.
- Resultados por tema.
- Directorio local verificado.

Escala:

- Tabla `dmv_question_sets` por estado.
- Moderacion/verificacion editorial.
- Importadores por estado.

### 5. Servicios premium

Nivel: alto por operaciones, no por UI.

Debe separar soporte humano, estado de tramite contratado, documentos compartidos, mensajes seguros y auditoria. No mezclar soporte premium con automatizacion generica.

## Escala

### 10,000 usuarios

PostgreSQL + object storage + workers + cache es suficiente.

Requisitos:

- Indices por `user_id`, `due_at`, `agency`, `created_at`.
- API stateless.
- Jobs asincronos.
- Rate limits.
- Backups y retencion.

### 1,000,000 usuarios

Viable, pero requiere arquitectura operativa:

- Particiones para `audit_log`, `case_status_snapshots`, `filing_events`.
- Cola administrada para OCR, alertas y polling.
- Cache distribuido.
- Observabilidad, trazas y alertas.
- Separacion de PII y secretos.
- KMS para cifrado.
- Procesos de privacidad, borrado y exportacion de datos.

## Roadmap recomendado

1. MVP PWA con dashboard, documentos demo, formularios demo y Utah DMV.
2. Backend con auth, usuarios reales, Postgres y subida segura.
3. OCR/document classifier.
4. Alertas push y jobs programados.
5. Stripe Base Membership.
6. USCIS API sandbox y aprobacion produccion.
7. Formularios PDF versionados.
8. Panel interno para revision humana premium.
9. Expansion DMV por estados.
10. Hardening para 10k, luego 100k, luego 1M.
