/* ═══ MÓDULOS Y DATOS ═══ */
const MODULES={
  cats:{
    prefix:'CAT', sec:'Inventario', title:'Categorías', desc:'Organiza tu inventario agrupando productos por categoría.',
    newBtn:'Nueva Categoría', colLabel:'Productos', hasEmail:false,
    items:[
      {id:'CAT-001',name:'Bebidas',        desc:'Gaseosas, jugos, aguas y energizantes', col:48, st:true},
      {id:'CAT-002',name:'Lácteos',        desc:'Leche, quesos, yogures y mantequillas', col:32, st:true},
      {id:'CAT-003',name:'Panadería',      desc:'Pan fresco, bollería y pasteles',       col:21, st:true},
      {id:'CAT-004',name:'Aseo del hogar', desc:'Detergentes, jabones y limpiadores',    col:27, st:true},
      {id:'CAT-005',name:'Snacks',         desc:'Papas, galletas, chocolates y dulces',  col:39, st:false},
      {id:'CAT-006',name:'Carnes y fríos', desc:'Cortes frescos, embutidos y congelados',col:18, st:true},
      {id:'CAT-007',name:'Frutas y verduras',desc:'Producción fresca de temporada',      col:44, st:true},
      {id:'CAT-008',name:'Limpieza personal',desc:'Jabones, shampus e higiene diaria',   col:26, st:false},
    ]},
  clientes:{
    prefix:'CLI', sec:'Operación', title:'Clientes', desc:'Administra los clientes de tu negocio y sus datos de contacto.',
    newBtn:'Nuevo Cliente', colLabel:'Compras', hasEmail:true,
    items:[
      {id:'CLI-001',name:'María González',  desc:'Cliente frecuente desde 2022',   col:24, st:true, email:'maria@correo.com'},
      {id:'CLI-002',name:'Carlos López',    desc:'Compra mensual al por mayor',    col:11, st:true, email:'carlos@correo.com'},
      {id:'CLI-003',name:'Ana Torres',      desc:'Cliente enterprise',             col:52, st:true, email:'ana@empresa.com'},
      {id:'CLI-004',name:'Jorge Fernández', desc:'Cuenta suspendida por mora',     col:3,  st:false,email:'jorge@correo.com'},
      {id:'CLI-005',name:'Lucía Ramírez',   desc:'Nueva cliente este mes',         col:2,  st:true, email:'lucia@correo.com'},
      {id:'CLI-006',name:'Pedro Sánchez',   desc:'Cliente mayorista de la zona',   col:18, st:true, email:'pedro@mayorista.com'},
    ]},
  usuarios:{
    prefix:'USR', sec:'Gestión', title:'Usuarios', desc:'Gestiona las cuentas con acceso al sistema.',
    newBtn:'Nuevo Usuario', colLabel:'Sesiones', hasEmail:true,
    items:[
      {id:'USR-001',name:'Alex Rivera',    desc:'Administrador del sistema',        col:214, st:true, email:'alex@tumarca.io'},
      {id:'USR-002',name:'Carla Méndez',   desc:'Vendedora — Sucursal Centro',      col:98,  st:true, email:'carla@tumarca.io'},
      {id:'USR-003',name:'Diego Ortiz',    desc:'Bodeguero — Almacén principal',    col:64,  st:true, email:'diego@tumarca.io'},
      {id:'USR-004',name:'Sofía Vega',     desc:'Contadora — Acceso restringido',   col:41,  st:false,email:'sofia@tumarca.io'},
      {id:'USR-005',name:'Miguel Ruiz',    desc:'Supervisor de ventas',             col:127, st:true, email:'miguel@tumarca.io'},
    ]},
  empleados:{
    prefix:'EMP', sec:'Gestión', title:'Empleados', desc:'Registro del personal de la organización.',
    newBtn:'Nuevo Empleado', colLabel:'Años', hasEmail:true,
    items:[
      {id:'EMP-001',name:'Rosa Jiménez',  desc:'Gerente general',            col:6, st:true,  email:'rosa@tumarca.io'},
      {id:'EMP-002',name:'Luis Castro',   desc:'Jefe de almacén',            col:4, st:true,  email:'luis@tumarca.io'},
      {id:'EMP-003',name:'Elena Paredes', desc:'Contadora senior',           col:8, st:true,  email:'elena@tumarca.io'},
      {id:'EMP-004',name:'Tomás Herrera', desc:'Vendedor — en vacaciones',   col:2, st:false, email:'tomas@tumarca.io'},
      {id:'EMP-005',name:'Paula Navarro', desc:'Asistente administrativa',   col:3, st:true,  email:'paula@tumarca.io'},
      {id:'EMP-006',name:'Andrés Molina', desc:'Repartidor — turno noche',   col:1, st:true,  email:'andres@tumarca.io'},
    ]},
};

