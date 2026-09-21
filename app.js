const SB_URL = localStorage.getItem('SB_URL') || '';
const SB_KEY = localStorage.getItem('SB_KEY') || '';
let sb = null, user = null, profile = null, products = [], customers = [], suppliers = [];

const $ = id => document.getElementById(id);
const money = n => new Intl.NumberFormat('ar-OM',{minimumFractionDigits:3,maximumFractionDigits:3}).format(Number(n||0))+' ر.ع';
const esc = s => String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function init(){
 if(!SB_URL||!SB_KEY){ $('setup').classList.remove('hidden'); return; }
 sb = window.supabase.createClient(SB_URL,SB_KEY);
 const {data:{session}}=await sb.auth.getSession(); user=session?.user||null;
 if(!user){ $('login').classList.remove('hidden'); return; }
 const r=await sb.from('profiles').select('*,roles(*)').eq('id',user.id).maybeSingle(); profile=r.data;
 if(!profile){ await sb.from('profiles').insert({id:user.id,full_name:user.email?.split('@')[0]||'مدير'}); }
 $('app').classList.remove('hidden'); await loadAll(); dashboard();
}
async function login(){ const email=$('email').value,password=$('password').value; const {error}=await sb.auth.signInWithPassword({email,password}); if(error)return alert(error.message); location.reload(); }
async function signup(){ const email=$('email').value,password=$('password').value; const {error}=await sb.auth.signUp({email,password}); if(error)return alert(error.message); alert('تم إنشاء الحساب. تحقق من البريد إذا كان التحقق مفعلًا.'); }
async function logout(){await sb.auth.signOut();location.reload();}
async function loadAll(){
 const [p,c,s]=await Promise.all([
  sb.from('products').select('*,categories(name),brands(name),suppliers(name)').order('created_at',{ascending:false}),
  sb.from('customers').select('*').order('name'),
  sb.from('suppliers').select('*').order('name')]);
 products=p.data||[];customers=c.data||[];suppliers=s.data||[];
 renderProducts(); renderCustomers(); renderSuppliers(); renderLowStock();
}
function nav(page){document.querySelectorAll('.page').forEach(x=>x.classList.add('hidden'));$(page)?.classList.remove('hidden');document.querySelectorAll('.nav button').forEach(x=>x.classList.toggle('active',x.dataset.page===page)); if(page==='dashboard')dashboard(); if(page==='sales')salesPage(); if(page==='purchases')purchasePage(); if(page==='audit')auditPage();}
async function dashboard(){
 const [s,p,e]=await Promise.all([sb.from('sales').select('total,due,created_at').eq('status','posted'),sb.from('purchases').select('total').eq('status','posted'),sb.from('expenses').select('amount,expense_date')]);
 const sales=s.data||[], purchases=p.data||[], expenses=e.data||[];
 const totalSales=sales.reduce((a,x)=>a+Number(x.total),0), exp=expenses.reduce((a,x)=>a+Number(x.amount),0);
 const saleIds=sales.map(x=>x.id); let cogs=0;
 if(saleIds.length){const q=await sb.from('sale_items').select('qty,cost').in('sale_id',saleIds); cogs=(q.data||[]).reduce((a,x)=>a+Number(x.qty)*Number(x.cost),0);}
 const gross=totalSales-cogs, net=gross-exp;
 $('kpis').innerHTML=[['المبيعات',totalSales],['المشتريات',purchases.reduce((a,x)=>a+Number(x.total),0)],['المصروفات',exp],['صافي الربح',net],['تكلفة البضاعة',cogs],['قيمة المخزون',products.reduce((a,x)=>a+Number(x.qty)*Number(x.avg_cost),0)]].map(([t,v])=>'<div class="kpi"><span>'+t+'</span><strong>'+money(v)+'</strong></div>').join('');
 $('counts').innerHTML='<div>المنتجات <b>'+products.length+'</b></div><div>العملاء <b>'+customers.length+'</b></div><div>الموردون <b>'+suppliers.length+'</b></div><div>منخفض المخزون <b>'+products.filter(x=>Number(x.qty)<=Number(x.min_stock)).length+'</b></div>';
}
function renderProducts(){
 $('productRows').innerHTML=products.map(p=>'<tr><td>'+esc(p.name)+'</td><td>'+esc(p.sku||'—')+'</td><td>'+money(p.retail_price)+'</td><td>'+p.qty+'</td><td><button onclick="editProduct(\''+p.id+'\')">تعديل</button></td></tr>').join('');
}
function renderLowStock(){ $('lowStock').innerHTML=products.filter(p=>Number(p.qty)<=Number(p.min_stock)).slice(0,8).map(p=>'<li>'+esc(p.name)+' <b>'+p.qty+'</b></li>').join('')||'<li>لا توجد تنبيهات</li>'; }
async function addProduct(){
 const payload={name:$('pname').value,sku:$('psku').value||null,barcode:$('pbarcode').value||null,purchase_price:+$('pcost').value||0,avg_cost:+$('pcost').value||0,retail_price:+$('pprice').value||0,wholesale_price:+$('pwholesale').value||0,qty:+$('pqty').value||0,min_stock:+$('pmin').value||0,notes:$('pnotes').value};
 const {error}=await sb.from('products').insert(payload); if(error)return alert(error.message); closeModal(); await loadAll(); dashboard();
}
function editProduct(id){const p=products.find(x=>x.id===id);if(!p)return; $('pname').value=p.name;$('psku').value=p.sku||'';$('pbarcode').value=p.barcode||'';$('pcost').value=p.purchase_price;$('pprice').value=p.retail_price;$('pwholesale').value=p.wholesale_price;$('pqty').value=p.qty;$('pmin').value=p.min_stock;$('pnotes').value=p.notes||'';$('productModal').dataset.id=id;$('productModal').classList.remove('hidden');}
async function saveProduct(){const id=$('productModal').dataset.id;if(!id)return addProduct();const payload={name:$('pname').value,sku:$('psku').value||null,barcode:$('pbarcode').value||null,purchase_price:+$('pcost').value||0,retail_price:+$('pprice').value||0,wholesale_price:+$('pwholesale').value||0,qty:+$('pqty').value||0,min_stock:+$('pmin').value||0,notes:$('pnotes').value,updated_at:new Date().toISOString()};const {error}=await sb.from('products').update(payload).eq('id',id);if(error)return alert(error.message);closeModal();delete $('productModal').dataset.id;await loadAll();}
function openProduct(){document.querySelectorAll('#productModal input,#productModal textarea').forEach(x=>x.value='');delete $('productModal').dataset.id;$('productModal').classList.remove('hidden');}
function closeModal(){document.querySelectorAll('.modal').forEach(x=>x.classList.add('hidden'))}
function filterProducts(){const q=$('productSearch').value.toLowerCase();document.querySelectorAll('#productRows tr').forEach(r=>r.style.display=r.innerText.toLowerCase().includes(q)?'':'none');}
function renderCustomers(){$('customerRows').innerHTML=customers.map(c=>'<tr><td>'+esc(c.name)+'</td><td>'+esc(c.phone||'')+'</td><td>'+money(c.balance)+'</td></tr>').join('')}
function renderSuppliers(){$('supplierRows').innerHTML=suppliers.map(s=>'<tr><td>'+esc(s.name)+'</td><td>'+esc(s.phone||'')+'</td><td>'+money(s.balance)+'</td></tr>').join('')}
async function addCustomer(){const {error}=await sb.from('customers').insert({name:$('cname').value,phone:$('cphone').value,email:$('cemail').value,address:$('caddress').value});if(error)return alert(error.message);closeModal();await loadAll();}
async function addSupplier(){const {error}=await sb.from('suppliers').insert({name:$('sname').value,phone:$('sphone').value,email:$('semail').value,address:$('saddress').value});if(error)return alert(error.message);closeModal();await loadAll();}
function salesPage(){ $('saleProduct').innerHTML=products.map(p=>'<option value="'+p.id+'">'+esc(p.name)+' — '+money(p.retail_price)+'</option>').join(''); }
async function createSale(){const p=products.find(x=>x.id===$('saleProduct').value),qty=+$('saleQty').value;if(!p||qty<=0)return;const items=[{product_id:p.id,qty,price:+$('salePrice').value||p.retail_price}];const {data,error}=await sb.rpc('create_sale',{p_customer:$('saleCustomer').value||null,p_items:items,p_paid:+$('salePaid').value||0,p_payment:$('salePayment').value||null,p_notes:$('saleNotes').value});if(error)return alert(error.message);alert('تم حفظ الفاتورة '+data);await loadAll();salesPage();}
function purchasePage(){ $('purchaseProduct').innerHTML=products.map(p=>'<option value="'+p.id+'">'+esc(p.name)+'</option>').join(''); }
async function createPurchase(){const p=products.find(x=>x.id===$('purchaseProduct').value),qty=+$('purchaseQty').value;if(!p||qty<=0)return;const items=[{product_id:p.id,qty,price:+$('purchasePrice').value||p.purchase_price}];const {data,error}=await sb.rpc('create_purchase',{p_supplier:$('purchaseSupplier').value||null,p_items:items,p_paid:+$('purchasePaid').value||0,p_payment:$('purchasePayment').value||null,p_notes:$('purchaseNotes').value});if(error)return alert(error.message);alert('تم حفظ المشتريات '+data);await loadAll();purchasePage();}
async function auditPage(){const {data}=await sb.from('audit_logs').select('*').order('created_at',{ascending:false}).limit(100);$('auditRows').innerHTML=(data||[]).map(x=>'<tr><td>'+new Date(x.created_at).toLocaleString('ar-OM')+'</td><td>'+esc(x.action)+'</td><td>'+esc(x.section)+'</td></tr>').join('');}
async function saveSetup(){localStorage.setItem('SB_URL',$('sburl').value.trim());localStorage.setItem('SB_KEY',$('sbkey').value.trim());location.reload();}
window.addEventListener('load',init);