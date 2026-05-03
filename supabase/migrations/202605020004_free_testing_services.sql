-- Temporary free testing mode for premium flows.
-- Stripe can be re-enabled later by restoring price modes and adding Stripe price IDs.

alter table public.premium_services
drop constraint if exists premium_services_price_mode_check;

alter table public.premium_services
add constraint premium_services_price_mode_check
check (price_mode in ('free', 'one_time', 'annual', 'manual_quote'));

update public.premium_services
set price_mode = 'free',
    stripe_price_id = null,
    description = case service_type
      when 'ANNUALITY_PAYMENT' then 'Prueba gratis: administra anualidades, comprobantes y recordatorios sin pago durante la etapa de validacion.'
      when 'EXPERT_REVIEW' then 'Prueba gratis: crea una solicitud de revision experta para validar el flujo operativo.'
      when 'SPECIAL_CASE_TRACKING' then 'Prueba gratis: activa el seguimiento especial para probar el dashboard de casos contratados.'
      else description
    end,
    updated_at = now()
where service_type in ('ANNUALITY_PAYMENT', 'EXPERT_REVIEW', 'SPECIAL_CASE_TRACKING');
