let documentos=[], filtrados=[], seleccionado=null;

const $ = s => document.querySelector(s);
const tipoInfo = {
  factura:{icon:"🧾", label:"Factura"},
  nota_credito:{icon:"↩️", label:"Nota de crédito"},
  presupuesto:{icon:"📋", label:"Presupuesto"},
  recibo:{icon:"🧾", label:"Recibo"},
  orden_compra:{icon:"🛒", label:"Orden de compra"}
};

function moneda(v){return new Intl.NumberFormat("es-PY",{minimumFractionDigits:0,maximumFractionDigits:0}).format(v);}
function fecha(v){return new Intl.DateTimeFormat("es-PY",{year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date(v+"T12:00:00"));}

async function cargarDocumentos(){
  try{
    const r=await fetch("documentos.json");
    if(!r.ok) throw new Error("No se pudo cargar documentos.json");
    const data=await r.json();
    documentos=data.documentos||[];
    filtrados=[...documentos];
    $("#contador").textContent=`${documentos.length} documentos`;
    renderizarIndice();
    if(documentos.length) seleccionarDocumento(documentos[0].id);
    else mostrarVacio("No hay documentos disponibles.");
  }catch(e){
    $("#canvas").innerHTML=`<div class="empty">No se pudo cargar el JSON.<br><br>Si abriste el HTML directamente con <b>file://</b>, usa un servidor local.</div>`;
  }
}

function renderizarIndice(){
  const lista=$("#listaDocumentos");
  if(!filtrados.length){lista.innerHTML='<div class="empty">No se encontraron documentos.</div>';return;}
  lista.innerHTML=filtrados.map(d=>{
    const t=tipoInfo[d.tipo]||{icon:"📄",label:d.tipo};
    return `<div class="doc-item ${d.id===seleccionado?"active":""}" data-id="${d.id}">
      <div class="doc-icon">${t.icon}</div>
      <div class="doc-info">
        <div class="doc-name">${esc(d.nombre)}</div>
        <div class="doc-meta">${t.label} · ${fecha(d.fecha)}</div>
      </div>
    </div>`;
  }).join("");
  lista.querySelectorAll(".doc-item").forEach(el=>el.addEventListener("click",()=>seleccionarDocumento(Number(el.dataset.id))));
}

function filtrarDocumentos(){
  const q=$("#buscador").value.trim().toLowerCase();
  filtrados=documentos.filter(d=>{
    const texto=[d.nombre,d.cliente,d.ruc,d.tipo,d.fecha,tipoInfo[d.tipo]?.label||""].join(" ").toLowerCase();
    return texto.includes(q);
  });
  renderizarIndice();
}

function seleccionarDocumento(id){
  seleccionado=id;
  const d=documentos.find(x=>x.id===id);
  if(!d)return;
  renderizarIndice();
  renderizarDocumento(d);
  const index=documentos.findIndex(x=>x.id===id);
  $("#posicionDocumento").textContent=`Documento ${index+1} de ${documentos.length}`;
  $("#anterior").disabled=index<=0;
  $("#siguiente").disabled=index>=documentos.length-1;
}

function renderizarDocumento(d){
  const t=tipoInfo[d.tipo]||{label:d.tipo};
  const productos=d.contenido?.productos||[];
  $("#tituloDocumento").textContent=d.nombre;
  $("#canvas").innerHTML=`<article class="paper">
    <div class="paper-header">
      <div class="company">
        <h2>Mi Empresa S.A.</h2>
        <p>RUC: 80012345-6</p><p>Av. España 1234 · Asunción, Paraguay</p><p>Tel.: 021 123 456</p>
      </div>
      <div class="doc-head">
        <h2>${t.label}</h2>
        <p><strong>${esc(d.nombre)}</strong></p>
        <p>Fecha: ${fecha(d.fecha)}</p>
      </div>
    </div>
    <div class="client">
      <div><strong>Cliente:</strong>${esc(d.cliente)}</div>
      <div><strong>RUC:</strong>${esc(d.ruc)}</div>
      <div><strong>Documento:</strong>${esc(d.nombre)}</div>
    </div>
    <table>
      <thead><tr><th>Descripción</th><th class="right">Cantidad</th><th class="right">Precio</th><th class="right">Subtotal</th></tr></thead>
      <tbody>${productos.map(p=>`<tr><td>${esc(p.descripcion)}</td><td class="right">${p.cantidad}</td><td class="right">${moneda(p.precio)}</td><td class="right">${moneda(p.cantidad*p.precio)}</td></tr>`).join("")}</tbody>
    </table>
    <table class="totals">
      <tr><td>Subtotal</td><td class="right">${moneda(d.contenido.subtotal)}</td></tr>
      <tr><td>IVA</td><td class="right">${moneda(d.contenido.iva)}</td></tr>
      <tr class="grand"><td>TOTAL</td><td class="right">${moneda(d.contenido.total)}</td></tr>
    </table>
    <div class="paper-footer">Documento generado a partir de datos JSON · ${t.label}</div>
  </article>`;
}

function esc(v){
  return String(v??"").replace(/[&<>"']/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[m]));
}
function mostrarVacio(t){$("#canvas").innerHTML=`<div class="empty">${t}</div>`;}

function mover(delta){
  const i=documentos.findIndex(d=>d.id===seleccionado);
  const nuevo=documentos[i+delta];
  if(nuevo) seleccionarDocumento(nuevo.id);
}

$("#buscador").addEventListener("input",filtrarDocumentos);
$("#anterior").addEventListener("click",()=>mover(-1));
$("#siguiente").addEventListener("click",()=>mover(1));
$("#imprimir").addEventListener("click",()=>window.print());
$("#openSidebar").addEventListener("click",()=>$("#sidebar").classList.add("open"));
$("#closeSidebar").addEventListener("click",()=>$("#sidebar").classList.remove("open"));
$("#listaDocumentos").addEventListener("click",()=>$("#sidebar").classList.remove("open"));

cargarDocumentos();