let curModule='cats';
let nextNs={};
Object.keys(MODULES).forEach(k=>nextNs[k]=MODULES[k].items.length+1);

/* ═══ NAVEGACIÓN ENTRE VISTAS ═══ */
const viewDash=document.getElementById('viewDash'),
      viewList=document.getElementById('viewList'),
      viewForm=document.getElementById('viewForm'),
      viewError=document.getElementById('viewError'),
      crumbHere=document.getElementById('crumbHere'),
      crumbSec=document.getElementById('crumbSec'),
      inpSearch=document.getElementById('inpSearch');

function triggerViewAnimation(viewEl) {
  viewEl.style.animation = 'none';
  viewEl.offsetHeight;
  viewEl.style.animation = 'fadeInUp 0.35s cubic-bezier(0.2, 0.9, 0.3, 1.15) forwards';
}

function showList(){
  viewDash.hidden=true;
  viewForm.hidden=true;
  viewError.hidden=true;
  viewList.hidden=false;
  triggerViewAnimation(viewList);
}

// NUEVO: Variable para controlar el modo del formulario
let formMode = 'edit'; // 'edit' o 'view'

function showForm(id, mode='edit'){
  editingId=id||null;
  formMode = mode; 
  const M=MODULES[curModule];
  const f=document.getElementById('fName'),
        d=document.getElementById('fDesc'),
        em=document.getElementById('fEmail'),
        sw=document.getElementById('fActive');
  const btnSave=document.getElementById('btnSave');
  const btnEdit=document.getElementById('btnEditFromDetails');
  
  document.getElementById('fErr').classList.remove('show');
  f.classList.remove('error');
  document.getElementById('fEmail').parentElement.style.display=M.hasEmail?'block':'none';
  
  if(id){
    const it=M.items.find(x=>x.id===id);
    
    if(formMode === 'view'){
      // MODO DETALLES (solo lectura)
      document.getElementById('formTitle').textContent=`Detalles de ${M.title.replace(/s$/,'')}`;
      document.getElementById('formSub').textContent=`Visualizando ${it.id} — Haz clic en "Editar" para modificar.`;
      document.getElementById('formNote').textContent=`ID: ${it.id}`;
      
      // Activar modo solo lectura en los campos
      f.classList.add('readonly');
      d.classList.add('readonly');
      em.classList.add('readonly');
      sw.classList.add('readonly');
      
      // Ocultar botón Guardar, mostrar botón Editar
      btnSave.hidden = true;
      btnEdit.hidden = false;
    } else {
      // MODO EDICIÓN
      document.getElementById('formTitle').textContent=`Editar ${M.title.replace(/s$/,'')}`;
      document.getElementById('formSub').textContent=`Modificando ${it.id} — los cambios se aplican al guardar.`;
      document.getElementById('formNote').textContent=`Editando: ${it.name}`;
      
      // Quitar modo solo lectura
      f.classList.remove('readonly');
      d.classList.remove('readonly');
      em.classList.remove('readonly');
      sw.classList.remove('readonly');
      
      // Mostrar botón Guardar, ocultar botón Editar
      btnSave.hidden = false;
      btnEdit.hidden = true;
    }
    
    f.value=it.name;
    d.value=it.desc;
    sw.checked=it.st;
    em.value=it.email||'';
    crumbHere.textContent=formMode === 'view' ? `Detalles ${it.id}` : `Editar ${M.title.replace(/s$/,'')}`;
  }else{
    document.getElementById('formTitle').textContent=M.newBtn;
    document.getElementById('formSub').textContent=M.desc;
    document.getElementById('formNote').textContent='';
    f.value='';
    d.value='';
    sw.checked=true;
    em.value='';
    crumbHere.textContent=M.newBtn;
    
    f.classList.remove('readonly');
    d.classList.remove('readonly');
    em.classList.remove('readonly');
    sw.classList.remove('readonly');
    btnSave.hidden = false;
    btnEdit.hidden = true;
  }
  document.getElementById('btnSaveTxt').textContent=`Guardar ${M.title.replace(/s$/,'')}`;
  viewDash.hidden=true;
  viewList.hidden=true;
  viewError.hidden=true;
  viewForm.hidden=false;
  triggerViewAnimation(viewForm);
  window.scrollTo({top:0,behavior:'smooth'});
  if(formMode === 'edit') setTimeout(()=>f.focus(),150);
}

