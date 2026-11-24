-- =====================================================================
--  ERP - ESQUEMA DE BASE DE DATOS  (PostgreSQL 14+)
--  Generado desde el DER: 89 tablas, 16 módulos.
--
--  Convenciones
--    * Claves primarias: id BIGINT GENERATED ALWAYS AS IDENTITY.
--    * Todas las tablas llevan created_at / updated_at (updated_at se
--      actualiza solo mediante trigger, ver sección 5).
--    * Los ENUM del DER se implementan como VARCHAR + CHECK (más fáciles
--      de migrar que los tipos ENUM nativos).
--    * Las claves foráneas se agregan al final (sección 2) para evitar
--      problemas de orden de creación. ON DELETE RESTRICT en todas:
--      los documentos no se borran, se anulan (campo estado).
--    * Cada columna FK tiene su índice (PostgreSQL no lo crea solo).
--    * Montos: NUMERIC(12,2)/(14,2). Cotizaciones: NUMERIC(12,4).
--  Las reglas que NO se pueden expresar solo con DDL están al final.
-- =====================================================================

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
--  1. TABLAS
-- =====================================================================

-- ---------------------------------------------------------------------
--  MÓDULO: MAESTROS Y SEGURIDAD
-- ---------------------------------------------------------------------

-- Entidad legal propietaria de los datos. Si el ERP es multiempresa, casi todas las tablas
-- llevan empresa_id.
CREATE TABLE empresa (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  razon_social              VARCHAR(150) NOT NULL,
  ruc                       VARCHAR(20) NOT NULL UNIQUE,
  moneda_base_id            BIGINT NOT NULL, -- FK -> moneda
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Establecimiento físico. Se vincula al código de establecimiento (001) del timbrado.
CREATE TABLE sucursal (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  nombre                    VARCHAR(80) NOT NULL,
  cod_establecimiento       CHAR(3) NOT NULL,
  direccion                 VARCHAR(200) NOT NULL,
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Usuarios del sistema. Los cajeros y vendedores se identifican aquí. Permisos vía rol.
CREATE TABLE usuario (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  rol_id                    BIGINT NOT NULL, -- FK -> rol
  nombre                    VARCHAR(100) NOT NULL,
  email                     VARCHAR(100) NOT NULL UNIQUE,
  password_hash             VARCHAR(255) NOT NULL,
  activo                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Agrupa permisos (cajero, vendedor, admin). Relación con permisos por tabla rol_permiso.
CREATE TABLE rol (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre                    VARCHAR(50) NOT NULL,
  descripcion               VARCHAR(150) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Catálogo de productos y servicios. Cada uno define su tasa de IVA por defecto y su
-- unidad.
CREATE TABLE producto (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo                    VARCHAR(30) NOT NULL UNIQUE,
  descripcion               VARCHAR(200) NOT NULL,
  impuesto_id               BIGINT NOT NULL, -- FK -> impuesto
  categoria_id              BIGINT NOT NULL, -- FK -> categoria
  unidad_id                 BIGINT NOT NULL, -- FK -> unidad_medida
  precio_venta              NUMERIC(12,2) NOT NULL,
  costo_promedio            NUMERIC(12,2) NOT NULL,
  stock_minimo              NUMERIC(10,2) NOT NULL,
  es_servicio               BOOLEAN NOT NULL DEFAULT FALSE,
  activo                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Tasas de IVA: 10 %, 5 % y exenta. Se copia a factura_detalle para conservar el
-- histórico.
CREATE TABLE impuesto (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre                    VARCHAR(30) NOT NULL,
  tasa                      NUMERIC(5,2) NOT NULL,
  base_calculo              NUMERIC(5,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_impuesto_1 CHECK (tasa BETWEEN 0 AND 100)
);

-- Catálogo de monedas (PYG, USD). Las transacciones guardan moneda y cotización del día.
CREATE TABLE moneda (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo                    CHAR(3) NOT NULL UNIQUE,
  nombre                    VARCHAR(40) NOT NULL,
  decimales                 INTEGER NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Autorización de la SET para numerar documentos: vigencia, establecimiento, punto de
-- expedición y rango. El número de factura se valida contra este rango.
CREATE TABLE timbrado (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sucursal_id               BIGINT NOT NULL, -- FK -> sucursal
  numero_timbrado           VARCHAR(10) NOT NULL,
  tipo_documento            VARCHAR(3) NOT NULL CHECK (tipo_documento IN ('FAC', 'NC', 'ND', 'REC', 'REM')),
  punto_expedicion          CHAR(3) NOT NULL,
  nro_desde                 INTEGER NOT NULL,
  nro_hasta                 INTEGER NOT NULL,
  nro_actual                INTEGER NOT NULL,
  vigencia_desde            DATE NOT NULL,
  vigencia_hasta            DATE NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_timbrado_numero_timbrado_tipo_documento_punto_exp UNIQUE (numero_timbrado, tipo_documento, punto_expedicion), -- clave natural
  CONSTRAINT ck_timbrado_1 CHECK (nro_desde <= nro_hasta),
  CONSTRAINT ck_timbrado_2 CHECK (vigencia_desde <= vigencia_hasta)
);

-- Acciones atómicas del sistema (ej. factura.anular, caja.cerrar). Se asignan a roles.
CREATE TABLE permiso (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo                    VARCHAR(60) NOT NULL UNIQUE,
  modulo                    VARCHAR(30) NOT NULL,
  descripcion               VARCHAR(150) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Puente N:M entre roles y permisos.
CREATE TABLE rol_permiso (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rol_id                    BIGINT NOT NULL, -- FK -> rol
  permiso_id                BIGINT NOT NULL, -- FK -> permiso
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_rol_permiso_rol_id_permiso_id UNIQUE (rol_id, permiso_id) -- clave natural
);

-- Bitácora de cambios sensibles (anulaciones, precios, diferencias de caja). Solo
-- inserción: guarda el estado antes y después.
CREATE TABLE audit_log (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  tabla                     VARCHAR(60) NOT NULL,
  registro_id               BIGINT NOT NULL, -- Id del registro modificado en la tabla indicada (sin FK).
  accion                    VARCHAR(3) NOT NULL CHECK (accion IN ('INS', 'UPD', 'DEL')),
  datos_antes               JSONB NULL,
  datos_despues             JSONB NULL,
  ip                        VARCHAR(45) NULL,
  fecha_hora                TIMESTAMP NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Configuración general por empresa (moneda por defecto, decimales, días de mora, etc.) en
-- formato clave-valor.
CREATE TABLE parametro_sistema (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  clave                     VARCHAR(60) NOT NULL,
  valor                     VARCHAR(255) NOT NULL,
  tipo                      VARCHAR(4) NOT NULL CHECK (tipo IN ('TXT', 'NUM', 'BOOL')),
  descripcion               VARCHAR(150) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_parametro_sistema_empresa_id_clave UNIQUE (empresa_id, clave) -- clave natural
);

-- Contadores de numeración de documentos internos (recibos, pedidos, asientos) por empresa
-- o sucursal. Para documentos fiscales se usa timbrado.
CREATE TABLE secuencia_documento (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  sucursal_id               BIGINT NULL, -- FK -> sucursal
  tipo_documento            VARCHAR(20) NOT NULL,
  prefijo                   VARCHAR(10) NOT NULL,
  ultimo_numero             INTEGER NOT NULL,
  longitud                  INTEGER NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: VENTAS Y DEUDAS
-- ---------------------------------------------------------------------

-- Maestro de clientes. Guarda RUC/CI, límite de crédito y condición de pago por defecto.
-- Direcciones y contactos múltiples irían en tablas hijas.
CREATE TABLE cliente (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  ruc_ci                    VARCHAR(20) NOT NULL,
  razon_social              VARCHAR(150) NOT NULL,
  tipo_contribuyente        VARCHAR(3) NOT NULL CHECK (tipo_contribuyente IN ('FIS', 'JUR', 'EXT')),
  telefono                  VARCHAR(30) NOT NULL,
  email                     VARCHAR(100) NOT NULL,
  limite_credito            NUMERIC(12,2) NOT NULL,
  lista_precio_id           BIGINT NULL, -- FK -> lista_precio
  activo                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_cliente_empresa_id_ruc_ci UNIQUE (empresa_id, ruc_ci) -- clave natural
);

-- Cabecera de venta (contado o crédito). Usa un timbrado, desglosa IVA y puede ser
-- electrónica (SIFEN). Al emitirse genera su cuenta_cobrar.
CREATE TABLE factura (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id                BIGINT NOT NULL, -- FK -> cliente
  pedido_venta_id           BIGINT NULL, -- FK -> pedido_venta
  remision_id               BIGINT NULL, -- FK -> remision
  timbrado_id               BIGINT NOT NULL, -- FK -> timbrado
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  numero_factura            VARCHAR(17) NOT NULL, -- Formato 001-001-0000001; debe caer dentro del rango del timbrado.
  condicion                 VARCHAR(4) NOT NULL CHECK (condicion IN ('CONT', 'CRED')),
  fecha_emision             TIMESTAMP NOT NULL,
  cotizacion                NUMERIC(12,4) NOT NULL,
  gravado_10                NUMERIC(12,2) NOT NULL,
  gravado_5                 NUMERIC(12,2) NOT NULL,
  exento                    NUMERIC(12,2) NOT NULL,
  iva_10                    NUMERIC(12,2) NOT NULL,
  iva_5                     NUMERIC(12,2) NOT NULL,
  total                     NUMERIC(12,2) NOT NULL,
  cdc_sifen                 CHAR(44) NULL, -- Código de Control del documento electrónico (44 caracteres).
  sifen_lote_id             BIGINT NULL, -- FK -> sifen_lote
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('EMI', 'APR', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_factura_timbrado_id_numero_factura UNIQUE (timbrado_id, numero_factura) -- clave natural
);

-- Ítems de la factura. Copia precio y tasa de IVA vigentes al momento de vender.
CREATE TABLE factura_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_id                BIGINT NOT NULL, -- FK -> factura
  pedido_venta_detalle_id   BIGINT NULL, -- FK -> pedido_venta_detalle
  producto_id               BIGINT NOT NULL, -- FK -> producto
  impuesto_id               BIGINT NOT NULL, -- FK -> impuesto
  cantidad                  NUMERIC(10,2) NOT NULL,
  precio_unitario           NUMERIC(12,2) NOT NULL,
  descuento                 NUMERIC(12,2) NOT NULL,
  subtotal                  NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_factura_detalle_1 CHECK (cantidad > 0)
);

-- Devoluciones, descuentos posteriores y anulaciones parciales. Reduce el saldo de la
-- cuenta_cobrar vinculada. Requiere motivo.
CREATE TABLE nota_credito (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_id                BIGINT NOT NULL, -- FK -> factura
  timbrado_id               BIGINT NOT NULL, -- FK -> timbrado
  numero                    VARCHAR(17) NOT NULL,
  fecha                     TIMESTAMP NOT NULL,
  motivo                    VARCHAR(150) NOT NULL,
  total                     NUMERIC(12,2) NOT NULL,
  cdc_sifen                 CHAR(44) NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('EMI', 'APR', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_nota_credito_timbrado_id_numero UNIQUE (timbrado_id, numero) -- clave natural
);

-- Obligación generada por cada factura (1:1). saldo_pendiente es derivable de plan_pago:
-- mantener con trigger o calcular.
CREATE TABLE cuenta_cobrar (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_id                BIGINT NOT NULL UNIQUE, -- FK -> factura
  monto_total               NUMERIC(12,2) NOT NULL,
  saldo_pendiente           NUMERIC(12,2) NOT NULL, -- Derivado: suma de plan_pago.saldo_cuota. Mantener por lógica de aplicación o trigger.
  estado                    VARCHAR(4) NOT NULL CHECK (estado IN ('PEND', 'PAG')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_cuenta_cobrar_1 CHECK (saldo_pendiente >= 0 AND saldo_pendiente <= monto_total)
);

-- Cronograma de cuotas. Contado: 1 cuota inmediata. Crédito: N cuotas. Incluye mora e
-- intereses.
CREATE TABLE plan_pago (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_cobrar_id          BIGINT NOT NULL, -- FK -> cuenta_cobrar
  numero_cuota              INTEGER NOT NULL,
  fecha_vencimiento         DATE NOT NULL,
  monto_cuota               NUMERIC(12,2) NOT NULL,
  saldo_cuota               NUMERIC(12,2) NOT NULL,
  tasa_mora                 NUMERIC(5,2) NOT NULL,
  interes_acumulado         NUMERIC(12,2) NOT NULL, -- Interés por mora acumulado a la fecha.
  estado                    VARCHAR(4) NOT NULL CHECK (estado IN ('PEND', 'PAG')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_plan_pago_1 CHECK (saldo_cuota >= 0)
);

-- Direcciones múltiples del cliente (fiscal, entrega, cobranza). Solo una puede ser
-- principal.
CREATE TABLE cliente_direccion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id                BIGINT NOT NULL, -- FK -> cliente
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('FIS', 'ENT', 'COB')),
  direccion                 VARCHAR(200) NOT NULL,
  ciudad                    VARCHAR(60) NOT NULL,
  telefono                  VARCHAR(30) NULL,
  principal                 BOOLEAN NOT NULL DEFAULT FALSE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: COBROS Y BANCOS
-- ---------------------------------------------------------------------

-- Recibo de pago. caja_sesion_id es NULL para transferencias o cobros online que no pasan
-- por caja. Puede generar saldo a favor (anticipo).
CREATE TABLE cobro (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id                BIGINT NOT NULL, -- FK -> cliente
  caja_sesion_id            BIGINT NULL, -- FK -> caja_sesion | NULL en transferencias o cobros online que no pasan por caja.
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  numero_recibo             VARCHAR(20) NOT NULL,
  fecha_cobro               TIMESTAMP NOT NULL,
  cotizacion                NUMERIC(12,4) NOT NULL,
  monto_total               NUMERIC(12,2) NOT NULL,
  saldo_a_favor             NUMERIC(12,2) NOT NULL, -- Anticipo: parte del cobro no aplicada a ninguna cuota.
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('REG', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Puente N:M entre cobro y cuotas. Regla: SUM(monto_aplicado) ≤ SUM(cobro_detalle.monto)
-- del cobro; la diferencia es anticipo.
CREATE TABLE cobro_aplicacion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cobro_id                  BIGINT NOT NULL, -- FK -> cobro
  plan_pago_id              BIGINT NOT NULL, -- FK -> plan_pago
  monto_aplicado            NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_cobro_aplicacion_cobro_id_plan_pago_id UNIQUE (cobro_id, plan_pago_id), -- clave natural
  CONSTRAINT ck_cobro_aplicacion_1 CHECK (monto_aplicado > 0)
);

-- Formas de pago del recibo. Si forma_pago.afecta_caja = true, genera un caja_movimiento.
CREATE TABLE cobro_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cobro_id                  BIGINT NOT NULL, -- FK -> cobro
  forma_pago_id             BIGINT NOT NULL, -- FK -> forma_pago
  cuenta_bancaria_id        BIGINT NULL, -- FK -> cuenta_bancaria
  cheque_id                 BIGINT NULL, -- FK -> cheque
  monto                     NUMERIC(12,2) NOT NULL,
  referencia                VARCHAR(50) NULL,
  nro_voucher               VARCHAR(30) NULL,
  fecha_acreditacion        DATE NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_cobro_detalle_1 CHECK (monto > 0)
);

-- Medios de pago (efectivo, tarjeta, cheque, transferencia). afecta_caja distingue
-- efectivo físico de dinero bancario.
CREATE TABLE forma_pago (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre                    VARCHAR(60) NOT NULL,
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('EFE', 'TAR', 'CHE', 'TRA')),
  afecta_caja               BOOLEAN NOT NULL, -- TRUE = efectivo físico (genera caja_movimiento); FALSE = banco/tarjeta.
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Catálogo de entidades bancarias (solo el banco, no la cuenta).
CREATE TABLE banco (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre                    VARCHAR(100) NOT NULL,
  codigo                    VARCHAR(10) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cuenta de la empresa en un banco. Base para tesorería y conciliación bancaria.
CREATE TABLE cuenta_bancaria (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  banco_id                  BIGINT NOT NULL, -- FK -> banco
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  numero_cuenta             VARCHAR(40) NOT NULL,
  titular                   VARCHAR(100) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cartera de cheques: recibido, depositado, cobrado o rechazado. Soporta fecha diferida.
CREATE TABLE cheque (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  banco_id                  BIGINT NOT NULL, -- FK -> banco
  numero                    VARCHAR(20) NOT NULL,
  librador                  VARCHAR(100) NOT NULL,
  monto                     NUMERIC(12,2) NOT NULL,
  fecha_emision             DATE NOT NULL,
  fecha_cobro               DATE NOT NULL,
  estado                    VARCHAR(4) NOT NULL CHECK (estado IN ('CART', 'DEP', 'COB', 'RECH')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: CAJA Y ARQUEO
-- ---------------------------------------------------------------------

-- Puestos de caja por sucursal.
CREATE TABLE caja (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sucursal_id               BIGINT NOT NULL, -- FK -> sucursal
  nombre                    VARCHAR(60) NOT NULL,
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Turno de caja con arqueo ciego: compara el cierre del sistema con lo declarado por el
-- cajero. Las diferencias requieren motivo y autorización.
CREATE TABLE caja_sesion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  caja_id                   BIGINT NOT NULL, -- FK -> caja
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  autorizado_por            BIGINT NULL, -- FK -> usuario
  fecha_apertura            TIMESTAMP NOT NULL,
  fecha_cierre              TIMESTAMP NULL,
  monto_apertura            NUMERIC(12,2) NOT NULL,
  monto_cierre_sistema      NUMERIC(12,2) NOT NULL,
  monto_cierre_declarado    NUMERIC(12,2) NOT NULL,
  diferencia                NUMERIC(12,2) NOT NULL, -- monto_cierre_declarado - monto_cierre_sistema (arqueo ciego).
  motivo_diferencia         VARCHAR(200) NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('ABI', 'CER')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_caja_sesion_1 CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura)
);

-- Entradas y salidas de efectivo. cobro_detalle_id es NULL en gastos, retiros, depósitos a
-- banco y traspasos entre cajas.
CREATE TABLE caja_movimiento (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  caja_sesion_id            BIGINT NOT NULL, -- FK -> caja_sesion
  cobro_detalle_id          BIGINT NULL, -- FK -> cobro_detalle
  cuenta_bancaria_id        BIGINT NULL, -- FK -> cuenta_bancaria
  pago_proveedor_id         BIGINT NULL, -- FK -> pago_proveedor
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('ING', 'EGR', 'RET', 'DEP', 'TRA')),
  concepto                  VARCHAR(150) NOT NULL,
  monto                     NUMERIC(12,2) NOT NULL,
  fecha_hora                TIMESTAMP NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_caja_movimiento_1 CHECK (cobro_detalle_id IS NULL OR pago_proveedor_id IS NULL)
);

-- Conteo por denominación (billetes y monedas) al cerrar el turno.
CREATE TABLE caja_arqueo_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  caja_sesion_id            BIGINT NOT NULL, -- FK -> caja_sesion
  denominacion              INTEGER NOT NULL,
  cantidad                  INTEGER NOT NULL,
  subtotal                  NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: INVENTARIO Y STOCK
-- ---------------------------------------------------------------------

-- Almacén físico de una sucursal. El stock siempre se lleva por producto y depósito.
CREATE TABLE deposito (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sucursal_id               BIGINT NOT NULL, -- FK -> sucursal
  nombre                    VARCHAR(80) NOT NULL,
  es_principal              BOOLEAN NOT NULL DEFAULT FALSE,
  activo                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Clasificación jerárquica de productos (padre_id NULL = categoría raíz).
CREATE TABLE categoria (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  padre_id                  BIGINT NULL, -- FK -> categoria
  nombre                    VARCHAR(80) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Unidades de medida (UN, KG, LT, CJ) usadas en producto y documentos.
CREATE TABLE unidad_medida (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo                    VARCHAR(10) NOT NULL UNIQUE,
  nombre                    VARCHAR(40) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Existencia actual por producto y depósito (único por par). Es un saldo derivado: solo
-- debe cambiar a través de movimiento_stock.
CREATE TABLE stock (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  producto_id               BIGINT NOT NULL, -- FK -> producto
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  cantidad                  NUMERIC(12,2) NOT NULL, -- Saldo derivado. Solo debe cambiar vía movimiento_stock.
  cantidad_reservada        NUMERIC(12,2) NOT NULL, -- Reservado por pedido_venta confirmado; se libera al emitir la remisión.
  ultimo_movimiento         TIMESTAMP NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_stock_producto_id_deposito_id UNIQUE (producto_id, deposito_id), -- clave natural
  CONSTRAINT ck_stock_1 CHECK (cantidad >= 0),
  CONSTRAINT ck_stock_2 CHECK (cantidad_reservada >= 0)
);

-- Kardex. Toda entrada o salida deja una fila: compras (recepcion_detalle), ventas
-- (remision_detalle, o factura_detalle si no hubo remisión) y ajustes. Guarda el costo
-- para el costo promedio. Es solo de inserción; no se edita.
CREATE TABLE movimiento_stock (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  producto_id               BIGINT NOT NULL, -- FK -> producto
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  deposito_destino_id       BIGINT NULL, -- FK -> deposito
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('ENT', 'SAL', 'AJU', 'TRA')),
  cantidad                  NUMERIC(12,2) NOT NULL,
  costo_unitario            NUMERIC(12,2) NOT NULL, -- Base del costo promedio ponderado.
  lote_id                   BIGINT NULL, -- FK -> lote
  recepcion_detalle_id      BIGINT NULL, -- FK -> recepcion_detalle
  factura_detalle_id        BIGINT NULL, -- FK -> factura_detalle
  remision_detalle_id       BIGINT NULL, -- FK -> remision_detalle
  transferencia_detalle_id  BIGINT NULL, -- FK -> transferencia_detalle
  ajuste_id                 BIGINT NULL, -- FK -> ajuste_inventario
  fecha_hora                TIMESTAMP NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_movimiento_stock_1 CHECK (cantidad > 0),
  CONSTRAINT ck_movimiento_stock_2 CHECK (tipo <> 'TRA' OR deposito_destino_id IS NOT NULL)
);

-- Corrección por toma física: compara lo contado con el stock del sistema. Al aplicarse
-- genera un movimiento_stock tipo AJU. Requiere motivo y usuario.
CREATE TABLE ajuste_inventario (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  producto_id               BIGINT NOT NULL, -- FK -> producto
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  cantidad_sistema          NUMERIC(12,2) NOT NULL,
  cantidad_contada          NUMERIC(12,2) NOT NULL,
  diferencia                NUMERIC(12,2) NOT NULL,
  motivo                    VARCHAR(150) NOT NULL,
  fecha                     TIMESTAMP NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('BOR', 'APL')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Traslado de mercadería entre depósitos como documento. Al enviarse sale del origen; al
-- recibirse entra al destino (dos movimientos de stock).
CREATE TABLE transferencia_deposito (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  deposito_origen_id        BIGINT NOT NULL, -- FK -> deposito
  deposito_destino_id       BIGINT NOT NULL, -- FK -> deposito
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  fecha                     TIMESTAMP NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('BOR', 'TRA', 'REC', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Productos (y lote, si aplica) trasladados. Cada fila genera movimientos de stock.
CREATE TABLE transferencia_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transferencia_id          BIGINT NOT NULL, -- FK -> transferencia_deposito
  producto_id               BIGINT NOT NULL, -- FK -> producto
  lote_id                   BIGINT NULL, -- FK -> lote
  cantidad                  NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: COMPRAS Y CUENTAS A PAGAR
-- ---------------------------------------------------------------------

-- Maestro de proveedores con RUC y plazo de pago por defecto.
CREATE TABLE proveedor (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  ruc                       VARCHAR(20) NOT NULL,
  razon_social              VARCHAR(150) NOT NULL,
  telefono                  VARCHAR(30) NOT NULL,
  email                     VARCHAR(100) NOT NULL,
  plazo_pago_dias           INTEGER NOT NULL,
  activo                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_proveedor_empresa_id_ruc UNIQUE (empresa_id, ruc) -- clave natural
);

-- Pedido al proveedor. No mueve stock ni genera deuda; solo es un compromiso.
CREATE TABLE orden_compra (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  proveedor_id              BIGINT NOT NULL, -- FK -> proveedor
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  numero                    VARCHAR(20) NOT NULL,
  fecha                     DATE NOT NULL,
  total                     NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('BOR', 'ENV', 'PAR', 'CER')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Ítems pedidos. cantidad_recibida se actualiza con cada recepción, así se detectan
-- entregas parciales.
CREATE TABLE orden_compra_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  orden_compra_id           BIGINT NOT NULL, -- FK -> orden_compra
  producto_id               BIGINT NOT NULL, -- FK -> producto
  cantidad                  NUMERIC(10,2) NOT NULL,
  precio_unitario           NUMERIC(12,2) NOT NULL,
  cantidad_recibida         NUMERIC(10,2) NOT NULL, -- Se actualiza con cada recepción; permite entregas parciales.
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Ingreso físico de mercadería (nota de remisión del proveedor). orden_compra_id es NULL
-- si se compra sin orden previa. Al registrarse, suma stock.
CREATE TABLE recepcion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  orden_compra_id           BIGINT NULL, -- FK -> orden_compra
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  nro_remision              VARCHAR(20) NOT NULL,
  fecha                     TIMESTAMP NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('REG', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cantidad y costo realmente recibidos. Cada fila genera un movimiento_stock de entrada.
CREATE TABLE recepcion_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  recepcion_id              BIGINT NOT NULL, -- FK -> recepcion
  producto_id               BIGINT NOT NULL, -- FK -> producto
  cantidad                  NUMERIC(10,2) NOT NULL,
  costo_unitario            NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Factura del proveedor, con su timbrado y desglose de IVA (base del libro IVA compras).
-- Al registrarse genera su cuenta_pagar.
CREATE TABLE factura_compra (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  proveedor_id              BIGINT NOT NULL, -- FK -> proveedor
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  recepcion_id              BIGINT NULL, -- FK -> recepcion
  timbrado_proveedor        VARCHAR(10) NOT NULL,
  numero_factura            VARCHAR(17) NOT NULL,
  condicion                 VARCHAR(4) NOT NULL CHECK (condicion IN ('CONT', 'CRED')),
  fecha_emision             DATE NOT NULL,
  cotizacion                NUMERIC(12,4) NOT NULL,
  gravado_10                NUMERIC(12,2) NOT NULL,
  gravado_5                 NUMERIC(12,2) NOT NULL,
  exento                    NUMERIC(12,2) NOT NULL,
  iva_10                    NUMERIC(12,2) NOT NULL,
  iva_5                     NUMERIC(12,2) NOT NULL,
  total                     NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('REG', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_factura_compra_proveedor_id_timbrado_proveedor_numero_f UNIQUE (proveedor_id, timbrado_proveedor, numero_factura) -- clave natural
);

-- Ítems facturados por el proveedor, con su tasa de IVA.
CREATE TABLE factura_compra_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_compra_id         BIGINT NOT NULL, -- FK -> factura_compra
  producto_id               BIGINT NOT NULL, -- FK -> producto
  impuesto_id               BIGINT NOT NULL, -- FK -> impuesto
  cantidad                  NUMERIC(10,2) NOT NULL,
  costo_unitario            NUMERIC(12,2) NOT NULL,
  subtotal                  NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Deuda con el proveedor (1:1 con la factura de compra). Espejo de cuenta_cobrar.
CREATE TABLE cuenta_pagar (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_compra_id         BIGINT NOT NULL UNIQUE, -- FK -> factura_compra
  monto_total               NUMERIC(12,2) NOT NULL,
  saldo_pendiente           NUMERIC(12,2) NOT NULL, -- Derivado de los pagos aplicados.
  fecha_vencimiento         DATE NOT NULL,
  estado                    VARCHAR(4) NOT NULL CHECK (estado IN ('PEND', 'PAG')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_cuenta_pagar_1 CHECK (saldo_pendiente >= 0 AND saldo_pendiente <= monto_total)
);

-- Pago de una deuda. Si es en efectivo sale de caja (caja_movimiento); si es
-- transferencia, de una cuenta_bancaria. Para pagos agrupados haría falta una tabla puente
-- como cobro_aplicacion.
CREATE TABLE pago_proveedor (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_pagar_id           BIGINT NOT NULL, -- FK -> cuenta_pagar
  forma_pago_id             BIGINT NOT NULL, -- FK -> forma_pago
  cuenta_bancaria_id        BIGINT NULL, -- FK -> cuenta_bancaria
  numero_comprobante        VARCHAR(20) NOT NULL,
  fecha_pago                TIMESTAMP NOT NULL,
  monto                     NUMERIC(12,2) NOT NULL,
  referencia                VARCHAR(50) NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Devolución o descuento obtenido del proveedor. Reduce el saldo de la cuenta_pagar de la
-- factura de compra y, si hay devolución física, genera salida de stock.
CREATE TABLE nota_credito_compra (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_compra_id         BIGINT NOT NULL, -- FK -> factura_compra
  timbrado_proveedor        VARCHAR(10) NOT NULL,
  numero                    VARCHAR(17) NOT NULL,
  fecha                     DATE NOT NULL,
  motivo                    VARCHAR(150) NOT NULL,
  total                     NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('REG', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Pago adelantado a un proveedor, aún no aplicado a facturas. Es el espejo de
-- cobro.saldo_a_favor.
CREATE TABLE anticipo_proveedor (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  proveedor_id              BIGINT NOT NULL, -- FK -> proveedor
  pago_proveedor_id         BIGINT NULL, -- FK -> pago_proveedor
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  fecha                     DATE NOT NULL,
  monto                     NUMERIC(12,2) NOT NULL,
  saldo                     NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('PEN', 'APL')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cheques que la empresa gira a proveedores (los recibidos están en cheque). Soporta fecha
-- de pago diferida.
CREATE TABLE cheque_emitido (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_bancaria_id        BIGINT NOT NULL, -- FK -> cuenta_bancaria
  pago_proveedor_id         BIGINT NULL, -- FK -> pago_proveedor
  numero                    VARCHAR(20) NOT NULL,
  beneficiario              VARCHAR(100) NOT NULL,
  monto                     NUMERIC(12,2) NOT NULL,
  fecha_emision             DATE NOT NULL,
  fecha_pago                DATE NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('EMI', 'ENT', 'COB', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: PREVENTA Y DESPACHO
-- ---------------------------------------------------------------------

-- Oferta al cliente con validez limitada. No reserva stock ni genera deuda. Si se acepta,
-- se convierte en pedido_venta.
CREATE TABLE cotizacion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id                BIGINT NOT NULL, -- FK -> cliente
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  numero                    VARCHAR(20) NOT NULL,
  fecha                     DATE NOT NULL,
  validez_hasta             DATE NOT NULL,
  total                     NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('BOR', 'ENV', 'ACE', 'VEN', 'REC')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Ítems cotizados con precio y descuento propuestos.
CREATE TABLE cotizacion_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cotizacion_id             BIGINT NOT NULL, -- FK -> cotizacion
  producto_id               BIGINT NOT NULL, -- FK -> producto
  impuesto_id               BIGINT NOT NULL, -- FK -> impuesto
  cantidad                  NUMERIC(10,2) NOT NULL,
  precio_unitario           NUMERIC(12,2) NOT NULL,
  descuento                 NUMERIC(12,2) NOT NULL,
  subtotal                  NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Compromiso firme con el cliente. Al confirmarse reserva stock (stock.cantidad_reservada)
-- en el depósito indicado. cotizacion_id es NULL si el pedido nació directo.
CREATE TABLE pedido_venta (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id                BIGINT NOT NULL, -- FK -> cliente
  cotizacion_id             BIGINT NULL, -- FK -> cotizacion
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  numero                    VARCHAR(20) NOT NULL,
  fecha                     DATE NOT NULL,
  fecha_entrega             DATE NULL,
  condicion                 VARCHAR(4) NOT NULL CHECK (condicion IN ('CONT', 'CRED')),
  total                     NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('PEN', 'PAR', 'COM', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Ítems del pedido. Lleva cantidad entregada y facturada por separado, así soporta
-- entregas y facturaciones parciales.
CREATE TABLE pedido_venta_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pedido_venta_id           BIGINT NOT NULL, -- FK -> pedido_venta
  producto_id               BIGINT NOT NULL, -- FK -> producto
  cantidad                  NUMERIC(10,2) NOT NULL,
  cantidad_entregada        NUMERIC(10,2) NOT NULL, -- Se actualiza con cada remisión; permite entregas parciales.
  cantidad_facturada        NUMERIC(10,2) NOT NULL,
  precio_unitario           NUMERIC(12,2) NOT NULL,
  descuento                 NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Nota de remisión: respalda el traslado de mercadería (usa timbrado tipo REM). Al
-- emitirse descuenta stock y libera la reserva. pedido_venta_id es NULL si no hubo pedido.
CREATE TABLE remision (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pedido_venta_id           BIGINT NULL, -- FK -> pedido_venta
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  timbrado_id               BIGINT NOT NULL, -- FK -> timbrado
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  numero                    VARCHAR(17) NOT NULL,
  fecha                     TIMESTAMP NOT NULL,
  motivo_traslado           VARCHAR(80) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('EMI', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cantidades despachadas. Cada fila genera un movimiento_stock de salida. Si la factura
-- referencia la remisión, su detalle NO vuelve a descontar stock.
CREATE TABLE remision_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  remision_id               BIGINT NOT NULL, -- FK -> remision
  pedido_venta_detalle_id   BIGINT NULL, -- FK -> pedido_venta_detalle
  producto_id               BIGINT NOT NULL, -- FK -> producto
  cantidad                  NUMERIC(10,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: CONTABILIDAD
-- ---------------------------------------------------------------------

-- Período anual de la empresa. Un asiento solo se puede registrar en un ejercicio abierto;
-- al cerrarse queda bloqueado.
CREATE TABLE ejercicio_contable (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  anio                      INTEGER NOT NULL,
  fecha_inicio              DATE NOT NULL,
  fecha_fin                 DATE NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('ABI', 'CER')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_ejercicio_contable_empresa_id_anio UNIQUE (empresa_id, anio) -- clave natural
);

-- Plan de cuentas jerárquico (padre_id NULL = cuenta raíz). Solo las cuentas con
-- acepta_movimiento reciben asientos.
CREATE TABLE plan_cuenta (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  padre_id                  BIGINT NULL, -- FK -> plan_cuenta
  codigo                    VARCHAR(20) NOT NULL,
  nombre                    VARCHAR(120) NOT NULL,
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('ACT', 'PAS', 'PAT', 'ING', 'EGR')),
  acepta_movimiento         BOOLEAN NOT NULL,
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_plan_cuenta_empresa_id_codigo UNIQUE (empresa_id, codigo) -- clave natural
);

-- Reglas que traducen eventos del ERP en cuentas (ej. VENTA_CREDITO: debe Clientes, haber
-- Ventas e IVA). Permite generar asientos automáticos.
CREATE TABLE configuracion_contable (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  evento                    VARCHAR(40) NOT NULL,
  concepto                  VARCHAR(40) NOT NULL,
  cuenta_id                 BIGINT NOT NULL, -- FK -> plan_cuenta
  lado                      VARCHAR(3) NOT NULL CHECK (lado IN ('DEB', 'HAB')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cabecera del asiento. origen_tipo y origen_id apuntan al documento que lo generó
-- (factura, cobro, factura_compra, etc.); es una referencia polimórfica, sin FK. Regla:
-- total_debe = total_haber.
CREATE TABLE asiento (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  ejercicio_id              BIGINT NOT NULL, -- FK -> ejercicio_contable
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  numero                    INTEGER NOT NULL,
  fecha                     DATE NOT NULL,
  glosa                     VARCHAR(200) NOT NULL,
  origen_tipo               VARCHAR(30) NULL, -- Referencia polimórfica al documento origen (sin FK): FACTURA, COBRO, FACTURA_COMPRA, etc.
  origen_id                 BIGINT NULL, -- Id del documento origen según origen_tipo (sin FK).
  total_debe                NUMERIC(14,2) NOT NULL,
  total_haber               NUMERIC(14,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('BOR', 'CON', 'ANU')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_asiento_empresa_id_ejercicio_id_numero UNIQUE (empresa_id, ejercicio_id, numero), -- clave natural
  CONSTRAINT ck_asiento_1 CHECK (total_debe = total_haber)
);

-- Líneas del asiento. Cada línea tiene debe o haber, nunca ambos.
CREATE TABLE asiento_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asiento_id                BIGINT NOT NULL, -- FK -> asiento
  cuenta_id                 BIGINT NOT NULL, -- FK -> plan_cuenta
  debe                      NUMERIC(14,2) NOT NULL,
  haber                     NUMERIC(14,2) NOT NULL,
  glosa                     VARCHAR(150) NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_asiento_detalle_1 CHECK (debe >= 0 AND haber >= 0 AND (debe = 0 OR haber = 0))
);

-- ---------------------------------------------------------------------
--  MÓDULO: COMISIONES
-- ---------------------------------------------------------------------

-- Define el porcentaje de comisión por vendedor y/o categoría. base indica si se devenga
-- al facturar o al cobrar.
CREATE TABLE comision_regla (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  usuario_id                BIGINT NULL, -- FK -> usuario
  categoria_id              BIGINT NULL, -- FK -> categoria
  porcentaje                NUMERIC(5,2) NOT NULL,
  base                      VARCHAR(3) NOT NULL CHECK (base IN ('FAC', 'COB')),
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_comision_regla_1 CHECK (porcentaje BETWEEN 0 AND 100)
);

-- Comisión devengada por una venta. Si la base es cobro, se genera al aplicar el cobro
-- (cobro_id). Se liquida en lotes: PEN → LIQ → PAG.
CREATE TABLE comision (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  factura_id                BIGINT NOT NULL, -- FK -> factura
  regla_id                  BIGINT NOT NULL, -- FK -> comision_regla
  cobro_id                  BIGINT NULL, -- FK -> cobro
  monto_base                NUMERIC(12,2) NOT NULL,
  porcentaje                NUMERIC(5,2) NOT NULL,
  monto_comision            NUMERIC(12,2) NOT NULL,
  fecha                     DATE NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('PEN', 'LIQ', 'PAG')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: CONCILIACIÓN BANCARIA
-- ---------------------------------------------------------------------

-- Extracto importado del banco para un período y una cuenta bancaria.
CREATE TABLE extracto_bancario (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_bancaria_id        BIGINT NOT NULL, -- FK -> cuenta_bancaria
  fecha_desde               DATE NOT NULL,
  fecha_hasta               DATE NOT NULL,
  saldo_inicial             NUMERIC(14,2) NOT NULL,
  saldo_final               NUMERIC(14,2) NOT NULL,
  archivo                   VARCHAR(150) NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cada movimiento del extracto. Queda PEN hasta que se concilia con un cobro o pago del
-- ERP.
CREATE TABLE extracto_linea (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  extracto_id               BIGINT NOT NULL, -- FK -> extracto_bancario
  fecha                     DATE NOT NULL,
  descripcion               VARCHAR(200) NOT NULL,
  referencia                VARCHAR(50) NULL,
  monto                     NUMERIC(14,2) NOT NULL,
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('CRE', 'DEB')),
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('PEN', 'CON')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cruce entre una línea del extracto y un cobro_detalle (crédito) o un pago_proveedor
-- (débito). Registra quién concilió y la diferencia, si existe.
CREATE TABLE conciliacion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  extracto_linea_id         BIGINT NOT NULL UNIQUE, -- FK -> extracto_linea
  cobro_detalle_id          BIGINT NULL, -- FK -> cobro_detalle
  pago_proveedor_id         BIGINT NULL, -- FK -> pago_proveedor
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  fecha                     TIMESTAMP NOT NULL,
  diferencia                NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_conciliacion_1 CHECK ((cobro_detalle_id IS NOT NULL)::int + (pago_proveedor_id IS NOT NULL)::int = 1)
);

-- ---------------------------------------------------------------------
--  MÓDULO: EVENTOS SIFEN
-- ---------------------------------------------------------------------

-- Lote de documentos electrónicos enviados a SIFEN. Guarda la respuesta de la SET.
CREATE TABLE sifen_lote (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  numero_lote               VARCHAR(20) NOT NULL,
  fecha_envio               TIMESTAMP NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('ENV', 'PRO', 'ERR')),
  respuesta                 TEXT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Eventos sobre un documento ya aprobado: cancelación, inutilización de numeración,
-- conformidad o disconformidad. Apunta a una factura o a una nota de crédito.
CREATE TABLE sifen_evento (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  factura_id                BIGINT NULL, -- FK -> factura
  nota_credito_id           BIGINT NULL, -- FK -> nota_credito
  lote_id                   BIGINT NULL, -- FK -> sifen_lote
  usuario_id                BIGINT NOT NULL, -- FK -> usuario
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('CAN', 'INU', 'CON', 'DIS')),
  cdc                       CHAR(44) NOT NULL,
  motivo                    VARCHAR(200) NOT NULL,
  xml_evento                TEXT NOT NULL,
  estado_sifen              VARCHAR(4) NOT NULL CHECK (estado_sifen IN ('PEN', 'APR', 'RECH')),
  codigo_respuesta          VARCHAR(10) NULL,
  fecha                     TIMESTAMP NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_sifen_evento_1 CHECK (factura_id IS NOT NULL OR nota_credito_id IS NOT NULL)
);

-- ---------------------------------------------------------------------
--  MÓDULO: LISTAS DE PRECIOS
-- ---------------------------------------------------------------------

-- Lista de precios por moneda y vigencia (mayorista, minorista, etc.). Se asigna al
-- cliente; si no tiene, aplica producto.precio_venta.
CREATE TABLE lista_precio (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  moneda_id                 BIGINT NOT NULL, -- FK -> moneda
  nombre                    VARCHAR(60) NOT NULL,
  vigencia_desde            DATE NOT NULL,
  vigencia_hasta            DATE NULL,
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Precio de un producto en una lista, con cantidad mínima para precios escalonados.
CREATE TABLE lista_precio_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lista_precio_id           BIGINT NOT NULL, -- FK -> lista_precio
  producto_id               BIGINT NOT NULL, -- FK -> producto
  precio                    NUMERIC(12,2) NOT NULL,
  cantidad_minima           NUMERIC(10,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_lista_precio_detalle_lista_precio_id_producto_id_cantidad_min UNIQUE (lista_precio_id, producto_id, cantidad_minima) -- clave natural
);

-- Descuento temporal sobre un producto o una categoría (porcentaje, monto fijo o 2x1). Se
-- aplica al armar cotización, pedido o factura.
CREATE TABLE promocion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  producto_id               BIGINT NULL, -- FK -> producto
  categoria_id              BIGINT NULL, -- FK -> categoria
  nombre                    VARCHAR(80) NOT NULL,
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('PCT', 'MON', 'DXU')),
  valor                     NUMERIC(12,2) NOT NULL,
  vigencia_desde            DATE NOT NULL,
  vigencia_hasta            DATE NOT NULL,
  activa                    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: LOTES Y SERIES
-- ---------------------------------------------------------------------

-- Lote de un producto con fecha de vencimiento. Permite trazabilidad y salida por FEFO
-- (primero vence, primero sale).
CREATE TABLE lote (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  producto_id               BIGINT NOT NULL, -- FK -> producto
  proveedor_id              BIGINT NULL, -- FK -> proveedor
  codigo_lote               VARCHAR(30) NOT NULL,
  fecha_fabricacion         DATE NULL,
  fecha_vencimiento         DATE NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Existencia por lote y depósito. Su suma debe coincidir con stock.cantidad del producto
-- cuando este usa lotes.
CREATE TABLE stock_lote (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lote_id                   BIGINT NOT NULL, -- FK -> lote
  deposito_id               BIGINT NOT NULL, -- FK -> deposito
  cantidad                  NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_stock_lote_lote_id_deposito_id UNIQUE (lote_id, deposito_id) -- clave natural
);

-- Número de serie individual (equipos, garantías). Sigue su ciclo: en stock, vendido o
-- devuelto.
CREATE TABLE serie_producto (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  producto_id               BIGINT NOT NULL, -- FK -> producto
  lote_id                   BIGINT NULL, -- FK -> lote
  factura_detalle_id        BIGINT NULL, -- FK -> factura_detalle
  numero_serie              VARCHAR(50) NOT NULL UNIQUE,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('STK', 'VEN', 'DEV')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: ACTIVOS FIJOS
-- ---------------------------------------------------------------------

-- Bien de uso de la empresa. Se origina normalmente en una factura de compra. La cuenta
-- contable define dónde se registra su costo.
CREATE TABLE activo_fijo (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  sucursal_id               BIGINT NOT NULL, -- FK -> sucursal
  factura_compra_id         BIGINT NULL, -- FK -> factura_compra
  cuenta_id                 BIGINT NOT NULL, -- FK -> plan_cuenta
  codigo                    VARCHAR(20) NOT NULL UNIQUE,
  descripcion               VARCHAR(150) NOT NULL,
  fecha_adquisicion         DATE NOT NULL,
  valor_adquisicion         NUMERIC(14,2) NOT NULL,
  vida_util_meses           INTEGER NOT NULL,
  valor_residual            NUMERIC(14,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('ACT', 'BAJ', 'VEN')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Cuota mensual de depreciación. Genera su asiento contable y acumula el valor depreciado.
CREATE TABLE depreciacion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  activo_fijo_id            BIGINT NOT NULL, -- FK -> activo_fijo
  asiento_id                BIGINT NULL, -- FK -> asiento
  periodo                   DATE NOT NULL,
  monto                     NUMERIC(14,2) NOT NULL,
  acumulada                 NUMERIC(14,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_depreciacion_activo_fijo_id_periodo UNIQUE (activo_fijo_id, periodo) -- clave natural
);

-- Baja o venta del activo. Registra valor en libros y, si se vendió, el precio obtenido.
CREATE TABLE activo_baja (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  activo_fijo_id            BIGINT NOT NULL UNIQUE, -- FK -> activo_fijo
  fecha                     DATE NOT NULL,
  motivo                    VARCHAR(150) NOT NULL,
  valor_libro               NUMERIC(14,2) NOT NULL,
  valor_venta               NUMERIC(14,2) NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: RRHH Y NÓMINA
-- ---------------------------------------------------------------------

-- Áreas de la empresa.
CREATE TABLE departamento (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  nombre                    VARCHAR(80) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Puestos de trabajo con su salario base de referencia.
CREATE TABLE cargo (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre                    VARCHAR(80) NOT NULL,
  salario_base              NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Ficha del empleado. usuario_id es NULL si no accede al sistema. fecha_egreso se completa
-- al desvincularse.
CREATE TABLE empleado (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  sucursal_id               BIGINT NOT NULL, -- FK -> sucursal
  departamento_id           BIGINT NOT NULL, -- FK -> departamento
  cargo_id                  BIGINT NOT NULL, -- FK -> cargo
  usuario_id                BIGINT NULL, -- FK -> usuario
  ci                        VARCHAR(20) NOT NULL UNIQUE,
  nombres                   VARCHAR(80) NOT NULL,
  apellidos                 VARCHAR(80) NOT NULL,
  fecha_ingreso             DATE NOT NULL,
  fecha_egreso              DATE NULL,
  salario_base              NUMERIC(12,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('ACT', 'SUS', 'BAJ')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Contratos del empleado (indefinido o plazo fijo) con su historial de salario.
CREATE TABLE contrato (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empleado_id               BIGINT NOT NULL, -- FK -> empleado
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('IND', 'DET')),
  fecha_inicio              DATE NOT NULL,
  fecha_fin                 DATE NULL,
  salario                   NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Marcación diaria de entrada y salida.
CREATE TABLE asistencia (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empleado_id               BIGINT NOT NULL, -- FK -> empleado
  fecha                     DATE NOT NULL,
  hora_entrada              TIME NULL,
  hora_salida               TIME NULL,
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('NOR', 'AUS', 'PER')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_asistencia_empleado_id_fecha UNIQUE (empleado_id, fecha) -- clave natural
);

-- Vacaciones, reposos y permisos, con aprobación de un superior.
CREATE TABLE licencia (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empleado_id               BIGINT NOT NULL, -- FK -> empleado
  aprobado_por              BIGINT NULL, -- FK -> usuario
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('VAC', 'REP', 'PER')),
  desde                     DATE NOT NULL,
  hasta                     DATE NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('SOL', 'APR', 'REC')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Haberes y descuentos (salario, horas extra, aporte IPS, anticipos). es_ips marca los
-- conceptos sujetos a aporte.
CREATE TABLE concepto_nomina (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo                    VARCHAR(20) NOT NULL UNIQUE,
  nombre                    VARCHAR(80) NOT NULL,
  tipo                      VARCHAR(3) NOT NULL CHECK (tipo IN ('HAB', 'DES')),
  es_ips                    BOOLEAN NOT NULL,
  formula                   VARCHAR(100) NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Liquidación de un período. Al cerrarse genera su asiento contable.
CREATE TABLE nomina (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  asiento_id                BIGINT NULL, -- FK -> asiento
  periodo                   DATE NOT NULL,
  fecha_pago                DATE NULL,
  total_haberes             NUMERIC(14,2) NOT NULL,
  total_descuentos          NUMERIC(14,2) NOT NULL,
  total_neto                NUMERIC(14,2) NOT NULL,
  estado                    VARCHAR(3) NOT NULL CHECK (estado IN ('BOR', 'CER', 'PAG')),
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_nomina_empresa_id_periodo UNIQUE (empresa_id, periodo) -- clave natural
);

-- Un concepto liquidado a un empleado en una nómina.
CREATE TABLE nomina_detalle (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nomina_id                 BIGINT NOT NULL, -- FK -> nomina
  empleado_id               BIGINT NOT NULL, -- FK -> empleado
  concepto_id               BIGINT NOT NULL, -- FK -> concepto_nomina
  monto                     NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
--  MÓDULO: RETENCIONES
-- ---------------------------------------------------------------------

-- Catálogo de retenciones (IVA, renta) con su porcentaje.
CREATE TABLE retencion_tipo (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo                    VARCHAR(20) NOT NULL UNIQUE,
  nombre                    VARCHAR(80) NOT NULL,
  impuesto                  VARCHAR(5) NOT NULL CHECK (impuesto IN ('IVA', 'RENTA')),
  porcentaje                NUMERIC(5,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Retención sufrida (te la hace el cliente al cobrar) o practicada (se la haces al
-- proveedor al pagar). Apunta al cobro o pago y a su factura; se informa en el libro
-- fiscal.
CREATE TABLE retencion (
  id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                BIGINT NOT NULL, -- FK -> empresa
  tipo_id                   BIGINT NOT NULL, -- FK -> retencion_tipo
  sentido                   VARCHAR(3) NOT NULL CHECK (sentido IN ('SUF', 'PRA')),
  cobro_id                  BIGINT NULL, -- FK -> cobro
  pago_proveedor_id         BIGINT NULL, -- FK -> pago_proveedor
  factura_id                BIGINT NULL, -- FK -> factura
  factura_compra_id         BIGINT NULL, -- FK -> factura_compra
  nro_comprobante           VARCHAR(20) NOT NULL,
  fecha                     DATE NOT NULL,
  base                      NUMERIC(12,2) NOT NULL,
  monto                     NUMERIC(12,2) NOT NULL,
  created_at                TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_retencion_1 CHECK ((sentido = 'SUF' AND cobro_id IS NOT NULL) OR (sentido = 'PRA' AND pago_proveedor_id IS NOT NULL))
);

-- =====================================================================
--  2. CLAVES FORÁNEAS
-- =====================================================================
ALTER TABLE empresa ADD CONSTRAINT fk_empresa_moneda_base_id FOREIGN KEY (moneda_base_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE sucursal ADD CONSTRAINT fk_sucursal_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE usuario ADD CONSTRAINT fk_usuario_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE usuario ADD CONSTRAINT fk_usuario_rol_id FOREIGN KEY (rol_id) REFERENCES rol(id) ON DELETE RESTRICT;
ALTER TABLE producto ADD CONSTRAINT fk_producto_impuesto_id FOREIGN KEY (impuesto_id) REFERENCES impuesto(id) ON DELETE RESTRICT;
ALTER TABLE producto ADD CONSTRAINT fk_producto_categoria_id FOREIGN KEY (categoria_id) REFERENCES categoria(id) ON DELETE RESTRICT;
ALTER TABLE producto ADD CONSTRAINT fk_producto_unidad_id FOREIGN KEY (unidad_id) REFERENCES unidad_medida(id) ON DELETE RESTRICT;
ALTER TABLE timbrado ADD CONSTRAINT fk_timbrado_sucursal_id FOREIGN KEY (sucursal_id) REFERENCES sucursal(id) ON DELETE RESTRICT;
ALTER TABLE rol_permiso ADD CONSTRAINT fk_rol_permiso_rol_id FOREIGN KEY (rol_id) REFERENCES rol(id) ON DELETE RESTRICT;
ALTER TABLE rol_permiso ADD CONSTRAINT fk_rol_permiso_permiso_id FOREIGN KEY (permiso_id) REFERENCES permiso(id) ON DELETE RESTRICT;
ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE parametro_sistema ADD CONSTRAINT fk_parametro_sistema_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE secuencia_documento ADD CONSTRAINT fk_secuencia_documento_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE secuencia_documento ADD CONSTRAINT fk_secuencia_documento_sucursal_id FOREIGN KEY (sucursal_id) REFERENCES sucursal(id) ON DELETE RESTRICT;
ALTER TABLE cliente ADD CONSTRAINT fk_cliente_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE cliente ADD CONSTRAINT fk_cliente_lista_precio_id FOREIGN KEY (lista_precio_id) REFERENCES lista_precio(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_cliente_id FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_pedido_venta_id FOREIGN KEY (pedido_venta_id) REFERENCES pedido_venta(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_remision_id FOREIGN KEY (remision_id) REFERENCES remision(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_timbrado_id FOREIGN KEY (timbrado_id) REFERENCES timbrado(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_sifen_lote_id FOREIGN KEY (sifen_lote_id) REFERENCES sifen_lote(id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_factura_id FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_pedido_venta_detalle_id FOREIGN KEY (pedido_venta_detalle_id) REFERENCES pedido_venta_detalle(id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_impuesto_id FOREIGN KEY (impuesto_id) REFERENCES impuesto(id) ON DELETE RESTRICT;
ALTER TABLE nota_credito ADD CONSTRAINT fk_nota_credito_factura_id FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT;
ALTER TABLE nota_credito ADD CONSTRAINT fk_nota_credito_timbrado_id FOREIGN KEY (timbrado_id) REFERENCES timbrado(id) ON DELETE RESTRICT;
ALTER TABLE cuenta_cobrar ADD CONSTRAINT fk_cuenta_cobrar_factura_id FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT;
ALTER TABLE plan_pago ADD CONSTRAINT fk_plan_pago_cuenta_cobrar_id FOREIGN KEY (cuenta_cobrar_id) REFERENCES cuenta_cobrar(id) ON DELETE RESTRICT;
ALTER TABLE cliente_direccion ADD CONSTRAINT fk_cliente_direccion_cliente_id FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT;
ALTER TABLE cobro ADD CONSTRAINT fk_cobro_cliente_id FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT;
ALTER TABLE cobro ADD CONSTRAINT fk_cobro_caja_sesion_id FOREIGN KEY (caja_sesion_id) REFERENCES caja_sesion(id) ON DELETE RESTRICT;
ALTER TABLE cobro ADD CONSTRAINT fk_cobro_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE cobro_aplicacion ADD CONSTRAINT fk_cobro_aplicacion_cobro_id FOREIGN KEY (cobro_id) REFERENCES cobro(id) ON DELETE RESTRICT;
ALTER TABLE cobro_aplicacion ADD CONSTRAINT fk_cobro_aplicacion_plan_pago_id FOREIGN KEY (plan_pago_id) REFERENCES plan_pago(id) ON DELETE RESTRICT;
ALTER TABLE cobro_detalle ADD CONSTRAINT fk_cobro_detalle_cobro_id FOREIGN KEY (cobro_id) REFERENCES cobro(id) ON DELETE RESTRICT;
ALTER TABLE cobro_detalle ADD CONSTRAINT fk_cobro_detalle_forma_pago_id FOREIGN KEY (forma_pago_id) REFERENCES forma_pago(id) ON DELETE RESTRICT;
ALTER TABLE cobro_detalle ADD CONSTRAINT fk_cobro_detalle_cuenta_bancaria_id FOREIGN KEY (cuenta_bancaria_id) REFERENCES cuenta_bancaria(id) ON DELETE RESTRICT;
ALTER TABLE cobro_detalle ADD CONSTRAINT fk_cobro_detalle_cheque_id FOREIGN KEY (cheque_id) REFERENCES cheque(id) ON DELETE RESTRICT;
ALTER TABLE cuenta_bancaria ADD CONSTRAINT fk_cuenta_bancaria_banco_id FOREIGN KEY (banco_id) REFERENCES banco(id) ON DELETE RESTRICT;
ALTER TABLE cuenta_bancaria ADD CONSTRAINT fk_cuenta_bancaria_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE cuenta_bancaria ADD CONSTRAINT fk_cuenta_bancaria_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE cheque ADD CONSTRAINT fk_cheque_banco_id FOREIGN KEY (banco_id) REFERENCES banco(id) ON DELETE RESTRICT;
ALTER TABLE caja ADD CONSTRAINT fk_caja_sucursal_id FOREIGN KEY (sucursal_id) REFERENCES sucursal(id) ON DELETE RESTRICT;
ALTER TABLE caja_sesion ADD CONSTRAINT fk_caja_sesion_caja_id FOREIGN KEY (caja_id) REFERENCES caja(id) ON DELETE RESTRICT;
ALTER TABLE caja_sesion ADD CONSTRAINT fk_caja_sesion_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE caja_sesion ADD CONSTRAINT fk_caja_sesion_autorizado_por FOREIGN KEY (autorizado_por) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE caja_movimiento ADD CONSTRAINT fk_caja_movimiento_caja_sesion_id FOREIGN KEY (caja_sesion_id) REFERENCES caja_sesion(id) ON DELETE RESTRICT;
ALTER TABLE caja_movimiento ADD CONSTRAINT fk_caja_movimiento_cobro_detalle_id FOREIGN KEY (cobro_detalle_id) REFERENCES cobro_detalle(id) ON DELETE RESTRICT;
ALTER TABLE caja_movimiento ADD CONSTRAINT fk_caja_movimiento_cuenta_bancaria_id FOREIGN KEY (cuenta_bancaria_id) REFERENCES cuenta_bancaria(id) ON DELETE RESTRICT;
ALTER TABLE caja_movimiento ADD CONSTRAINT fk_caja_movimiento_pago_proveedor_id FOREIGN KEY (pago_proveedor_id) REFERENCES pago_proveedor(id) ON DELETE RESTRICT;
ALTER TABLE caja_arqueo_detalle ADD CONSTRAINT fk_caja_arqueo_detalle_caja_sesion_id FOREIGN KEY (caja_sesion_id) REFERENCES caja_sesion(id) ON DELETE RESTRICT;
ALTER TABLE deposito ADD CONSTRAINT fk_deposito_sucursal_id FOREIGN KEY (sucursal_id) REFERENCES sucursal(id) ON DELETE RESTRICT;
ALTER TABLE categoria ADD CONSTRAINT fk_categoria_padre_id FOREIGN KEY (padre_id) REFERENCES categoria(id) ON DELETE RESTRICT;
ALTER TABLE stock ADD CONSTRAINT fk_stock_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE stock ADD CONSTRAINT fk_stock_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_deposito_destino_id FOREIGN KEY (deposito_destino_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_lote_id FOREIGN KEY (lote_id) REFERENCES lote(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_recepcion_detalle_id FOREIGN KEY (recepcion_detalle_id) REFERENCES recepcion_detalle(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_factura_detalle_id FOREIGN KEY (factura_detalle_id) REFERENCES factura_detalle(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_remision_detalle_id FOREIGN KEY (remision_detalle_id) REFERENCES remision_detalle(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_transferencia_detalle_id FOREIGN KEY (transferencia_detalle_id) REFERENCES transferencia_detalle(id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_stock_ajuste_id FOREIGN KEY (ajuste_id) REFERENCES ajuste_inventario(id) ON DELETE RESTRICT;
ALTER TABLE ajuste_inventario ADD CONSTRAINT fk_ajuste_inventario_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE ajuste_inventario ADD CONSTRAINT fk_ajuste_inventario_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE ajuste_inventario ADD CONSTRAINT fk_ajuste_inventario_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE transferencia_deposito ADD CONSTRAINT fk_transferencia_deposito_deposito_origen_id FOREIGN KEY (deposito_origen_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE transferencia_deposito ADD CONSTRAINT fk_transferencia_deposito_deposito_destino_id FOREIGN KEY (deposito_destino_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE transferencia_deposito ADD CONSTRAINT fk_transferencia_deposito_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE transferencia_detalle ADD CONSTRAINT fk_transferencia_detalle_transferencia_id FOREIGN KEY (transferencia_id) REFERENCES transferencia_deposito(id) ON DELETE RESTRICT;
ALTER TABLE transferencia_detalle ADD CONSTRAINT fk_transferencia_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE transferencia_detalle ADD CONSTRAINT fk_transferencia_detalle_lote_id FOREIGN KEY (lote_id) REFERENCES lote(id) ON DELETE RESTRICT;
ALTER TABLE proveedor ADD CONSTRAINT fk_proveedor_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE orden_compra ADD CONSTRAINT fk_orden_compra_proveedor_id FOREIGN KEY (proveedor_id) REFERENCES proveedor(id) ON DELETE RESTRICT;
ALTER TABLE orden_compra ADD CONSTRAINT fk_orden_compra_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE orden_compra ADD CONSTRAINT fk_orden_compra_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE orden_compra_detalle ADD CONSTRAINT fk_orden_compra_detalle_orden_compra_id FOREIGN KEY (orden_compra_id) REFERENCES orden_compra(id) ON DELETE RESTRICT;
ALTER TABLE orden_compra_detalle ADD CONSTRAINT fk_orden_compra_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE recepcion ADD CONSTRAINT fk_recepcion_orden_compra_id FOREIGN KEY (orden_compra_id) REFERENCES orden_compra(id) ON DELETE RESTRICT;
ALTER TABLE recepcion ADD CONSTRAINT fk_recepcion_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE recepcion ADD CONSTRAINT fk_recepcion_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE recepcion_detalle ADD CONSTRAINT fk_recepcion_detalle_recepcion_id FOREIGN KEY (recepcion_id) REFERENCES recepcion(id) ON DELETE RESTRICT;
ALTER TABLE recepcion_detalle ADD CONSTRAINT fk_recepcion_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE factura_compra ADD CONSTRAINT fk_factura_compra_proveedor_id FOREIGN KEY (proveedor_id) REFERENCES proveedor(id) ON DELETE RESTRICT;
ALTER TABLE factura_compra ADD CONSTRAINT fk_factura_compra_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE factura_compra ADD CONSTRAINT fk_factura_compra_recepcion_id FOREIGN KEY (recepcion_id) REFERENCES recepcion(id) ON DELETE RESTRICT;
ALTER TABLE factura_compra_detalle ADD CONSTRAINT fk_factura_compra_detalle_factura_compra_id FOREIGN KEY (factura_compra_id) REFERENCES factura_compra(id) ON DELETE RESTRICT;
ALTER TABLE factura_compra_detalle ADD CONSTRAINT fk_factura_compra_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE factura_compra_detalle ADD CONSTRAINT fk_factura_compra_detalle_impuesto_id FOREIGN KEY (impuesto_id) REFERENCES impuesto(id) ON DELETE RESTRICT;
ALTER TABLE cuenta_pagar ADD CONSTRAINT fk_cuenta_pagar_factura_compra_id FOREIGN KEY (factura_compra_id) REFERENCES factura_compra(id) ON DELETE RESTRICT;
ALTER TABLE pago_proveedor ADD CONSTRAINT fk_pago_proveedor_cuenta_pagar_id FOREIGN KEY (cuenta_pagar_id) REFERENCES cuenta_pagar(id) ON DELETE RESTRICT;
ALTER TABLE pago_proveedor ADD CONSTRAINT fk_pago_proveedor_forma_pago_id FOREIGN KEY (forma_pago_id) REFERENCES forma_pago(id) ON DELETE RESTRICT;
ALTER TABLE pago_proveedor ADD CONSTRAINT fk_pago_proveedor_cuenta_bancaria_id FOREIGN KEY (cuenta_bancaria_id) REFERENCES cuenta_bancaria(id) ON DELETE RESTRICT;
ALTER TABLE nota_credito_compra ADD CONSTRAINT fk_nota_credito_compra_factura_compra_id FOREIGN KEY (factura_compra_id) REFERENCES factura_compra(id) ON DELETE RESTRICT;
ALTER TABLE anticipo_proveedor ADD CONSTRAINT fk_anticipo_proveedor_proveedor_id FOREIGN KEY (proveedor_id) REFERENCES proveedor(id) ON DELETE RESTRICT;
ALTER TABLE anticipo_proveedor ADD CONSTRAINT fk_anticipo_proveedor_pago_proveedor_id FOREIGN KEY (pago_proveedor_id) REFERENCES pago_proveedor(id) ON DELETE RESTRICT;
ALTER TABLE anticipo_proveedor ADD CONSTRAINT fk_anticipo_proveedor_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE cheque_emitido ADD CONSTRAINT fk_cheque_emitido_cuenta_bancaria_id FOREIGN KEY (cuenta_bancaria_id) REFERENCES cuenta_bancaria(id) ON DELETE RESTRICT;
ALTER TABLE cheque_emitido ADD CONSTRAINT fk_cheque_emitido_pago_proveedor_id FOREIGN KEY (pago_proveedor_id) REFERENCES pago_proveedor(id) ON DELETE RESTRICT;
ALTER TABLE cotizacion ADD CONSTRAINT fk_cotizacion_cliente_id FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT;
ALTER TABLE cotizacion ADD CONSTRAINT fk_cotizacion_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE cotizacion ADD CONSTRAINT fk_cotizacion_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE cotizacion_detalle ADD CONSTRAINT fk_cotizacion_detalle_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES cotizacion(id) ON DELETE RESTRICT;
ALTER TABLE cotizacion_detalle ADD CONSTRAINT fk_cotizacion_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE cotizacion_detalle ADD CONSTRAINT fk_cotizacion_detalle_impuesto_id FOREIGN KEY (impuesto_id) REFERENCES impuesto(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta ADD CONSTRAINT fk_pedido_venta_cliente_id FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta ADD CONSTRAINT fk_pedido_venta_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES cotizacion(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta ADD CONSTRAINT fk_pedido_venta_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta ADD CONSTRAINT fk_pedido_venta_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta ADD CONSTRAINT fk_pedido_venta_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta_detalle ADD CONSTRAINT fk_pedido_venta_detalle_pedido_venta_id FOREIGN KEY (pedido_venta_id) REFERENCES pedido_venta(id) ON DELETE RESTRICT;
ALTER TABLE pedido_venta_detalle ADD CONSTRAINT fk_pedido_venta_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE remision ADD CONSTRAINT fk_remision_pedido_venta_id FOREIGN KEY (pedido_venta_id) REFERENCES pedido_venta(id) ON DELETE RESTRICT;
ALTER TABLE remision ADD CONSTRAINT fk_remision_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE remision ADD CONSTRAINT fk_remision_timbrado_id FOREIGN KEY (timbrado_id) REFERENCES timbrado(id) ON DELETE RESTRICT;
ALTER TABLE remision ADD CONSTRAINT fk_remision_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE remision_detalle ADD CONSTRAINT fk_remision_detalle_remision_id FOREIGN KEY (remision_id) REFERENCES remision(id) ON DELETE RESTRICT;
ALTER TABLE remision_detalle ADD CONSTRAINT fk_remision_detalle_pedido_venta_detalle_id FOREIGN KEY (pedido_venta_detalle_id) REFERENCES pedido_venta_detalle(id) ON DELETE RESTRICT;
ALTER TABLE remision_detalle ADD CONSTRAINT fk_remision_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE ejercicio_contable ADD CONSTRAINT fk_ejercicio_contable_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE plan_cuenta ADD CONSTRAINT fk_plan_cuenta_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE plan_cuenta ADD CONSTRAINT fk_plan_cuenta_padre_id FOREIGN KEY (padre_id) REFERENCES plan_cuenta(id) ON DELETE RESTRICT;
ALTER TABLE configuracion_contable ADD CONSTRAINT fk_configuracion_contable_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE configuracion_contable ADD CONSTRAINT fk_configuracion_contable_cuenta_id FOREIGN KEY (cuenta_id) REFERENCES plan_cuenta(id) ON DELETE RESTRICT;
ALTER TABLE asiento ADD CONSTRAINT fk_asiento_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE asiento ADD CONSTRAINT fk_asiento_ejercicio_id FOREIGN KEY (ejercicio_id) REFERENCES ejercicio_contable(id) ON DELETE RESTRICT;
ALTER TABLE asiento ADD CONSTRAINT fk_asiento_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE asiento_detalle ADD CONSTRAINT fk_asiento_detalle_asiento_id FOREIGN KEY (asiento_id) REFERENCES asiento(id) ON DELETE RESTRICT;
ALTER TABLE asiento_detalle ADD CONSTRAINT fk_asiento_detalle_cuenta_id FOREIGN KEY (cuenta_id) REFERENCES plan_cuenta(id) ON DELETE RESTRICT;
ALTER TABLE comision_regla ADD CONSTRAINT fk_comision_regla_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE comision_regla ADD CONSTRAINT fk_comision_regla_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE comision_regla ADD CONSTRAINT fk_comision_regla_categoria_id FOREIGN KEY (categoria_id) REFERENCES categoria(id) ON DELETE RESTRICT;
ALTER TABLE comision ADD CONSTRAINT fk_comision_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE comision ADD CONSTRAINT fk_comision_factura_id FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT;
ALTER TABLE comision ADD CONSTRAINT fk_comision_regla_id FOREIGN KEY (regla_id) REFERENCES comision_regla(id) ON DELETE RESTRICT;
ALTER TABLE comision ADD CONSTRAINT fk_comision_cobro_id FOREIGN KEY (cobro_id) REFERENCES cobro(id) ON DELETE RESTRICT;
ALTER TABLE extracto_bancario ADD CONSTRAINT fk_extracto_bancario_cuenta_bancaria_id FOREIGN KEY (cuenta_bancaria_id) REFERENCES cuenta_bancaria(id) ON DELETE RESTRICT;
ALTER TABLE extracto_linea ADD CONSTRAINT fk_extracto_linea_extracto_id FOREIGN KEY (extracto_id) REFERENCES extracto_bancario(id) ON DELETE RESTRICT;
ALTER TABLE conciliacion ADD CONSTRAINT fk_conciliacion_extracto_linea_id FOREIGN KEY (extracto_linea_id) REFERENCES extracto_linea(id) ON DELETE RESTRICT;
ALTER TABLE conciliacion ADD CONSTRAINT fk_conciliacion_cobro_detalle_id FOREIGN KEY (cobro_detalle_id) REFERENCES cobro_detalle(id) ON DELETE RESTRICT;
ALTER TABLE conciliacion ADD CONSTRAINT fk_conciliacion_pago_proveedor_id FOREIGN KEY (pago_proveedor_id) REFERENCES pago_proveedor(id) ON DELETE RESTRICT;
ALTER TABLE conciliacion ADD CONSTRAINT fk_conciliacion_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE sifen_lote ADD CONSTRAINT fk_sifen_lote_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE sifen_evento ADD CONSTRAINT fk_sifen_evento_factura_id FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT;
ALTER TABLE sifen_evento ADD CONSTRAINT fk_sifen_evento_nota_credito_id FOREIGN KEY (nota_credito_id) REFERENCES nota_credito(id) ON DELETE RESTRICT;
ALTER TABLE sifen_evento ADD CONSTRAINT fk_sifen_evento_lote_id FOREIGN KEY (lote_id) REFERENCES sifen_lote(id) ON DELETE RESTRICT;
ALTER TABLE sifen_evento ADD CONSTRAINT fk_sifen_evento_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE lista_precio ADD CONSTRAINT fk_lista_precio_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE lista_precio ADD CONSTRAINT fk_lista_precio_moneda_id FOREIGN KEY (moneda_id) REFERENCES moneda(id) ON DELETE RESTRICT;
ALTER TABLE lista_precio_detalle ADD CONSTRAINT fk_lista_precio_detalle_lista_precio_id FOREIGN KEY (lista_precio_id) REFERENCES lista_precio(id) ON DELETE RESTRICT;
ALTER TABLE lista_precio_detalle ADD CONSTRAINT fk_lista_precio_detalle_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE promocion ADD CONSTRAINT fk_promocion_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE promocion ADD CONSTRAINT fk_promocion_categoria_id FOREIGN KEY (categoria_id) REFERENCES categoria(id) ON DELETE RESTRICT;
ALTER TABLE lote ADD CONSTRAINT fk_lote_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE lote ADD CONSTRAINT fk_lote_proveedor_id FOREIGN KEY (proveedor_id) REFERENCES proveedor(id) ON DELETE RESTRICT;
ALTER TABLE stock_lote ADD CONSTRAINT fk_stock_lote_lote_id FOREIGN KEY (lote_id) REFERENCES lote(id) ON DELETE RESTRICT;
ALTER TABLE stock_lote ADD CONSTRAINT fk_stock_lote_deposito_id FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT;
ALTER TABLE serie_producto ADD CONSTRAINT fk_serie_producto_producto_id FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT;
ALTER TABLE serie_producto ADD CONSTRAINT fk_serie_producto_lote_id FOREIGN KEY (lote_id) REFERENCES lote(id) ON DELETE RESTRICT;
ALTER TABLE serie_producto ADD CONSTRAINT fk_serie_producto_factura_detalle_id FOREIGN KEY (factura_detalle_id) REFERENCES factura_detalle(id) ON DELETE RESTRICT;
ALTER TABLE activo_fijo ADD CONSTRAINT fk_activo_fijo_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE activo_fijo ADD CONSTRAINT fk_activo_fijo_sucursal_id FOREIGN KEY (sucursal_id) REFERENCES sucursal(id) ON DELETE RESTRICT;
ALTER TABLE activo_fijo ADD CONSTRAINT fk_activo_fijo_factura_compra_id FOREIGN KEY (factura_compra_id) REFERENCES factura_compra(id) ON DELETE RESTRICT;
ALTER TABLE activo_fijo ADD CONSTRAINT fk_activo_fijo_cuenta_id FOREIGN KEY (cuenta_id) REFERENCES plan_cuenta(id) ON DELETE RESTRICT;
ALTER TABLE depreciacion ADD CONSTRAINT fk_depreciacion_activo_fijo_id FOREIGN KEY (activo_fijo_id) REFERENCES activo_fijo(id) ON DELETE RESTRICT;
ALTER TABLE depreciacion ADD CONSTRAINT fk_depreciacion_asiento_id FOREIGN KEY (asiento_id) REFERENCES asiento(id) ON DELETE RESTRICT;
ALTER TABLE activo_baja ADD CONSTRAINT fk_activo_baja_activo_fijo_id FOREIGN KEY (activo_fijo_id) REFERENCES activo_fijo(id) ON DELETE RESTRICT;
ALTER TABLE departamento ADD CONSTRAINT fk_departamento_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE empleado ADD CONSTRAINT fk_empleado_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE empleado ADD CONSTRAINT fk_empleado_sucursal_id FOREIGN KEY (sucursal_id) REFERENCES sucursal(id) ON DELETE RESTRICT;
ALTER TABLE empleado ADD CONSTRAINT fk_empleado_departamento_id FOREIGN KEY (departamento_id) REFERENCES departamento(id) ON DELETE RESTRICT;
ALTER TABLE empleado ADD CONSTRAINT fk_empleado_cargo_id FOREIGN KEY (cargo_id) REFERENCES cargo(id) ON DELETE RESTRICT;
ALTER TABLE empleado ADD CONSTRAINT fk_empleado_usuario_id FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE contrato ADD CONSTRAINT fk_contrato_empleado_id FOREIGN KEY (empleado_id) REFERENCES empleado(id) ON DELETE RESTRICT;
ALTER TABLE asistencia ADD CONSTRAINT fk_asistencia_empleado_id FOREIGN KEY (empleado_id) REFERENCES empleado(id) ON DELETE RESTRICT;
ALTER TABLE licencia ADD CONSTRAINT fk_licencia_empleado_id FOREIGN KEY (empleado_id) REFERENCES empleado(id) ON DELETE RESTRICT;
ALTER TABLE licencia ADD CONSTRAINT fk_licencia_aprobado_por FOREIGN KEY (aprobado_por) REFERENCES usuario(id) ON DELETE RESTRICT;
ALTER TABLE nomina ADD CONSTRAINT fk_nomina_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE nomina ADD CONSTRAINT fk_nomina_asiento_id FOREIGN KEY (asiento_id) REFERENCES asiento(id) ON DELETE RESTRICT;
ALTER TABLE nomina_detalle ADD CONSTRAINT fk_nomina_detalle_nomina_id FOREIGN KEY (nomina_id) REFERENCES nomina(id) ON DELETE RESTRICT;
ALTER TABLE nomina_detalle ADD CONSTRAINT fk_nomina_detalle_empleado_id FOREIGN KEY (empleado_id) REFERENCES empleado(id) ON DELETE RESTRICT;
ALTER TABLE nomina_detalle ADD CONSTRAINT fk_nomina_detalle_concepto_id FOREIGN KEY (concepto_id) REFERENCES concepto_nomina(id) ON DELETE RESTRICT;
ALTER TABLE retencion ADD CONSTRAINT fk_retencion_empresa_id FOREIGN KEY (empresa_id) REFERENCES empresa(id) ON DELETE RESTRICT;
ALTER TABLE retencion ADD CONSTRAINT fk_retencion_tipo_id FOREIGN KEY (tipo_id) REFERENCES retencion_tipo(id) ON DELETE RESTRICT;
ALTER TABLE retencion ADD CONSTRAINT fk_retencion_cobro_id FOREIGN KEY (cobro_id) REFERENCES cobro(id) ON DELETE RESTRICT;
ALTER TABLE retencion ADD CONSTRAINT fk_retencion_pago_proveedor_id FOREIGN KEY (pago_proveedor_id) REFERENCES pago_proveedor(id) ON DELETE RESTRICT;
ALTER TABLE retencion ADD CONSTRAINT fk_retencion_factura_id FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT;
ALTER TABLE retencion ADD CONSTRAINT fk_retencion_factura_compra_id FOREIGN KEY (factura_compra_id) REFERENCES factura_compra(id) ON DELETE RESTRICT;

-- =====================================================================
--  3. ÍNDICES (uno por cada FK que no tiene ya índice único)
-- =====================================================================
CREATE INDEX idx_empresa_moneda_base_id ON empresa(moneda_base_id);
CREATE INDEX idx_sucursal_empresa_id ON sucursal(empresa_id);
CREATE INDEX idx_usuario_empresa_id ON usuario(empresa_id);
CREATE INDEX idx_usuario_rol_id ON usuario(rol_id);
CREATE INDEX idx_producto_impuesto_id ON producto(impuesto_id);
CREATE INDEX idx_producto_categoria_id ON producto(categoria_id);
CREATE INDEX idx_producto_unidad_id ON producto(unidad_id);
CREATE INDEX idx_timbrado_sucursal_id ON timbrado(sucursal_id);
CREATE INDEX idx_rol_permiso_permiso_id ON rol_permiso(permiso_id);
CREATE INDEX idx_audit_log_usuario_id ON audit_log(usuario_id);
CREATE INDEX idx_secuencia_documento_empresa_id ON secuencia_documento(empresa_id);
CREATE INDEX idx_secuencia_documento_sucursal_id ON secuencia_documento(sucursal_id);
CREATE INDEX idx_cliente_lista_precio_id ON cliente(lista_precio_id);
CREATE INDEX idx_factura_cliente_id ON factura(cliente_id);
CREATE INDEX idx_factura_pedido_venta_id ON factura(pedido_venta_id);
CREATE INDEX idx_factura_remision_id ON factura(remision_id);
CREATE INDEX idx_factura_usuario_id ON factura(usuario_id);
CREATE INDEX idx_factura_moneda_id ON factura(moneda_id);
CREATE INDEX idx_factura_sifen_lote_id ON factura(sifen_lote_id);
CREATE INDEX idx_factura_detalle_factura_id ON factura_detalle(factura_id);
CREATE INDEX idx_factura_detalle_pedido_venta_detalle_id ON factura_detalle(pedido_venta_detalle_id);
CREATE INDEX idx_factura_detalle_producto_id ON factura_detalle(producto_id);
CREATE INDEX idx_factura_detalle_impuesto_id ON factura_detalle(impuesto_id);
CREATE INDEX idx_nota_credito_factura_id ON nota_credito(factura_id);
CREATE INDEX idx_plan_pago_cuenta_cobrar_id ON plan_pago(cuenta_cobrar_id);
CREATE INDEX idx_cliente_direccion_cliente_id ON cliente_direccion(cliente_id);
CREATE INDEX idx_cobro_cliente_id ON cobro(cliente_id);
CREATE INDEX idx_cobro_caja_sesion_id ON cobro(caja_sesion_id);
CREATE INDEX idx_cobro_moneda_id ON cobro(moneda_id);
CREATE INDEX idx_cobro_aplicacion_plan_pago_id ON cobro_aplicacion(plan_pago_id);
CREATE INDEX idx_cobro_detalle_cobro_id ON cobro_detalle(cobro_id);
CREATE INDEX idx_cobro_detalle_forma_pago_id ON cobro_detalle(forma_pago_id);
CREATE INDEX idx_cobro_detalle_cuenta_bancaria_id ON cobro_detalle(cuenta_bancaria_id);
CREATE INDEX idx_cobro_detalle_cheque_id ON cobro_detalle(cheque_id);
CREATE INDEX idx_cuenta_bancaria_banco_id ON cuenta_bancaria(banco_id);
CREATE INDEX idx_cuenta_bancaria_empresa_id ON cuenta_bancaria(empresa_id);
CREATE INDEX idx_cuenta_bancaria_moneda_id ON cuenta_bancaria(moneda_id);
CREATE INDEX idx_cheque_banco_id ON cheque(banco_id);
CREATE INDEX idx_caja_sucursal_id ON caja(sucursal_id);
CREATE INDEX idx_caja_sesion_caja_id ON caja_sesion(caja_id);
CREATE INDEX idx_caja_sesion_usuario_id ON caja_sesion(usuario_id);
CREATE INDEX idx_caja_sesion_autorizado_por ON caja_sesion(autorizado_por);
CREATE INDEX idx_caja_movimiento_caja_sesion_id ON caja_movimiento(caja_sesion_id);
CREATE INDEX idx_caja_movimiento_cobro_detalle_id ON caja_movimiento(cobro_detalle_id);
CREATE INDEX idx_caja_movimiento_cuenta_bancaria_id ON caja_movimiento(cuenta_bancaria_id);
CREATE INDEX idx_caja_movimiento_pago_proveedor_id ON caja_movimiento(pago_proveedor_id);
CREATE INDEX idx_caja_arqueo_detalle_caja_sesion_id ON caja_arqueo_detalle(caja_sesion_id);
CREATE INDEX idx_deposito_sucursal_id ON deposito(sucursal_id);
CREATE INDEX idx_categoria_padre_id ON categoria(padre_id);
CREATE INDEX idx_stock_deposito_id ON stock(deposito_id);
CREATE INDEX idx_movimiento_stock_producto_id ON movimiento_stock(producto_id);
CREATE INDEX idx_movimiento_stock_deposito_id ON movimiento_stock(deposito_id);
CREATE INDEX idx_movimiento_stock_deposito_destino_id ON movimiento_stock(deposito_destino_id);
CREATE INDEX idx_movimiento_stock_usuario_id ON movimiento_stock(usuario_id);
CREATE INDEX idx_movimiento_stock_lote_id ON movimiento_stock(lote_id);
CREATE INDEX idx_movimiento_stock_recepcion_detalle_id ON movimiento_stock(recepcion_detalle_id);
CREATE INDEX idx_movimiento_stock_factura_detalle_id ON movimiento_stock(factura_detalle_id);
CREATE INDEX idx_movimiento_stock_remision_detalle_id ON movimiento_stock(remision_detalle_id);
CREATE INDEX idx_movimiento_stock_transferencia_detalle_id ON movimiento_stock(transferencia_detalle_id);
CREATE INDEX idx_movimiento_stock_ajuste_id ON movimiento_stock(ajuste_id);
CREATE INDEX idx_ajuste_inventario_deposito_id ON ajuste_inventario(deposito_id);
CREATE INDEX idx_ajuste_inventario_producto_id ON ajuste_inventario(producto_id);
CREATE INDEX idx_ajuste_inventario_usuario_id ON ajuste_inventario(usuario_id);
CREATE INDEX idx_transferencia_deposito_deposito_origen_id ON transferencia_deposito(deposito_origen_id);
CREATE INDEX idx_transferencia_deposito_deposito_destino_id ON transferencia_deposito(deposito_destino_id);
CREATE INDEX idx_transferencia_deposito_usuario_id ON transferencia_deposito(usuario_id);
CREATE INDEX idx_transferencia_detalle_transferencia_id ON transferencia_detalle(transferencia_id);
CREATE INDEX idx_transferencia_detalle_producto_id ON transferencia_detalle(producto_id);
CREATE INDEX idx_transferencia_detalle_lote_id ON transferencia_detalle(lote_id);
CREATE INDEX idx_orden_compra_proveedor_id ON orden_compra(proveedor_id);
CREATE INDEX idx_orden_compra_moneda_id ON orden_compra(moneda_id);
CREATE INDEX idx_orden_compra_usuario_id ON orden_compra(usuario_id);
CREATE INDEX idx_orden_compra_detalle_orden_compra_id ON orden_compra_detalle(orden_compra_id);
CREATE INDEX idx_orden_compra_detalle_producto_id ON orden_compra_detalle(producto_id);
CREATE INDEX idx_recepcion_orden_compra_id ON recepcion(orden_compra_id);
CREATE INDEX idx_recepcion_deposito_id ON recepcion(deposito_id);
CREATE INDEX idx_recepcion_usuario_id ON recepcion(usuario_id);
CREATE INDEX idx_recepcion_detalle_recepcion_id ON recepcion_detalle(recepcion_id);
CREATE INDEX idx_recepcion_detalle_producto_id ON recepcion_detalle(producto_id);
CREATE INDEX idx_factura_compra_moneda_id ON factura_compra(moneda_id);
CREATE INDEX idx_factura_compra_recepcion_id ON factura_compra(recepcion_id);
CREATE INDEX idx_factura_compra_detalle_factura_compra_id ON factura_compra_detalle(factura_compra_id);
CREATE INDEX idx_factura_compra_detalle_producto_id ON factura_compra_detalle(producto_id);
CREATE INDEX idx_factura_compra_detalle_impuesto_id ON factura_compra_detalle(impuesto_id);
CREATE INDEX idx_pago_proveedor_cuenta_pagar_id ON pago_proveedor(cuenta_pagar_id);
CREATE INDEX idx_pago_proveedor_forma_pago_id ON pago_proveedor(forma_pago_id);
CREATE INDEX idx_pago_proveedor_cuenta_bancaria_id ON pago_proveedor(cuenta_bancaria_id);
CREATE INDEX idx_nota_credito_compra_factura_compra_id ON nota_credito_compra(factura_compra_id);
CREATE INDEX idx_anticipo_proveedor_proveedor_id ON anticipo_proveedor(proveedor_id);
CREATE INDEX idx_anticipo_proveedor_pago_proveedor_id ON anticipo_proveedor(pago_proveedor_id);
CREATE INDEX idx_anticipo_proveedor_moneda_id ON anticipo_proveedor(moneda_id);
CREATE INDEX idx_cheque_emitido_cuenta_bancaria_id ON cheque_emitido(cuenta_bancaria_id);
CREATE INDEX idx_cheque_emitido_pago_proveedor_id ON cheque_emitido(pago_proveedor_id);
CREATE INDEX idx_cotizacion_cliente_id ON cotizacion(cliente_id);
CREATE INDEX idx_cotizacion_usuario_id ON cotizacion(usuario_id);
CREATE INDEX idx_cotizacion_moneda_id ON cotizacion(moneda_id);
CREATE INDEX idx_cotizacion_detalle_cotizacion_id ON cotizacion_detalle(cotizacion_id);
CREATE INDEX idx_cotizacion_detalle_producto_id ON cotizacion_detalle(producto_id);
CREATE INDEX idx_cotizacion_detalle_impuesto_id ON cotizacion_detalle(impuesto_id);
CREATE INDEX idx_pedido_venta_cliente_id ON pedido_venta(cliente_id);
CREATE INDEX idx_pedido_venta_cotizacion_id ON pedido_venta(cotizacion_id);
CREATE INDEX idx_pedido_venta_usuario_id ON pedido_venta(usuario_id);
CREATE INDEX idx_pedido_venta_deposito_id ON pedido_venta(deposito_id);
CREATE INDEX idx_pedido_venta_moneda_id ON pedido_venta(moneda_id);
CREATE INDEX idx_pedido_venta_detalle_pedido_venta_id ON pedido_venta_detalle(pedido_venta_id);
CREATE INDEX idx_pedido_venta_detalle_producto_id ON pedido_venta_detalle(producto_id);
CREATE INDEX idx_remision_pedido_venta_id ON remision(pedido_venta_id);
CREATE INDEX idx_remision_deposito_id ON remision(deposito_id);
CREATE INDEX idx_remision_timbrado_id ON remision(timbrado_id);
CREATE INDEX idx_remision_usuario_id ON remision(usuario_id);
CREATE INDEX idx_remision_detalle_remision_id ON remision_detalle(remision_id);
CREATE INDEX idx_remision_detalle_pedido_venta_detalle_id ON remision_detalle(pedido_venta_detalle_id);
CREATE INDEX idx_remision_detalle_producto_id ON remision_detalle(producto_id);
CREATE INDEX idx_plan_cuenta_padre_id ON plan_cuenta(padre_id);
CREATE INDEX idx_configuracion_contable_empresa_id ON configuracion_contable(empresa_id);
CREATE INDEX idx_configuracion_contable_cuenta_id ON configuracion_contable(cuenta_id);
CREATE INDEX idx_asiento_ejercicio_id ON asiento(ejercicio_id);
CREATE INDEX idx_asiento_usuario_id ON asiento(usuario_id);
CREATE INDEX idx_asiento_detalle_asiento_id ON asiento_detalle(asiento_id);
CREATE INDEX idx_asiento_detalle_cuenta_id ON asiento_detalle(cuenta_id);
CREATE INDEX idx_comision_regla_empresa_id ON comision_regla(empresa_id);
CREATE INDEX idx_comision_regla_usuario_id ON comision_regla(usuario_id);
CREATE INDEX idx_comision_regla_categoria_id ON comision_regla(categoria_id);
CREATE INDEX idx_comision_usuario_id ON comision(usuario_id);
CREATE INDEX idx_comision_factura_id ON comision(factura_id);
CREATE INDEX idx_comision_regla_id ON comision(regla_id);
CREATE INDEX idx_comision_cobro_id ON comision(cobro_id);
CREATE INDEX idx_extracto_bancario_cuenta_bancaria_id ON extracto_bancario(cuenta_bancaria_id);
CREATE INDEX idx_extracto_linea_extracto_id ON extracto_linea(extracto_id);
CREATE INDEX idx_conciliacion_cobro_detalle_id ON conciliacion(cobro_detalle_id);
CREATE INDEX idx_conciliacion_pago_proveedor_id ON conciliacion(pago_proveedor_id);
CREATE INDEX idx_conciliacion_usuario_id ON conciliacion(usuario_id);
CREATE INDEX idx_sifen_lote_empresa_id ON sifen_lote(empresa_id);
CREATE INDEX idx_sifen_evento_factura_id ON sifen_evento(factura_id);
CREATE INDEX idx_sifen_evento_nota_credito_id ON sifen_evento(nota_credito_id);
CREATE INDEX idx_sifen_evento_lote_id ON sifen_evento(lote_id);
CREATE INDEX idx_sifen_evento_usuario_id ON sifen_evento(usuario_id);
CREATE INDEX idx_lista_precio_empresa_id ON lista_precio(empresa_id);
CREATE INDEX idx_lista_precio_moneda_id ON lista_precio(moneda_id);
CREATE INDEX idx_lista_precio_detalle_producto_id ON lista_precio_detalle(producto_id);
CREATE INDEX idx_promocion_producto_id ON promocion(producto_id);
CREATE INDEX idx_promocion_categoria_id ON promocion(categoria_id);
CREATE INDEX idx_lote_producto_id ON lote(producto_id);
CREATE INDEX idx_lote_proveedor_id ON lote(proveedor_id);
CREATE INDEX idx_stock_lote_deposito_id ON stock_lote(deposito_id);
CREATE INDEX idx_serie_producto_producto_id ON serie_producto(producto_id);
CREATE INDEX idx_serie_producto_lote_id ON serie_producto(lote_id);
CREATE INDEX idx_serie_producto_factura_detalle_id ON serie_producto(factura_detalle_id);
CREATE INDEX idx_activo_fijo_empresa_id ON activo_fijo(empresa_id);
CREATE INDEX idx_activo_fijo_sucursal_id ON activo_fijo(sucursal_id);
CREATE INDEX idx_activo_fijo_factura_compra_id ON activo_fijo(factura_compra_id);
CREATE INDEX idx_activo_fijo_cuenta_id ON activo_fijo(cuenta_id);
CREATE INDEX idx_depreciacion_asiento_id ON depreciacion(asiento_id);
CREATE INDEX idx_departamento_empresa_id ON departamento(empresa_id);
CREATE INDEX idx_empleado_empresa_id ON empleado(empresa_id);
CREATE INDEX idx_empleado_sucursal_id ON empleado(sucursal_id);
CREATE INDEX idx_empleado_departamento_id ON empleado(departamento_id);
CREATE INDEX idx_empleado_cargo_id ON empleado(cargo_id);
CREATE INDEX idx_empleado_usuario_id ON empleado(usuario_id);
CREATE INDEX idx_contrato_empleado_id ON contrato(empleado_id);
CREATE INDEX idx_licencia_empleado_id ON licencia(empleado_id);
CREATE INDEX idx_licencia_aprobado_por ON licencia(aprobado_por);
CREATE INDEX idx_nomina_asiento_id ON nomina(asiento_id);
CREATE INDEX idx_nomina_detalle_nomina_id ON nomina_detalle(nomina_id);
CREATE INDEX idx_nomina_detalle_empleado_id ON nomina_detalle(empleado_id);
CREATE INDEX idx_nomina_detalle_concepto_id ON nomina_detalle(concepto_id);
CREATE INDEX idx_retencion_empresa_id ON retencion(empresa_id);
CREATE INDEX idx_retencion_tipo_id ON retencion(tipo_id);
CREATE INDEX idx_retencion_cobro_id ON retencion(cobro_id);
CREATE INDEX idx_retencion_pago_proveedor_id ON retencion(pago_proveedor_id);
CREATE INDEX idx_retencion_factura_id ON retencion(factura_id);
CREATE INDEX idx_retencion_factura_compra_id ON retencion(factura_compra_id);

-- Índices parciales de integridad
CREATE UNIQUE INDEX uq_caja_sesion_caja_id_abierta ON caja_sesion(caja_id) WHERE estado = 'ABI';  -- una sola sesión abierta por caja

-- Búsquedas frecuentes
CREATE INDEX idx_factura_fecha          ON factura(fecha_emision);
CREATE INDEX idx_cobro_fecha            ON cobro(fecha_cobro);
CREATE INDEX idx_plan_pago_vencimiento  ON plan_pago(fecha_vencimiento) WHERE estado = 'PEND';
CREATE INDEX idx_movstock_fecha         ON movimiento_stock(fecha_hora);
CREATE INDEX idx_audit_tabla_registro   ON audit_log(tabla, registro_id);
CREATE INDEX idx_asiento_origen         ON asiento(origen_tipo, origen_id);

-- =====================================================================
--  4. DOCUMENTACIÓN (COMMENT ON TABLE)
-- =====================================================================
COMMENT ON TABLE empresa IS 'Entidad legal propietaria de los datos. Si el ERP es multiempresa, casi todas las tablas llevan empresa_id.';
COMMENT ON TABLE sucursal IS 'Establecimiento físico. Se vincula al código de establecimiento (001) del timbrado.';
COMMENT ON TABLE usuario IS 'Usuarios del sistema. Los cajeros y vendedores se identifican aquí. Permisos vía rol.';
COMMENT ON TABLE rol IS 'Agrupa permisos (cajero, vendedor, admin). Relación con permisos por tabla rol_permiso.';
COMMENT ON TABLE producto IS 'Catálogo de productos y servicios. Cada uno define su tasa de IVA por defecto y su unidad.';
COMMENT ON TABLE impuesto IS 'Tasas de IVA: 10 %, 5 % y exenta. Se copia a factura_detalle para conservar el histórico.';
COMMENT ON TABLE moneda IS 'Catálogo de monedas (PYG, USD). Las transacciones guardan moneda y cotización del día.';
COMMENT ON TABLE timbrado IS 'Autorización de la SET para numerar documentos: vigencia, establecimiento, punto de expedición y rango. El número de factura se valida contra este rango.';
COMMENT ON TABLE permiso IS 'Acciones atómicas del sistema (ej. factura.anular, caja.cerrar). Se asignan a roles.';
COMMENT ON TABLE rol_permiso IS 'Puente N:M entre roles y permisos.';
COMMENT ON TABLE audit_log IS 'Bitácora de cambios sensibles (anulaciones, precios, diferencias de caja). Solo inserción: guarda el estado antes y después.';
COMMENT ON TABLE parametro_sistema IS 'Configuración general por empresa (moneda por defecto, decimales, días de mora, etc.) en formato clave-valor.';
COMMENT ON TABLE secuencia_documento IS 'Contadores de numeración de documentos internos (recibos, pedidos, asientos) por empresa o sucursal. Para documentos fiscales se usa timbrado.';
COMMENT ON TABLE cliente IS 'Maestro de clientes. Guarda RUC/CI, límite de crédito y condición de pago por defecto. Direcciones y contactos múltiples irían en tablas hijas.';
COMMENT ON TABLE factura IS 'Cabecera de venta (contado o crédito). Usa un timbrado, desglosa IVA y puede ser electrónica (SIFEN). Al emitirse genera su cuenta_cobrar.';
COMMENT ON TABLE factura_detalle IS 'Ítems de la factura. Copia precio y tasa de IVA vigentes al momento de vender.';
COMMENT ON TABLE nota_credito IS 'Devoluciones, descuentos posteriores y anulaciones parciales. Reduce el saldo de la cuenta_cobrar vinculada. Requiere motivo.';
COMMENT ON TABLE cuenta_cobrar IS 'Obligación generada por cada factura (1:1). saldo_pendiente es derivable de plan_pago: mantener con trigger o calcular.';
COMMENT ON TABLE plan_pago IS 'Cronograma de cuotas. Contado: 1 cuota inmediata. Crédito: N cuotas. Incluye mora e intereses.';
COMMENT ON TABLE cliente_direccion IS 'Direcciones múltiples del cliente (fiscal, entrega, cobranza). Solo una puede ser principal.';
COMMENT ON TABLE cobro IS 'Recibo de pago. caja_sesion_id es NULL para transferencias o cobros online que no pasan por caja. Puede generar saldo a favor (anticipo).';
COMMENT ON TABLE cobro_aplicacion IS 'Puente N:M entre cobro y cuotas. Regla: SUM(monto_aplicado) ≤ SUM(cobro_detalle.monto) del cobro; la diferencia es anticipo.';
COMMENT ON TABLE cobro_detalle IS 'Formas de pago del recibo. Si forma_pago.afecta_caja = true, genera un caja_movimiento.';
COMMENT ON TABLE forma_pago IS 'Medios de pago (efectivo, tarjeta, cheque, transferencia). afecta_caja distingue efectivo físico de dinero bancario.';
COMMENT ON TABLE banco IS 'Catálogo de entidades bancarias (solo el banco, no la cuenta).';
COMMENT ON TABLE cuenta_bancaria IS 'Cuenta de la empresa en un banco. Base para tesorería y conciliación bancaria.';
COMMENT ON TABLE cheque IS 'Cartera de cheques: recibido, depositado, cobrado o rechazado. Soporta fecha diferida.';
COMMENT ON TABLE caja IS 'Puestos de caja por sucursal.';
COMMENT ON TABLE caja_sesion IS 'Turno de caja con arqueo ciego: compara el cierre del sistema con lo declarado por el cajero. Las diferencias requieren motivo y autorización.';
COMMENT ON TABLE caja_movimiento IS 'Entradas y salidas de efectivo. cobro_detalle_id es NULL en gastos, retiros, depósitos a banco y traspasos entre cajas.';
COMMENT ON TABLE caja_arqueo_detalle IS 'Conteo por denominación (billetes y monedas) al cerrar el turno.';
COMMENT ON TABLE deposito IS 'Almacén físico de una sucursal. El stock siempre se lleva por producto y depósito.';
COMMENT ON TABLE categoria IS 'Clasificación jerárquica de productos (padre_id NULL = categoría raíz).';
COMMENT ON TABLE unidad_medida IS 'Unidades de medida (UN, KG, LT, CJ) usadas en producto y documentos.';
COMMENT ON TABLE stock IS 'Existencia actual por producto y depósito (único por par). Es un saldo derivado: solo debe cambiar a través de movimiento_stock.';
COMMENT ON TABLE movimiento_stock IS 'Kardex. Toda entrada o salida deja una fila: compras (recepcion_detalle), ventas (remision_detalle, o factura_detalle si no hubo remisión) y ajustes. Guarda el costo para el costo promedio. Es solo de inserción; no se edita.';
COMMENT ON TABLE ajuste_inventario IS 'Corrección por toma física: compara lo contado con el stock del sistema. Al aplicarse genera un movimiento_stock tipo AJU. Requiere motivo y usuario.';
COMMENT ON TABLE transferencia_deposito IS 'Traslado de mercadería entre depósitos como documento. Al enviarse sale del origen; al recibirse entra al destino (dos movimientos de stock).';
COMMENT ON TABLE transferencia_detalle IS 'Productos (y lote, si aplica) trasladados. Cada fila genera movimientos de stock.';
COMMENT ON TABLE proveedor IS 'Maestro de proveedores con RUC y plazo de pago por defecto.';
COMMENT ON TABLE orden_compra IS 'Pedido al proveedor. No mueve stock ni genera deuda; solo es un compromiso.';
COMMENT ON TABLE orden_compra_detalle IS 'Ítems pedidos. cantidad_recibida se actualiza con cada recepción, así se detectan entregas parciales.';
COMMENT ON TABLE recepcion IS 'Ingreso físico de mercadería (nota de remisión del proveedor). orden_compra_id es NULL si se compra sin orden previa. Al registrarse, suma stock.';
COMMENT ON TABLE recepcion_detalle IS 'Cantidad y costo realmente recibidos. Cada fila genera un movimiento_stock de entrada.';
COMMENT ON TABLE factura_compra IS 'Factura del proveedor, con su timbrado y desglose de IVA (base del libro IVA compras). Al registrarse genera su cuenta_pagar.';
COMMENT ON TABLE factura_compra_detalle IS 'Ítems facturados por el proveedor, con su tasa de IVA.';
COMMENT ON TABLE cuenta_pagar IS 'Deuda con el proveedor (1:1 con la factura de compra). Espejo de cuenta_cobrar.';
COMMENT ON TABLE pago_proveedor IS 'Pago de una deuda. Si es en efectivo sale de caja (caja_movimiento); si es transferencia, de una cuenta_bancaria. Para pagos agrupados haría falta una tabla puente como cobro_aplicacion.';
COMMENT ON TABLE nota_credito_compra IS 'Devolución o descuento obtenido del proveedor. Reduce el saldo de la cuenta_pagar de la factura de compra y, si hay devolución física, genera salida de stock.';
COMMENT ON TABLE anticipo_proveedor IS 'Pago adelantado a un proveedor, aún no aplicado a facturas. Es el espejo de cobro.saldo_a_favor.';
COMMENT ON TABLE cheque_emitido IS 'Cheques que la empresa gira a proveedores (los recibidos están en cheque). Soporta fecha de pago diferida.';
COMMENT ON TABLE cotizacion IS 'Oferta al cliente con validez limitada. No reserva stock ni genera deuda. Si se acepta, se convierte en pedido_venta.';
COMMENT ON TABLE cotizacion_detalle IS 'Ítems cotizados con precio y descuento propuestos.';
COMMENT ON TABLE pedido_venta IS 'Compromiso firme con el cliente. Al confirmarse reserva stock (stock.cantidad_reservada) en el depósito indicado. cotizacion_id es NULL si el pedido nació directo.';
COMMENT ON TABLE pedido_venta_detalle IS 'Ítems del pedido. Lleva cantidad entregada y facturada por separado, así soporta entregas y facturaciones parciales.';
COMMENT ON TABLE remision IS 'Nota de remisión: respalda el traslado de mercadería (usa timbrado tipo REM). Al emitirse descuenta stock y libera la reserva. pedido_venta_id es NULL si no hubo pedido.';
COMMENT ON TABLE remision_detalle IS 'Cantidades despachadas. Cada fila genera un movimiento_stock de salida. Si la factura referencia la remisión, su detalle NO vuelve a descontar stock.';
COMMENT ON TABLE ejercicio_contable IS 'Período anual de la empresa. Un asiento solo se puede registrar en un ejercicio abierto; al cerrarse queda bloqueado.';
COMMENT ON TABLE plan_cuenta IS 'Plan de cuentas jerárquico (padre_id NULL = cuenta raíz). Solo las cuentas con acepta_movimiento reciben asientos.';
COMMENT ON TABLE configuracion_contable IS 'Reglas que traducen eventos del ERP en cuentas (ej. VENTA_CREDITO: debe Clientes, haber Ventas e IVA). Permite generar asientos automáticos.';
COMMENT ON TABLE asiento IS 'Cabecera del asiento. origen_tipo y origen_id apuntan al documento que lo generó (factura, cobro, factura_compra, etc.); es una referencia polimórfica, sin FK. Regla: total_debe = total_haber.';
COMMENT ON TABLE asiento_detalle IS 'Líneas del asiento. Cada línea tiene debe o haber, nunca ambos.';
COMMENT ON TABLE comision_regla IS 'Define el porcentaje de comisión por vendedor y/o categoría. base indica si se devenga al facturar o al cobrar.';
COMMENT ON TABLE comision IS 'Comisión devengada por una venta. Si la base es cobro, se genera al aplicar el cobro (cobro_id). Se liquida en lotes: PEN → LIQ → PAG.';
COMMENT ON TABLE extracto_bancario IS 'Extracto importado del banco para un período y una cuenta bancaria.';
COMMENT ON TABLE extracto_linea IS 'Cada movimiento del extracto. Queda PEN hasta que se concilia con un cobro o pago del ERP.';
COMMENT ON TABLE conciliacion IS 'Cruce entre una línea del extracto y un cobro_detalle (crédito) o un pago_proveedor (débito). Registra quién concilió y la diferencia, si existe.';
COMMENT ON TABLE sifen_lote IS 'Lote de documentos electrónicos enviados a SIFEN. Guarda la respuesta de la SET.';
COMMENT ON TABLE sifen_evento IS 'Eventos sobre un documento ya aprobado: cancelación, inutilización de numeración, conformidad o disconformidad. Apunta a una factura o a una nota de crédito.';
COMMENT ON TABLE lista_precio IS 'Lista de precios por moneda y vigencia (mayorista, minorista, etc.). Se asigna al cliente; si no tiene, aplica producto.precio_venta.';
COMMENT ON TABLE lista_precio_detalle IS 'Precio de un producto en una lista, con cantidad mínima para precios escalonados.';
COMMENT ON TABLE promocion IS 'Descuento temporal sobre un producto o una categoría (porcentaje, monto fijo o 2x1). Se aplica al armar cotización, pedido o factura.';
COMMENT ON TABLE lote IS 'Lote de un producto con fecha de vencimiento. Permite trazabilidad y salida por FEFO (primero vence, primero sale).';
COMMENT ON TABLE stock_lote IS 'Existencia por lote y depósito. Su suma debe coincidir con stock.cantidad del producto cuando este usa lotes.';
COMMENT ON TABLE serie_producto IS 'Número de serie individual (equipos, garantías). Sigue su ciclo: en stock, vendido o devuelto.';
COMMENT ON TABLE activo_fijo IS 'Bien de uso de la empresa. Se origina normalmente en una factura de compra. La cuenta contable define dónde se registra su costo.';
COMMENT ON TABLE depreciacion IS 'Cuota mensual de depreciación. Genera su asiento contable y acumula el valor depreciado.';
COMMENT ON TABLE activo_baja IS 'Baja o venta del activo. Registra valor en libros y, si se vendió, el precio obtenido.';
COMMENT ON TABLE departamento IS 'Áreas de la empresa.';
COMMENT ON TABLE cargo IS 'Puestos de trabajo con su salario base de referencia.';
COMMENT ON TABLE empleado IS 'Ficha del empleado. usuario_id es NULL si no accede al sistema. fecha_egreso se completa al desvincularse.';
COMMENT ON TABLE contrato IS 'Contratos del empleado (indefinido o plazo fijo) con su historial de salario.';
COMMENT ON TABLE asistencia IS 'Marcación diaria de entrada y salida.';
COMMENT ON TABLE licencia IS 'Vacaciones, reposos y permisos, con aprobación de un superior.';
COMMENT ON TABLE concepto_nomina IS 'Haberes y descuentos (salario, horas extra, aporte IPS, anticipos). es_ips marca los conceptos sujetos a aporte.';
COMMENT ON TABLE nomina IS 'Liquidación de un período. Al cerrarse genera su asiento contable.';
COMMENT ON TABLE nomina_detalle IS 'Un concepto liquidado a un empleado en una nómina.';
COMMENT ON TABLE retencion_tipo IS 'Catálogo de retenciones (IVA, renta) con su porcentaje.';
COMMENT ON TABLE retencion IS 'Retención sufrida (te la hace el cliente al cobrar) o practicada (se la haces al proveedor al pagar). Apunta al cobro o pago y a su factura; se informa en el libro fiscal.';

-- =====================================================================
--  5. TRIGGER GENÉRICO updated_at (para todas las tablas con esa columna)
-- =====================================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT table_name FROM information_schema.columns
           WHERE table_schema = current_schema() AND column_name = 'updated_at'
  LOOP
    EXECUTE format('CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON %I
                    FOR EACH ROW EXECUTE FUNCTION set_updated_at()', r.table_name, r.table_name);
  END LOOP;
END $$;

-- =====================================================================
--  6. REGLAS DE NEGOCIO QUE REQUIEREN LÓGICA (aplicación o triggers)
--     Esto NO está implementado en el esquema: es lo que debe cubrir el código.
-- =====================================================================
--  STOCK
--   * stock.cantidad solo cambia insertando en movimiento_stock (kardex inmutable).
--   * Si la factura referencia una remisión, su detalle NO vuelve a descontar stock.
--   * Si el producto usa lotes, SUM(stock_lote.cantidad) = stock.cantidad.
--   * Confirmar pedido_venta incrementa stock.cantidad_reservada; la remisión lo libera.
--   * transferencia_deposito genera 2 movimientos: salida en origen y entrada en destino.
--  VENTAS Y COBROS
--   * Emitir factura crea su cuenta_cobrar (1:1) y su plan_pago (contado = 1 cuota).
--   * cuenta_cobrar.saldo_pendiente = SUM(plan_pago.saldo_cuota); nota_credito lo reduce.
--   * Por cobro: SUM(cobro_aplicacion.monto_aplicado) <= SUM(cobro_detalle.monto);
--     la diferencia es anticipo (cobro.saldo_a_favor).
--   * forma_pago.afecta_caja = TRUE => cada cobro_detalle genera un caja_movimiento
--     y exige cobro.caja_sesion_id (sesión abierta).
--   * numero_factura debe estar dentro del rango y vigencia del timbrado.
--  CAJA
--   * caja_sesion.diferencia = monto_cierre_declarado - monto_cierre_sistema;
--     si es distinta de 0, exigir motivo_diferencia y autorizado_por.
--   * SUM(caja_arqueo_detalle.subtotal) = monto_cierre_declarado.
--  COMPRAS
--   * La recepción genera movimiento_stock (entrada) y actualiza el costo promedio.
--   * Registrar factura_compra crea su cuenta_pagar (1:1).
--  CONTABILIDAD
--   * asiento solo en ejercicio ABIERTO; los asientos automáticos se arman con
--     configuracion_contable. Cada asiento_detalle tiene debe O haber (ver CHECK).
--   * Los libros de IVA ventas/compras son consultas (vistas) sobre factura y
--     factura_compra; no son tablas.
--  OTROS
--   * Documentos: no se borran, se anulan (estado). audit_log es solo inserción.
--   * sifen_evento: exactamente un documento afectado (factura o nota de crédito).
