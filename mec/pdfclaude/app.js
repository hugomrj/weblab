/* ============================================================
   GESTOR DOCUMENTAL — app.js
   Visor de documentos en HTML + CSS + JavaScript puro.
   ============================================================ */

/* ---------- Datos fijos de la empresa emisora ---------- */
const EMISOR = {
  nombre: "Comercial del Sur S.A.",
  ruc: "80012345-6",
  timbrado: "18742365",
  direccion: "Av. Mariscal López 1234 c/ Perú, Asunción, Paraguay",
  telefono: "+595 21 555 0134"
};

/* ---------- Metadatos por tipo de documento ---------- */
const TIPO_INFO = {
  factura:        { label: "Factura",           abbr: "FA" },
  nota_credito:   { label: "Nota de Crédito",    abbr: "NC" },
  presupuesto:    { label: "Presupuesto",        abbr: "PR" },
  recibo:         { label: "Recibo",             abbr: "RE" },
  orden_compra:   { label: "Orden de Compra",    abbr: "OC" }
};

/* ---------- Estado de la aplicación ---------- */
const state = {
  documentos: [],   // todos los documentos cargados
  filtrados: [],     // documentos visibles según el filtro actual
  actualId: null     // id del documento actualmente seleccionado
};

/* ---------- Referencias al DOM ---------- */
const el = {
  docList: document.getElementById("docList"),
  docCount: document.getElementById("docCount"),
  emptyState: document.getElementById("emptyState"),
  searchInput: document.getElementById("searchInput"),
  sheet: document.getElementById("sheet"),
  docIndicator: document.getElementById("docIndicator"),
  prevBtn: document.getElementById("prevBtn"),
  nextBtn: document.getElementById("nextBtn"),
  printBtn: document.getElementById("printBtn"),
  sidebarToggle: document.getElementById("sidebarToggle"),
  sidebarClose: document.getElementById("sidebarClose"),
  sidebarScrim: document.getElementById("sidebarScrim"),
  app: document.querySelector(".app")
};

/* ============================================================
   CARGA DE DATOS
   ============================================================ */
async function cargarDocumentos() {
  try {
    const respuesta = await fetch("documentos.json");
    if (!respuesta.ok) throw new Error("No se pudo leer documentos.json");
    const data = await respuesta.json();

    // Orden cronológico descendente (más recientes primero)
    state.documentos = [...data.documentos].sort(
      (a, b) => new Date(b.fecha) - new Date(a.fecha)
    );
    state.filtrados = state.documentos;

    renderizarIndice(state.filtrados);

    if (state.documentos.length > 0) {
      seleccionarDocumento(state.documentos[0].id);
    }
  } catch (error) {
    el.sheet.innerHTML = `
      <div class="sheet-inner">
        <p class="sheet-loading">No se pudieron cargar los documentos.<br>
        Verificá que <code>documentos.json</code> esté junto a este archivo.</p>
      </div>`;
    console.error(error);
  }
}

/* ============================================================
   RENDERIZAR ÍNDICE (panel izquierdo)
   ============================================================ */
function renderizarIndice(lista) {
  el.docCount.textContent = `${state.documentos.length} documento${state.documentos.length === 1 ? "" : "s"}`;
  el.docList.innerHTML = "";

  if (lista.length === 0) {
    el.emptyState.hidden = false;
    return;
  }
  el.emptyState.hidden = true;

  const fragment = document.createDocumentFragment();

  lista.forEach((doc) => {
    const info = TIPO_INFO[doc.tipo] || { label: doc.tipo, abbr: "?" };

    const item = document.createElement("li");
    item.className = `doc-item type-${doc.tipo}`;
    item.dataset.id = doc.id;
    item.setAttribute("role", "option");
    item.setAttribute("aria-selected", doc.id === state.actualId ? "true" : "false");
    if (doc.id === state.actualId) item.classList.add("is-active");

    item.innerHTML = `
      <span class="chip">${info.abbr}</span>
      <span class="info">
        <span class="name">${escapeHtml(doc.nombre)}</span>
        <span class="meta">
          <span>${escapeHtml(doc.cliente)}</span>
          <span class="dot">·</span>
          <span>${formatoFecha(doc.fecha, true)}</span>
        </span>
      </span>
    `;

    item.addEventListener("click", () => {
      seleccionarDocumento(doc.id);
      cerrarSidebarMovil();
    });

    fragment.appendChild(item);
  });

  el.docList.appendChild(fragment);
}

/* ============================================================
   FILTRAR DOCUMENTOS
   ============================================================ */
