-- Keep user-facing automation catalog copy in Spanish.

update public.form_definitions
set
  title = case form_code
    when 'ANNUAL_ASYLUM_FEE' then 'Pago de Tarifa Anual de Asilo'
    when 'AR-11' then 'AR-11 Cambio de direccion ante USCIS'
    when 'I-765' then 'I-765 Permiso de trabajo'
    when 'EOIR-33' then 'EOIR-33 Cambio de direccion en corte'
    when 'CHANGE_OF_VENUE' then 'Mocion de cambio de sede'
    else title
  end,
  description = case form_code
    when 'ANNUAL_ASYLUM_FEE' then 'Prepara datos, alertas y comprobante interno para pagar la Tarifa Anual de Asilo en el portal oficial de USCIS.'
    when 'AR-11' then 'Prepara el cambio de direccion de USCIS y la lista de verificacion para enviarlo por el canal oficial.'
    when 'I-765' then 'Prepara el paquete para solicitud, renovacion o reemplazo del permiso de trabajo.'
    when 'EOIR-33' then 'Prepara el aviso de cambio de direccion o informacion de contacto para la corte de inmigracion.'
    when 'CHANGE_OF_VENUE' then 'Prepara el borrador para solicitar cambio de corte, con revision humana obligatoria antes de usarlo.'
    else description
  end
where form_code in ('ANNUAL_ASYLUM_FEE', 'AR-11', 'I-765', 'EOIR-33', 'CHANGE_OF_VENUE');