function showErr(name){
  viewDash.hidden=true;
  viewList.hidden=true;
  viewForm.hidden=true;
  viewError.hidden=false;
  crumbHere.textContent=name;
  document.getElementById('errTitle').textContent=`${name} no está disponible`;
  document.getElementById('errMsg').textContent='Esta sección del prototipo aún no tiene una vista implementada. Vuelve al inicio o reintenta más tarde.';
  document.getElementById('bulkbar').classList.remove('show');
  triggerViewAnimation(viewError);
  window.scrollTo({top:0,behavior:'smooth'});
}

function showDash(){
  viewList.hidden=true;
  viewForm.hidden=true;
  viewError.hidden=true;
  viewDash.hidden=false;
  triggerViewAnimation(viewDash);
}

function activateSide(btn){
  document.querySelectorAll('.nav-item,.sub-item,.group-btn').forEach(x=>x.classList.remove('active'));
  btn.classList.add('active');
  const grp=btn.closest('.group');
  if(grp)grp.querySelector('.group-btn').classList.add('active');
}

/* Navegación unificada */
document.querySelectorAll('.nav-item,.sub-item').forEach(b=>b.addEventListener('click',()=>{
  const name=b.querySelector('span')?.textContent.trim()||'Sección';
  activateSide(b);
  
  if(b.dataset.view==='dash'){
    showDash();
    if(typeof renderDash==='function') renderDash();
    document.getElementById('sidebar').classList.remove('open');
    document.getElementById('scrim').classList.remove('show');
    return;
  }
  
  if(b.classList.contains('nav-item')){
    document.querySelectorAll('.group.open').forEach(x=>x.classList.remove('open'));
  }
  
  const v=b.dataset.view;
  if(v){
    curModule=v;
    const M=MODULES[v];
    document.getElementById('listTitle').textContent=M.title;
    document.getElementById('listDesc').textContent=M.desc;
    document.getElementById('btnNew').textContent=M.newBtn;
    document.getElementById('panelTitle').textContent=`Listado de ${M.title.toLowerCase()}`;
    document.getElementById('thCol').textContent=M.colLabel;
    inpSearch.placeholder=`Buscar en ${M.title.toLowerCase()}…`;
    crumbSec.style.display='';
    crumbSec.textContent=M.sec;
    crumbHere.textContent=M.title;
    stFilter='all';
    page=1;
    selected.clear();
    inpSearch.value='';
    if(typeof fsOrderSel!=='undefined') fsOrderSel.set('default');
    fOrder.value='default';
    document.getElementById('btnClear').hidden=true;
    showList();
    renderWithSkeleton(700);
  }else{
    showErr(name);
  }
  
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('scrim').classList.remove('show');
}));

document.getElementById('btnErrHome').onclick=()=>{
  document.querySelector('[data-view="dash"]').click();
};

document.getElementById('btnRetry').onclick=()=>toast('info','Reintentando','Aquí se repetiría la petición al servidor.');
document.getElementById('btnBack').onclick=()=>showList();
document.getElementById('btnCancel').onclick=()=>showList();

// NUEVO: Botón "Editar" en modo detalles
document.getElementById('btnEditFromDetails').onclick = () => {
  if(editingId) showForm(editingId, 'edit');
};

/* ══ DASHBOARD ═══ */
let dashRange={value:7};

function fmtMoney(n){return '$'+Math.round(n).toLocaleString('es-CO')}

const fsRangeSel=initFsel('fsRange',val=>{
  dashRange.value=val;
  if(typeof renderDash==='function') renderDash();
});