function filtrarDocumentos(query) {
  const q = normalizarTexto(query.trim());

  if (q === "") {
    state.filtrados = state.documentos;
  } else {
    state.filtrados = state.documentos.filter((doc) => {
      const tipoLabel = TIPO_INFO[doc.tipo]?.label || doc.tipo;
      const campos = [
        doc.nombre,
        doc.cliente,
        doc.ruc,
        tipoLabel,
        doc.tipo,
        doc.fecha,
        formatoFecha(doc.fecha, false)
      ];
      return campos.some((campo) => normalizarTexto((campo || "").toString()).includes(q));
    });
  }

  renderizarIndice(state.filtrados);
}

/* ============================================================
   SELECCIONAR DOCUMENTO
   ============================================================ */
function seleccionarDocumento(id) {
  const doc = state.documentos.find((d) => d.id === id);
  if (!doc) return;

  state.actualId = id;

  // Resaltar el ítem correspondiente en el índice
  document.querySelectorAll(".doc-item").forEach((li) => {
    const activo = Number(li.dataset.id) === id;
    li.classList.toggle("is-active", activo);
    li.setAttribute("aria-selected", activo ? "true" : "false");
  });

  renderizarDocumento(doc);
  actualizarIndicador();
  document.getElementById("viewerCanvas").scrollTop = 0;
}

/* ============================================================
   RENDERIZAR DOCUMENTO (panel derecho — hoja A4)
   ============================================================ */
function renderizarDocumento(doc) {
  const info = TIPO_INFO[doc.tipo] || { label: doc.tipo, abbr: "?" };

  let cuerpo = "";
  switch (doc.tipo) {
    case "factura":
      cuerpo = plantillaFactura(doc);
      break;
    case "nota_credito":
      cuerpo = plantillaNotaCredito(doc);
      break;
    case "presupuesto":
      cuerpo = plantillaPresupuesto(doc);
      break;
    case "recibo":
      cuerpo = plantillaRecibo(doc);
      break;
    case "orden_compra":
      cuerpo = plantillaOrdenCompra(doc);
      break;
    default:
      cuerpo = `<p>Tipo de documento no soportado: ${escapeHtml(doc.tipo)}</p>`;
  }

  el.sheet.innerHTML = `
    <div class="sheet-tipo-bar type-${doc.tipo}"></div>
    <div class="sheet-inner">
      <div class="sheet-seal type-${doc.tipo}">${info.abbr}</div>

      <div class="doc-header">
        <div class="emisor">
          <h2>${escapeHtml(EMISOR.nombre)}</h2>
          <p>
            RUC: ${escapeHtml(EMISOR.ruc)} &nbsp;·&nbsp; Timbrado: ${escapeHtml(EMISOR.timbrado)}<br>
            ${escapeHtml(EMISOR.direccion)}<br>
            ${escapeHtml(EMISOR.telefono)}
          </p>
        </div>
        <div class="doc-title-block">
          <span class="tipo-label type-${doc.tipo}">${info.label}</span>
          <div class="numero">N° ${escapeHtml(doc.numero || "—")}</div>
          <div class="fecha">${formatoFecha(doc.fecha, false)}</div>
        </div>
      </div>

      ${cuerpo}

      <div class="sheet-footer">
        <span>${info.label} generada por el sistema de gestión documental</span>
        <span>${escapeHtml(doc.nombre)}</span>
      </div>
    </div>
  `;
}

