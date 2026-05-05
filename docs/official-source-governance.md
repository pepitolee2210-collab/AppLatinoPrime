# Gobierno de fuentes oficiales

## Regla de produccion

Ningun formulario visible debe activarse sin:

- `form_definitions.official_page_source_id`.
- una edicion activa con `verified_at`.
- `instructions_source_id`.
- fuente oficial registrada en `official_sources`.

La vista `production_ready_form_catalog` solo muestra formularios que cumplen esa regla.

## Formularios federales

Los tramites migratorios principales no cambian por estado. AR-11 e I-765 son USCIS; EOIR-33 y cambio de sede son EOIR. El estado del usuario afecta evidencia, domicilio, corte local, recursos y herramientas DMV, pero no convierte esos formularios federales en formularios estatales.

## Estados

Los 50 estados quedan registrados en `state_service_catalog` con portal oficial DMV importado desde USAGov. Eso no significa que todos los simuladores DMV esten listos: cada estado debe tener handbook/manual oficial descargado, versionado y convertido a preguntas antes de marcarlo como `questions_ready`.

## Descarga y auditoria

El script `npm run sources:sync` descarga cada URL oficial de `official_sources`, sube una copia privada al bucket `official-source-snapshots` y guarda hash SHA-256, estado HTTP, tipo de contenido y ruta en `official_source_snapshots`.

Requisitos de entorno:

- `SUPABASE_URL` o `VITE_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

No se debe usar este script desde el frontend ni exponer la llave `service_role`.