function renderDash(){
  const M=MODULES;
  const clientesOn=M.clientes.items.filter(c=>c.st).length;
  const usersOn=M.usuarios.items.filter(u=>u.st).length;
  const totalProds=M.cats.items.reduce((a,c)=>a+c.col,0);

  document.getElementById('mClientes').textContent=clientesOn;
  document.getElementById('mClientesTot').textContent=M.clientes.items.length;
  document.getElementById('mProds').textContent=totalProds;
  document.getElementById('mCats').textContent=M.cats.items.length;
  document.getElementById('mUsers').textContent=M.usuarios.items.length;
  document.getElementById('mUsersOn').textContent=usersOn;

  const days=+dashRange.value;
  let seed=42*days;
  const rnd=()=>{seed=(seed*9301+49297)%233280;return seed/233280};
  const sales=[];
  for(let i=0;i<days;i++)sales.push(180000+rnd()*620000);
  const total=sales.reduce((a,b)=>a+b,0);
  document.getElementById('mVentas').textContent=fmtMoney(total);
  document.getElementById('chartTotal').innerHTML=`${fmtMoney(total)} <small>total</small>`;

  const half=Math.floor(days/2);
  const oldH=sales.slice(0,half).reduce((a,b)=>a+b,0);
  const newH=sales.slice(half).reduce((a,b)=>a+b,0);
  const delta=oldH?Math.round((newH-oldH)/oldH*100):0;
  const d1=document.getElementById('chartDelta'),d2=document.getElementById('mVentasDelta');
  [d1,d2].forEach(el=>{
    el.textContent=delta>=0?`↗ +${delta}%`:`↘ ${delta}%`;
    el.className='delta '+(delta>=0?'up':'down');
  });

  const W=600,H=170,PAD=12;
  const max=Math.max(...sales),min=Math.min(...sales);
  const lo=min-(max-min)*.15, hi=max+(max-min)*.15;
  const px=i=>days===1?W/2:(i/(days-1))*W;
  const py=v=>H-PAD-((v-lo)/(hi-lo))*(H-PAD*2);

  let grid='';
  for(let i=1;i<=3;i++){
    const y=(H/4)*i;
    grid+=`<line class="chart-grid-l" x1="0" y1="${y}" x2="${W}" y2="${y}"/>`;
  }
  document.getElementById('chartGrid').innerHTML=grid;

  const pts=sales.map((v,i)=>`${px(i).toFixed(1)},${py(v).toFixed(1)}`);
  document.getElementById('linePath').setAttribute('d','M'+pts.join(' L'));
  document.getElementById('areaPath').setAttribute('d',`M${pts.join(' L')} L${W},${H} L0,${H} Z`);

  const dots=document.getElementById('chartDots');
  dots.innerHTML=sales.map((v,i)=>`
    <div class="chart-dot" data-tip="${fmtMoney(v)}" style="left:${(px(i)/W*100)}%;top:${(py(v)/H*100)}%"></div>`).join('');

  const xl=document.getElementById('chartXLabels');
  if(days<=7){
    xl.style.display='flex';
    xl.innerHTML=['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'].slice(0,days).map(l=>`<span>${l}</span>`).join('');
  }else{
    xl.style.display='none';
  }

  const top=[...M.cats.items].sort((a,b)=>b.col-a.col).slice(0,5);
  const maxCat=top[0]?.col||1;
  document.getElementById('topCats').innerHTML=top.map(c=>`
    <li>
      <div class="tc-row"><span class="n">${c.name}</span><span class="v">${c.col} productos</span></div>
      <div class="progress"><i style="width:${Math.round(c.col/maxCat*100)}%"></i></div>
    </li>`).join('');
}

/* ═══ TABLA GENÉRICA ═══ */
const tbody=document.getElementById('tbody'),
      emptyBox=document.getElementById('emptyBox'),
      btnClear=document.getElementById('btnClear'),
      footInfo=document.getElementById('footInfo'),
      pagerEl=document.getElementById('pager'),
      chkAll=document.getElementById('chkAll'),
      bulkbar=document.getElementById('bulkbar'),
      bulkCount=document.getElementById('bulkCount'),
      listTabs=document.getElementById('listTabs');

const PAGE_SIZE=5;
let page=1,stFilter='all',editingId=null,deletingId=null;
let fOrder={value:'default'};
let selected=new Set();

function getFiltered(){
  const M=MODULES[curModule];
  const q=inpSearch.value.trim().toLowerCase(), st=stFilter;
  let rows=M.items.filter(it=>
    (it.name.toLowerCase().includes(q)||it.desc.toLowerCase().includes(q)) &&
    (st==='all'||(st==='ok'?it.st:!it.st)));
  if(fOrder.value==='name') rows=[...rows].sort((a,b)=>a.name.localeCompare(b.name));
  if(fOrder.value==='prods')rows=[...rows].sort((a,b)=>b.col-a.col);
  return rows;
}

