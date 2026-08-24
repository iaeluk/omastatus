.pragma library

const sensorCatalog = {
  'temperature': { icon: 'temperature-symbolic.svg', colorFormats: ['temp'] },
  'voltage': { icon: 'voltage-symbolic.svg' },
  'fan': { icon: 'fan-symbolic.svg', colorFormats: ['fan'] },
  'memory': { icon: 'memory-symbolic.svg', colorFormats: ['percent'] },
  'processor': { icon: 'cpu-symbolic.svg', colorFormats: ['percent'] },
  'system': { icon: 'system-symbolic.svg', colorFormats: ['load'] },
  'network': { icon: 'network-symbolic.svg', 'icon-rx': 'network-download-symbolic.svg', 'icon-tx': 'network-upload-symbolic.svg' },
  'storage': { icon: 'storage-symbolic.svg' },
  'battery': { icon: 'battery-symbolic.svg', colorFormats: ['percent'] },
  'gpu': { icon: 'gpu-symbolic.svg', colorFormats: ['percent'] }
};

function sensorGroupFromType(type) {
  let g = (type || '').replace(/-group$/, '');
  if (g.startsWith('gpu')) return 'gpu';
  if (g.startsWith('network')) return 'network';
  return g.replace(/#\d+$/, '');
}

function sensorKeyFromTypeLabel(type, label) {
  let typeKey = (type || '').replace('-group', '');
  if (/^network-(?!rx$|tx$)/.test(typeKey)) typeKey = 'network';
  return '_' + typeKey + '_' + String(label).replace(/ /g, '_').toLowerCase() + '_';
}

function parseColorEntry(e) {
  if (typeof e !== 'string') return null;
  const p = e.trim().split(' ');
  if (p.length < 4) return null;
  const t = Number(p[0]), r = Number(p[1]), g = Number(p[2]), b = Number(p[3]);
  if (![t,r,g,b].every(Number.isFinite)) return null;
  let sk = null;
  if (p.length > 4) {
    const rest = p.slice(4).join(' ');
    if (!rest.startsWith('sensor:')) return null;
    sk = rest.slice(7);
    if (!sk) return null;
  }
  return {threshold:t, red:r, green:g, blue:b, sensorKey:sk};
}
function normalizeColorComponent(c) {
  if (!Number.isFinite(c)) return null;
  const s = c > 1 ? c : c*255;
  return Math.max(0, Math.min(255, Math.round(s)));
}
function styleForEntries(value, entries) {
  const th = entries.slice().sort((a,b)=>a.threshold-b.threshold).map(e=>{
    const r=normalizeColorComponent(e.red), g=normalizeColorComponent(e.green), b=normalizeColorComponent(e.blue);
    if (r===null||g===null||b===null) return null;
    return {threshold:e.threshold, style:`color: rgb(${r}, ${g}, ${b});`};
  }).filter(Boolean);
  if (!th.length) return '';
  for (let i=th.length-1;i>=0;i--) if (value>=th[i].threshold) return th[i].style;
  return '';
}
function getUsageColor(value, colors, sensorKey) {
  if (!colors||!colors.length||!Number.isFinite(value)) return '';
  const entries = colors.map(parseColorEntry).filter(Boolean);
  if (!entries.length) return '';
  if (sensorKey) {
    const specific = entries.filter(e=>e.sensorKey===sensorKey);
    if (specific.length) return styleForEntries(value, specific);
  }
  return styleForEntries(value, entries.filter(e=>!e.sensorKey));
}
function colorsKeyForSensor(type, format) {
  if (format==='temp') return 'temperature-colors';
  const g = sensorGroupFromType(type);
  const cat = sensorCatalog[g]
  const f = cat ? cat.colorFormats : null
  if (f && f.includes(format)) return `${g}-colors`;
  return null;
}

function legible(value, format, settings, type, sensorKey) {
  if (value===null || value===undefined) return {text:'N/A', style:''};
  const useHigher = settings.useHigherPrecision === true;
  const memUnit = settings.memoryMeasurement;
  const storUnit = settings.storageMeasurement;
  const useBps = settings.networkSpeedFormat === 1;
  const fixedUnit = settings.networkSpeedUnit || 0;
  const unit = 1000;
  let ending=''; let exp=0; let fmt='';
  const decimal=['B','KB','MB','GB','TB','PB','EB','ZB','YB'];
  const binary=['B','KiB','MiB','GiB','TiB','PiB','EiB','ZiB','YiB'];
  const hertz=['Hz','KHz','MHz','GHz','THz','PHz','EHz','ZHz'];
  let v = value;
  switch(format){
    case 'percent':
      fmt = useHigher ? '%.1f%s' : '%d%s';
      v = v*100; if(v>100) v=100; ending='%'; break;
    case 'temp':
      v = v/1000; ending='°C';
      if (settings.unit===1){ v = (9/5)*v+32; ending='°F'; }
      fmt = useHigher ? '%.1f%s' : '%d%s'; break;
    case 'fan': fmt='%d %s'; ending='RPM'; break;
    case 'in':
      v = v/1000; fmt = ((v>=0)?'+':'-') + (useHigher ? '%.2f %s' : '%.1f %s'); ending='V'; break;
    case 'hertz':
      if(v>0){ exp=Math.max(0,Math.floor(Math.log(v)/Math.log(unit))); if(v>=Math.pow(unit,exp)*(unit-0.05)) exp++; v=parseFloat((v/Math.pow(unit,exp)).toFixed(useHigher?2:1));}
      fmt = useHigher ? '%.2f %s' : '%.1f %s'; ending=hertz[exp]||'Hz'; break;
    case 'memory':
      {
        const u = memUnit ? 1000 : 1024;
        if(v>0){ v*=u; exp=Math.floor(Math.log(v)/Math.log(u)); if(v>=Math.pow(u,exp)*(u-0.05)) exp++; v=parseFloat((v/Math.pow(u,exp)).toFixed(useHigher?2:1));}
        fmt = useHigher ? '%.2f %s' : '%.1f %s'; ending = memUnit ? decimal[exp] : binary[exp]; break;
      }
    case 'storage':
      {
        const u = storUnit ? 1000 : 1024;
        if(v>0){ exp=Math.floor(Math.log(v)/Math.log(u)); if(v>=Math.pow(u,exp)*(u-0.05)) exp++; v=parseFloat((v/Math.pow(u,exp)).toFixed(useHigher?2:1));}
        fmt = useHigher ? '%.2f %s' : '%.1f %s'; ending = storUnit ? decimal[exp] : binary[exp]; break;
      }
    case 'speed':
      {
        if(v>0){
          if(useBps) v*=8;
          if(fixedUnit>0){ exp=fixedUnit; v=parseFloat((v/Math.pow(unit,exp)).toFixed(useHigher?1:0));}
          else { exp=Math.floor(Math.log(v)/Math.log(unit)); if(v>=Math.pow(unit,exp)*(unit-0.05)) exp++; v=parseFloat((v/Math.pow(unit,exp)).toFixed(useHigher?1:0));}
        } else exp=0;
        fmt = useHigher ? '%.1f %s' : '%.0f %s';
        ending = useBps ? decimal[exp].replace('B','bps') : decimal[exp]+'/s';
        break;
      }
    case 'uptime':
    case 'runtime':
      {
        let scale=[24,60,60]; let units=['d ','h ','m '];
        if(format!=='runtime' && (useHigher || v<60)){ scale.push(1); units.push('s ');}
        let result=['', v];
        const cbFun=(d,c)=>{ let bb=d[1]%c[0], aa=(d[1]-bb)/c[0]; aa=aa>0?aa+c[1]:''; return [d[0]+aa, bb];};
        for(let i=0;i<scale.length;i++){
        }
        let secs = Math.floor(v);
        let d = Math.floor(secs/86400); secs%=86400;
        let h = Math.floor(secs/3600); secs%=3600;
        let m = Math.floor(secs/60); secs%=60;
        let parts=[];
        if(d>0) parts.push(d+'d');
        if(h>0||d>0) parts.push(h+'h');
        if(m>0||h>0||d>0) parts.push(m+'m');
        if(secs>0 && (format!=='runtime' && (useHigher || v<60))) parts.push(secs+'s');
        if(parts.length===0) parts.push('0s');
        return {text: parts.join(' '), style: styleFor(v,type,format,sensorKey,settings)};
      }
    case 'watt': fmt = ((v>0)?'+':'') + (useHigher?'%.2f %s':'%.1f %s'); v=v/1000000; ending='W'; break;
    case 'watt-gpu': fmt = useHigher?'%.2f %s':'%.1f %s'; ending='W'; break;
    case 'watt-hour': fmt = useHigher?'%.2f %s':'%.1f %s'; v=v/1000000; ending='Wh'; break;
    case 'load': fmt = useHigher?'%.2f %s':'%.1f %s'; v=parseFloat(v); break;
    case 'pcie': {
      let s=String(v).split('x'); v='PCIe '+parseInt(s[0])+(s.length>1?' x'+parseInt(s[1]):''); fmt='%s'; break;
    }
    default: fmt='%s'; break;
  }
  let text='';
  if(fmt==='%d%s') text = Math.round(v)+ending;
  else if(fmt==='%.1f%s') text = (Math.round(v*10)/10).toFixed(1)+ending;
  else if(fmt==='%.2f %s') text = v.toFixed(2)+' '+ending;
  else if(fmt==='%.1f %s') text = v.toFixed(1)+' '+ending;
  else if(fmt==='%.0f %s') text = Math.round(v)+' '+ending;
  else if(fmt==='%.2f%s') text = v.toFixed(2)+ending;
  else if(fmt==='%d %s') text = Math.round(v)+' '+ending;
  else if(fmt==='%s') text = String(v).trim();
  else text = String(v)+ending;
  if(format==='in' || format==='watt'){
    if(format==='in'){
      let sign = value>=0?'+':'-';
      let av=Math.abs(v);
      text = sign + (useHigher? av.toFixed(2): av.toFixed(1))+' '+ending;
    }
    if(format==='watt'){
      let sign = value>0?'+':'';
      text = sign + (useHigher? (value/1000000).toFixed(2): (value/1000000).toFixed(1))+' W';
    }
  }
  text = text.trim();
  return {text, style: styleFor(v,type,format,sensorKey,settings)};
}

function styleFor(numeric, type, format, sensorKey, settings){
  const k = colorsKeyForSensor(type, format);
  if(!k || numeric===null || !Number.isFinite(numeric)) return '';
  const colors = settings[k] || [];
  return getUsageColor(numeric, colors, sensorKey);
}

function groupForType(type){
  let g=(type||'').replace(/-group$/,'');
  if(g.startsWith('gpu')) return 'gpu';
  if(g.startsWith('network')) return 'network';
  return g.replace(/#\d+$/,'');
}
function ucFirst(s){
  if(s.startsWith('gpu')) return 'Graphics';
  return s.charAt(0).toUpperCase()+s.slice(1);
}
function iconForType(type){
  const g=groupForType(type);
  const cat=sensorCatalog[g]||sensorCatalog['system'];
  if(type==='network-rx') return 'network-download-symbolic.svg';
  if(type==='network-tx') return 'network-upload-symbolic.svg';
  return cat.icon || 'system-symbolic.svg';
}

function processorPercent(prev, curr, dwell, cores){
  if(prev===null || curr===null || dwell<=0) return null;
  const delta = curr - prev;
  if(delta<0) return null;
  if(cores<=0) cores=1;
  let pct = (delta / dwell) / 100;
  if(pct>1) pct=1; if(pct<0) pct=0;
  return pct;
}