/* ---------- Plantilla: Factura ---------- */
function plantillaFactura(doc) {
  const c = doc.contenido;
  return `
    <div class="party-block">
      <div class="field">
        <div class="label">Cliente</div>
        <div class="value">${escapeHtml(doc.cliente)}</div>
        <div class="value sub">RUC: ${escapeHtml(doc.ruc)}</div>
      </div>
      <div class="field">
        <div class="label">Condición de pago</div>
        <div class="value">${escapeHtml(c.condicion_pago || "Contado")}</div>
      </div>
    </div>

    <table class="doc-table">
      <thead>
        <tr>
          <th>Descripción</th>
          <th class="num">Cant.</th>
          <th class="num">Precio unit.</th>
          <th class="num">Total</th>
        </tr>
      </thead>
      <tbody>
        ${c.productos.map((p) => `
          <tr>
            <td>${escapeHtml(p.descripcion)}</td>
            <td class="num">${p.cantidad}</td>
            <td class="num">${formatoGs(p.precio)}</td>
            <td class="num">${formatoGs(p.precio * p.cantidad)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>

    <div class="totales">
      <div class="row"><span>Subtotal</span><span>${formatoGs(c.subtotal)}</span></div>
      <div class="row"><span>IVA (10%)</span><span>${formatoGs(c.iva)}</span></div>
      <div class="row total"><span>Total</span><span>${formatoGs(c.total)}</span></div>
    </div>
  `;
}

/* ---------- Plantilla: Nota de Crédito ---------- */
function plantillaNotaCredito(doc) {
  const c = doc.contenido;
  return `
    <div class="party-block">
      <div class="field">
        <div class="label">Cliente</div>
        <div class="value">${escapeHtml(doc.cliente)}</div>
        <div class="value sub">RUC: ${escapeHtml(doc.ruc)}</div>
      </div>
      <div class="field">
        <div class="label">Factura relacionada</div>
        <div class="value">${escapeHtml(c.factura_referencia || "—")}</div>
      </div>
    </div>

    <div class="nota-block">
      <div class="label">Motivo</div>
      ${escapeHtml(c.motivo)}
    </div>

    <table class="doc-table">
      <thead>
        <tr>
          <th>Descripción</th>
          <th class="num">Cant.</th>
          <th class="num">Precio unit.</th>
          <th class="num">Total</th>
        </tr>
      </thead>
      <tbody>
        ${c.productos.map((p) => `
          <tr>
            <td>${escapeHtml(p.descripcion)}</td>
            <td class="num">${p.cantidad}</td>
            <td class="num">${formatoGs(p.precio)}</td>
            <td class="num">${formatoGs(p.precio * p.cantidad)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>

    <div class="totales">
      <div class="row"><span>Subtotal</span><span>${formatoGs(c.subtotal)}</span></div>
      <div class="row"><span>IVA (10%)</span><span>${formatoGs(c.iva)}</span></div>
      <div class="row total"><span>Total acreditado</span><span>${formatoGs(c.total)}</span></div>
    </div>
  `;
}

/* ---------- Plantilla: Presupuesto ---------- */
function plantillaPresupuesto(doc) {
  const c = doc.contenido;
  return `
    <div class="party-block">
      <div class="field">
        <div class="label">Cliente</div>
        <div class="value">${escapeHtml(doc.cliente)}</div>
        <div class="value sub">RUC: ${escapeHtml(doc.ruc)}</div>
      </div>
      <div class="field">
        <div class="label">Validez de la oferta</div>
        <div class="value">${c.validez_dias} días</div>
      </div>
    </div>

    <table class="doc-table">
      <thead>
        <tr>
          <th>Descripción</th>
          <th class="num">Cant.</th>
          <th class="num">Precio unit.</th>
          <th class="num">Total</th>
        </tr>
      </thead>
      <tbody>
        ${c.productos.map((p) => `
          <tr>
            <td>${escapeHtml(p.descripcion)}</td>
            <td class="num">${p.cantidad}</td>
            <td class="num">${formatoGs(p.precio)}</td>
            <td class="num">${formatoGs(p.precio * p.cantidad)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>

    <div class="totales">
      <div class="row"><span>Subtotal</span><span>${formatoGs(c.subtotal)}</span></div>
      ${c.descuento ? `<div class="row"><span>Descuento</span><span>−${formatoGs(c.descuento)}</span></div>` : ""}
      <div class="row"><span>IVA (10%)</span><span>${formatoGs(c.iva)}</span></div>
      <div class="row total"><span>Total estimado</span><span>${formatoGs(c.total)}</span></div>
    </div>

    ${c.condiciones ? `
      <div class="nota-block">
        <div class="label">Condiciones</div>
        ${escapeHtml(c.condiciones)}
      </div>
    ` : ""}
  `;
}

/* ---------- Plantilla: Recibo ---------- */
function plantillaRecibo(doc) {
  const c = doc.contenido;
  return `
    <div class="party-block">
      <div class="field">
        <div class="label">Recibí de</div>
        <div class="value">${escapeHtml(doc.cliente)}</div>
        <div class="value sub">RUC: ${escapeHtml(doc.ruc)}</div>
      </div>
      <div class="field">
        <div class="label">Forma de pago</div>
        <div class="value">${escapeHtml(c.forma_pago)}</div>
      </div>
    </div>

    <div class="recibo-monto">
      <div class="label">Monto recibido</div>
      <div class="cifra">${formatoGs(c.monto)}</div>
    </div>

    <p class="recibo-texto">
      La suma de guaraníes indicada corresponde al siguiente concepto:
      <span class="concepto">"${escapeHtml(c.concepto)}"</span>
    </p>

    <div class="firma-line">
      <div>Firma y aclaración</div>
      <div>Sello</div>
    </div>
  `;
}

/* ---------- Plantilla: Orden de Compra ---------- */
function plantillaOrdenCompra(doc) {
  const c = doc.contenido;
  return `
    <div class="party-block">
      <div class="field">
        <div class="label">Proveedor</div>
        <div class="value">${escapeHtml(doc.cliente)}</div>
        <div class="value sub">RUC: ${escapeHtml(doc.ruc)}</div>
      </div>
      <div class="field">
        <div class="label">Plazo de entrega</div>
        <div class="value">${escapeHtml(c.plazo_entrega || "—")}</div>
      </div>
    </div>

    <table class="doc-table">
      <thead>
        <tr>
          <th>Descripción</th>
          <th class="num">Cant.</th>
          <th class="num">Precio unit.</th>
          <th class="num">Total</th>
        </tr>
      </thead>
      <tbody>
        ${c.items.map((p) => `
          <tr>
            <td>${escapeHtml(p.descripcion)}</td>
            <td class="num">${p.cantidad}</td>
            <td class="num">${formatoGs(p.precio_unitario)}</td>
            <td class="num">${formatoGs(p.precio_unitario * p.cantidad)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>

    <div class="totales">
      <div class="row"><span>Subtotal</span><span>${formatoGs(c.subtotal)}</span></div>
      <div class="row"><span>IVA (10%)</span><span>${formatoGs(c.iva)}</span></div>
      <div class="row total"><span>Total de la orden</span><span>${formatoGs(c.total)}</span></div>
    </div>

    ${c.condiciones ? `
      <div class="nota-block">
        <div class="label">Condiciones de entrega</div>
        ${escapeHtml(c.condiciones)}
      </div>
    ` : ""}
  `;
}

/* ============================================================
   NAVEGACIÓN ENTRE DOCUMENTOS
   ============================================================ */
function navegarDocumento(direccion) {
  const lista = state.filtrados.length ? state.filtrados : state.documentos;
  const indexActual = lista.findIndex((d) => d.id === state.actualId);
  if (indexActual === -1) return;

  const nuevoIndex = indexActual + direccion;
  if (nuevoIndex < 0 || nuevoIndex >= lista.length) return;

  seleccionarDocumento(lista[nuevoIndex].id);
}

function actualizarIndicador() {
  const lista = state.filtrados.length ? state.filtrados : state.documentos;
  const indexActual = lista.findIndex((d) => d.id === state.actualId);

  if (indexActual === -1) {
    el.docIndicator.textContent = "—";
    el.prevBtn.disabled = true;
    el.nextBtn.disabled = true;
    return;
  }

  el.docIndicator.textContent = `Documento ${indexActual + 1} de ${lista.length}`;
  el.prevBtn.disabled = indexActual === 0;
  el.nextBtn.disabled = indexActual === lista.length - 1;
}

/* ============================================================
   IMPRIMIR / GUARDAR PDF
   ============================================================ */
function imprimir() {
  window.print();
}

/* ============================================================
   UTILIDADES
   ============================================================ */
function formatoGs(numero) {
  return "₲ " + Math.round(numero).toLocaleString("es-PY");
}

function formatoFecha(fechaISO, corta) {
  const fecha = new Date(fechaISO + "T00:00:00");
  const opciones = corta
    ? { day: "2-digit", month: "short", year: "numeric" }
    : { day: "2-digit", month: "long", year: "numeric" };
  return fecha.toLocaleDateString("es-PY", opciones);
}

function normalizarTexto(texto) {
  return texto
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function escapeHtml(valor) {
  const div = document.createElement("div");
  div.textContent = valor ?? "";
  return div.innerHTML;
}

/* ---------- Sidebar móvil ---------- */
function abrirSidebarMovil() {
  el.app.classList.add("sidebar-open");
}
function cerrarSidebarMovil() {
  el.app.classList.remove("sidebar-open");
}

/* ============================================================
   EVENTOS
   ============================================================ */
el.searchInput.addEventListener("input", (e) => filtrarDocumentos(e.target.value));
el.prevBtn.addEventListener("click", () => navegarDocumento(-1));
el.nextBtn.addEventListener("click", () => navegarDocumento(1));
el.printBtn.addEventListener("click", imprimir);
el.sidebarToggle.addEventListener("click", abrirSidebarMovil);
el.sidebarClose.addEventListener("click", cerrarSidebarMovil);
el.sidebarScrim.addEventListener("click", cerrarSidebarMovil);

document.addEventListener("keydown", (e) => {
  const enCampoDeTexto = document.activeElement === el.searchInput;
  if (enCampoDeTexto) return;
  if (e.key === "ArrowLeft") navegarDocumento(-1);
  if (e.key === "ArrowRight") navegarDocumento(1);
});

/* ---------- Arranque ---------- */
document.addEventListener("DOMContentLoaded", cargarDocumentos);