function skeletonRows(){
  const widths=[['45px','60%','40px','90px','31px'],['52px','75%','36px','90px','31px'],
    ['40px','55%','44px','90px','31px'],['58px','68%','38px','90px','31px'],['46px','62%','42px','90px','31px']];
  return widths.map(w=>`
    <tr class="skel-row">
      <td class="c-chk"><span class="skel" style="width:16px;height:16px;border-radius:4px;display:block"></span></td>
      <td class="c-id"><span class="skel" style="width:${w[0]}"></span></td>
      <td><span class="skel" style="width:${w[1]};display:block"></span><span class="skel" style="width:${w[1]};display:block;margin-top:7px;height:9px;opacity:.6"></span></td>
      <td class="c-prods"><span class="skel" style="width:${w[2]}"></span></td>
      <td class="c-state"><span class="skel" style="width:70px;border-radius:8px"></span></td>
      <td class="c-actions"><span class="skel" style="width:${w[4]};border-radius:8px"></span></td>
    </tr>`).join('');
}

function syncBulkbar(){
  const n=selected.size;
  bulkCount.textContent=`${n} seleccionado${n!==1?'s':''}`;
  bulkbar.classList.toggle('show',n>0 && !viewList.hidden);
  chkAll.checked=pageItems().length>0 && pageItems().every(it=>selected.has(it.id));
}

function pageItems(){
  const rows=getFiltered();
  const totalPages=Math.max(1,Math.ceil(rows.length/PAGE_SIZE));
  const p=Math.min(page,totalPages);
  return rows.slice((p-1)*PAGE_SIZE,p*PAGE_SIZE);
}

function syncTabs(){
  listTabs.querySelectorAll('.tab').forEach(t=>t.classList.toggle('on',t.dataset.tab===stFilter));
  const M=MODULES[curModule];
  document.getElementById('tcAll').textContent=M.items.length;
  document.getElementById('tcOk').textContent=M.items.filter(x=>x.st).length;
  document.getElementById('tcOff').textContent=M.items.filter(x=>!x.st).length;
}

function render(){
  const M=MODULES[curModule];
  const rows=getFiltered();
  const total=rows.length;
  const totalPages=Math.max(1,Math.ceil(total/PAGE_SIZE));
  if(page>totalPages)page=totalPages;
  const start=(page-1)*PAGE_SIZE;
  const view=rows.slice(start,start+PAGE_SIZE);

  tbody.innerHTML=view.map(it=>`
    <tr class="${selected.has(it.id)?'selected':''}">
      <td class="c-chk"><input type="checkbox" data-chk="${it.id}" ${selected.has(it.id)?'checked':''}></td>
      <td class="c-id"><span class="id-cell" data-view-id="${it.id}" title="Clic para ver detalles">${it.id}</span></td>
      <td class="cell-name"><b>${it.name}</b><span>${it.desc}</span></td>
      <td class="qty c-prods">${it.col}</td>
      <td class="c-state"><span class="status ${it.st?'ok':'off'}">${it.st?'Activo':'Inactivo'}</span></td>
      <td class="c-actions"><div class="row-actions">
        <button class="kebab" data-kebab><svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="1.7"/><circle cx="12" cy="12" r="1.7"/><circle cx="12" cy="19" r="1.7"/></svg></button>
        <div class="dd glass-deep">
          <button data-edit="${it.id}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4z"/></svg>Editar</button>
          <button class="danger" data-del="${it.id}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>Eliminar</button>
        </div>
      </div></td>
    </tr>`).join('');

  const noResults=total===0;
  emptyBox.classList.toggle('show',noResults);
  document.querySelector('.table-wrap').style.display=noResults?'none':'block';
  if(noResults){
    const filtered=inpSearch.value.trim()||stFilter!=='all';
    document.getElementById('emptyTitle').textContent=filtered?'Sin resultados':`No hay ${M.title.toLowerCase()} aún`;
    document.getElementById('emptyMsg').textContent=filtered
      ?'Ningún registro coincide con los filtros aplicados. Prueba con otros términos o límpialos.'
      :`Crea el primero para comenzar.`;
  }

  footInfo.textContent=total===0?'Sin resultados'
    :`Mostrando ${start+1}–${Math.min(start+PAGE_SIZE,total)} de ${total} registro${total!==1?'s':''}`;
  btnClear.hidden=!(inpSearch.value.trim()||stFilter!=='all'||fOrder.value!=='default');

  let html=`<button ${page===1?'disabled':''} data-pg="prev" title="Anterior">‹</button>`;
  for(let i=1;i<=totalPages;i++)html+=`<button class="${i===page?'on':''}" data-pg="${i}">${i}</button>`;
  html+=`<button ${page===totalPages?'disabled':''} data-pg="next" title="Siguiente">›</button>`;
  pagerEl.innerHTML=html;

  syncBulkbar();
}

function renderWithSkeleton(delay=700){
  tbody.innerHTML=skeletonRows();
  setTimeout(render,delay);
}

listTabs.addEventListener('click',e=>{
  const t=e.target.closest('.tab');
  if(!t||t.classList.contains('on'))return;
  stFilter=t.dataset.tab;
  syncTabs();
  page=1;
  renderWithSkeleton(500);
});

inpSearch.addEventListener('input',()=>{
  page=1;
  renderWithSkeleton(500)
});

const fsOrderSel=initFsel('fsOrder',val=>{
  fOrder.value=val;
  page=1;
  renderWithSkeleton(500);
});

btnClear.onclick=()=>{
  inpSearch.value='';
  stFilter='all';
  fOrder.value='default';
  fsOrderSel.set('default');
  syncTabs();
  page=1;
  selected.clear();
  renderWithSkeleton(500);
  inpSearch.focus();
};

pagerEl.addEventListener('click',e=>{
  const b=e.target.closest('[data-pg]');
  if(!b||b.disabled)return;
  const v=b.dataset.pg;
  const totalPages=Math.max(1,Math.ceil(getFiltered().length/PAGE_SIZE));
  if(v==='prev')page=Math.max(1,page-1);
  else if(v==='next')page=Math.min(totalPages,page+1);
  else page=+v;
  renderWithSkeleton(400);
});

/* Selección múltiple */
chkAll.addEventListener('change',()=>{
  pageItems().forEach(it=>chkAll.checked?selected.add(it.id):selected.delete(it.id));
  render();
});

tbody.addEventListener('change',e=>{
  const cb=e.target.closest('[data-chk]');
  if(!cb)return;
  cb.checked?selected.add(cb.dataset.chk):selected.delete(cb.dataset.chk);
  render();
});

// NUEVO: Delegación de eventos para clic en ID
tbody.addEventListener('click', e => {
  const idCell = e.target.closest('[data-view-id]');
  if (idCell) {
    const id = idCell.dataset.viewId;
    showForm(id, 'view');
  }
});

/* Acciones masivas */
document.getElementById('bulkActivate').onclick=()=>{
  let n=0;
  selected.forEach(id=>{
    MODULES[curModule].items.forEach(it=>{
      if(it.id===id&&!it.st){it.st=true;n++}
    })
  });
  if(n)toast('ok','Registros activados',`${n} cambiaron a activo.`);
  selected.clear();
  render();
};

document.getElementById('bulkDeactivate').onclick=()=>{
  let n=0;
  selected.forEach(id=>{
    MODULES[curModule].items.forEach(it=>{
      if(it.id===id&&it.st){it.st=false;n++}
    })
  });
  if(n)toast('warn','Registros desactivados',`${n} cambiaron a inactivo.`);
  selected.clear();
  render();
};

let bulkMode=false;
document.getElementById('bulkDelete').onclick=()=>{
  bulkMode=true;
  const M=MODULES[curModule];
  document.getElementById('delTitle').textContent=`Eliminar ${M.title.toLowerCase()}`;
  document.getElementById('delSub').innerHTML=`¿Seguro que deseas eliminar <b style="color:var(--text)">${selected.size} registro${selected.size!==1?'s':''}</b>? Esta acción no se puede deshacer.`;
  document.getElementById('ovDel').classList.add('show');
};

/* Dropdowns de fila */
document.addEventListener('click',e=>{
  const kb=e.target.closest('[data-kebab]');
  document.querySelectorAll('.dd.open').forEach(d=>{
    if(!kb||d.previousElementSibling!==kb)d.classList.remove('open')
  });
  if(kb)kb.nextElementSibling.classList.toggle('open');
  
  const ed=e.target.closest('[data-edit]');
  if(ed)showForm(ed.dataset.edit, 'edit'); // Asegurar modo edición
  
  const dl=e.target.closest('[data-del]');
  if(dl){
    bulkMode=false;
    const M=MODULES[curModule];
    deletingId=dl.dataset.del;
    const it=M.items.find(x=>x.id===deletingId);
    document.getElementById('delTitle').textContent=`Eliminar ${M.title.toLowerCase().replace(/s$/,'')}`;
    document.getElementById('delSub').innerHTML=`¿Seguro que deseas eliminar <b id="delName" style="color:var(--text)"></b>? Esta acción no se puede deshacer.`;
    document.getElementById('delName').textContent=it.name;
    document.getElementById('ovDel').classList.add('show')
  }
  
  if(!e.target.closest('.row-actions')){
    document.querySelectorAll('.dd.open').forEach(d=>d.classList.remove('open'))
  }
});

/* Guardar */
const fName=document.getElementById('fName');
document.getElementById('btnSave').onclick=()=>{
  const M=MODULES[curModule];
  if(!fName.value.trim()){
    fName.classList.add('error');
    document.getElementById('fErr').classList.add('show');
    fName.focus();
    return;
  }
  const data={
    name:fName.value.trim(),
    desc:document.getElementById('fDesc').value.trim()||'Sin descripción',
    st:document.getElementById('fActive').checked
  };
  if(M.hasEmail)data.email=document.getElementById('fEmail').value.trim();
  
  if(editingId){
    Object.assign(M.items.find(c=>c.id===editingId),data);
    toast('ok','Cambios guardados',`${data.name} se actualizó correctamente.`);
  }else{
    const nid=M.prefix+'-'+String(nextNs[curModule]++).padStart(3,'0');
    M.items.push({id:nid,col:0,...data});
    toast('ok','Registro creado',`${data.name} se agregó a ${M.title.toLowerCase()}.`);
  }
  showList();
  render();
};

fName.addEventListener('input',e=>{
  e.target.classList.remove('error');
  document.getElementById('fErr').classList.remove('show')
});

/* Eliminar */
const ovDel=document.getElementById('ovDel');
document.getElementById('btnDel').onclick=()=>{
  const M=MODULES[curModule];
  if(bulkMode){
    const n=selected.size;
    M.items=M.items.filter(x=>!selected.has(x.id));
    selected.clear();
    closeOv(ovDel);
    render();
    toast('err','Registros eliminados',`${n} fueron eliminados.`);
  }else{
    const it=M.items.find(x=>x.id===deletingId);
    M.items=M.items.filter(x=>x.id!==deletingId);
    selected.delete(deletingId);
    closeOv(ovDel);
    render();
    toast('err','Registro eliminado',`${it.name} fue eliminado.`);
  }
  bulkMode=false;
};

/* Atajos de teclado */
document.addEventListener('keydown',e=>{
  if(e.key==='/'&&!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)&&!viewList.hidden){
    e.preventDefault();
    inpSearch.focus();
  }
  if(e.key==='Escape'){
    closeOv(ovDel);
    userMenu.classList.remove('open');
    avatarBtn.classList.remove('active');
    document.getElementById('notifMenu').classList.remove('open');
    document.getElementById('btnNotif').classList.remove('active');
    document.querySelectorAll('.fsel.open').forEach(x=>x.classList.remove('open'));
    hideTip();
    if(!viewForm.hidden||!viewError.hidden)showList();
  }
});

/* Sidebar */
document.querySelectorAll('[data-group]').forEach(b=>b.addEventListener('click',()=>{
  const g=b.closest('.group');
  const wasOpen=g.classList.contains('open');
  document.querySelectorAll('.group.open').forEach(x=>x.classList.remove('open'));
  if(!wasOpen)g.classList.add('open');
}));

document.getElementById('btnCollapse').onclick=()=>document.body.classList.toggle('collapsed');

const side=document.getElementById('sidebar'),
      scrim=document.getElementById('scrim'),
      mqMobile=matchMedia('(max-width:900px)'),
      btnSide=document.getElementById('btnSide');

btnSide.onclick=()=>{
  if(mqMobile.matches){
    side.classList.add('open');
    scrim.classList.add('show')
  }else{
    document.body.classList.toggle('collapsed')
  }
};

scrim.onclick=()=>{
  side.classList.remove('open');
  scrim.classList.remove('show')
};

mqMobile.addEventListener('change',()=>{
  side.classList.remove('open');
  scrim.classList.remove('show')
});

/* Inicialización */
renderDash();
setTimeout(()=>toast('info','TuMarca UI','Sistema cargado correctamente. Todos los componentes están activos.'),700);