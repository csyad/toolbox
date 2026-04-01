/**
 * ==========================================
 * 📌 代码名称: 🖥️ Server Monitor Widget Pro (统一 UI 版 - 仪表盘进度条)
 * ==========================================
 */
export default async function (ctx) {
  const env = ctx.env || {}; 
  
  const SERVER_CONFIG = {
    widgetName: env.WIDGET_NAME || 'My Node',        
    host: env.SERVER_HOST || '',                     
    port: Number(env.SERVER_PORT) || 22,             
    username: env.SERVER_USER || 'root',             
    password: env.SERVER_PASSWORD || '',             
    privateKey: env.SERVER_KEY || '',                
    bwhVeid: env.BWH_VEID || '',                     
    bwhApiKey: env.BWH_API_KEY || '',                
    trafficLimitGB: Number(env.TRAFFIC_LIMIT) || 2000, 
    resetDay: Number(env.RESET_DAY) || 1             
  };

  // 🎨 统一 UI 规范颜色
  const C = {
    bg: { light: '#FFFFFF', dark: '#121212' },       
    barBg: { light: '#0000001A', dark: '#FFFFFF22' },
    text: { light: '#1C1C1E', dark: '#FFFFFF' },     
    dim: { light: '#8E8E93', dark: '#8E8E93' },      
    
    cpu: { light: '#007AFF', dark: '#0A84FF' },      
    mem: { light: '#AF52DE', dark: '#BF5AF2' },      
    disk: { light: '#FF9500', dark: '#FF9F0A' },     
    netRx: { light: '#34C759', dark: '#30D158' },    
    netTx: { light: '#5856D6', dark: '#5E5CE6' },    
  };

  const getTrafficColor = (pct) => {
    if (pct >= 85) return { light: '#FF3B30', dark: '#FF453A' }; 
    if (pct >= 60) return { light: '#FF9500', dark: '#FF9F0A' }; 
    return { light: '#34C759', dark: '#30D158' };                
  };

  const fmtBytes = (b) => {
    if (b >= 1024 ** 4) return (b / 1024 ** 4).toFixed(2) + 'T';
    if (b >= 1024 ** 3) return (b / 1024 ** 3).toFixed(2) + 'G';
    if (b >= 1024 ** 2) return (b / 1024 ** 2).toFixed(1) + 'M';
    if (b >= 1024)      return (b / 1024).toFixed(0) + 'K';
    return Math.round(b) + 'B';
  };

  const getNextResetDate = (resetDay) => {
    const now = new Date();
    let y = now.getFullYear(), m = now.getMonth();
    if (now.getDate() >= resetDay) m += 1; 
    if (m > 11) { m = 0; y += 1; }
    return `${m + 1}月${resetDay}日 00:00`;
  };

  let d;
  try {
    const { host, port, username, password, privateKey, widgetName, bwhVeid, bwhApiKey, trafficLimitGB, resetDay } = SERVER_CONFIG;
    
    if (!host) {
      throw new Error('未配置 SERVER_HOST 环境变量');
    }

    let bwhData = null;
    if (bwhVeid && bwhApiKey) {
      try {
        const resp = await ctx.http.get(`https://api.64clouds.com/v1/getServiceInfo?veid=${bwhVeid}&api_key=${bwhApiKey}`);
        bwhData = await resp.json();
      } catch (e) { console.log('BWH API Error:', e); }
    }

    const session = await ctx.ssh.connect({
      host, port: Number(port || 22), username,
      ...(privateKey ? { privateKey } : { password }),
      timeout: 8000,
    });

    const SEP = '<<SEP>>';
    const cmds = [
      'hostname -s 2>/dev/null || hostname',
      'cat /proc/loadavg',
      'cat /proc/uptime',
      'head -1 /proc/stat',
      "awk '/MemTotal/{t=$2}/MemFree/{f=$2}/Buffers/{b=$2}/^Cached/{c=$2}END{print t,f,b,c}' /proc/meminfo",
      'df -B1 / | tail -1',
      'nproc',
      "curl -s -m 2 http://ip-api.com/line?fields=country,city,query || echo ''",
      "awk '/^ *(eth|en|wlan|ens|eno|bond|veth)/{rx+=$2;tx+=$10}END{print rx,tx}' /proc/net/dev",
    ];
    const { stdout } = await session.exec(cmds.join(` && echo '${SEP}' && `));
    await session.close();

    const p = stdout.split(SEP).map(s => s.trim());
    const hostname = widgetName !== 'My Node' ? widgetName : (p[0] || 'Server');
    const load = (p[1] || '0 0 0').split(' ').slice(0, 3);
    
    const upSec = parseFloat((p[2] || '0').split(' ')[0]);
    const upDays = Math.floor(upSec / 86400);
    const upHours = Math.floor((upSec % 86400) / 3600);
    const upMins = Math.floor((upSec % 3600) / 60);
    const uptime = upDays > 0 ? `${upDays}天 ${upHours}小时` : `${upHours}小时 ${upMins}分`;

    const cpuNums = (p[3] || '').replace(/^cpu\s+/, '').split(/\s+/).map(Number);
    const cpuTotal = cpuNums.reduce((a, b) => a + b, 0);
    const cpuIdle = cpuNums[3] || 0;
    const prevCpu = ctx.storage.getJSON('_cpu');
    let cpuPct = 0;
    if (prevCpu && cpuTotal > prevCpu.t) {
      cpuPct = Math.round(((cpuTotal - prevCpu.t - (cpuIdle - prevCpu.i)) / (cpuTotal - prevCpu.t)) * 100);
    }
    ctx.storage.setJSON('_cpu', { t: cpuTotal, i: cpuIdle });
    cpuPct = Math.max(0, Math.min(100, cpuPct));
    
    const memKB = (p[4] || '0 0 0 0').split(' ').map(Number);
    const memTotal = memKB[0] * 1024 || 1;
    const memFree = memKB[1] * 1024 || 0;
    const memBuff = memKB[2] * 1024 || 0;
    const memCache = memKB[3] * 1024 || 0;
    const memUsed = memTotal - memFree - memBuff - memCache;
    const memPct = Math.min(100, Math.round((memUsed / memTotal) * 100));

    const df = (p[5] || '').split(/\s+/);
    const diskTotal = Number(df[1]) || 1, diskUsed = Number(df[2]) || 0;
    const diskPct = parseInt(df[4]) || 0;
    const cores = parseInt(p[6]) || 1;

    let ipInfo = host;
    let locInfo = '未知';
    const ipApiLines = (p[7] || '').split('\n').map(s => s.trim()).filter(Boolean);
    if (ipApiLines.length >= 3) {
      locInfo = `${ipApiLines[0]} ${ipApiLines[1]}`.replace(/United States/g, 'US').replace(/United Kingdom/g, 'UK');
      ipInfo = ipApiLines[2];
    } else if (ipApiLines.length > 0) {
      ipInfo = ipApiLines[ipApiLines.length - 1];
    }

    const nn = (p[8] || '0 0').split(' ');
    const netRx = Number(nn[0]) || 0, netTx = Number(nn[1]) || 0;
    const prevNet = ctx.storage.getJSON('_net');
    const now = Date.now();
    let rxRate = 0, txRate = 0;
    if (prevNet && prevNet.ts) {
      const el = (now - prevNet.ts) / 1000;
      if (el > 0 && el < 3600) {
        rxRate = Math.max(0, (netRx - prevNet.rx) / el);
        txRate = Math.max(0, (netTx - prevNet.tx) / el);
      }
    }
    ctx.storage.setJSON('_net', { rx: netRx, tx: netTx, ts: now });

    let tfUsed = 0, tfTotal = 1, tfPct = 0, tfReset = '';
    if (bwhData && bwhData.data_counter !== undefined) {
      tfUsed = bwhData.data_counter;
      tfTotal = bwhData.plan_monthly_data;
      tfPct = Math.min((tfUsed / tfTotal) * 100, 100) || 0;
      const rd = new Date((bwhData.data_next_reset || 0) * 1000);
      tfReset = `${rd.getMonth() + 1}月${rd.getDate()}日 ${String(rd.getHours()).padStart(2, '0')}:${String(rd.getMinutes()).padStart(2, '0')}`;
      
      if (bwhData.ip_addresses && bwhData.ip_addresses[0]) ipInfo = bwhData.ip_addresses[0];
      if (bwhData.node_location) locInfo = bwhData.node_location;
    } else {
      tfUsed = netRx + netTx;
      tfTotal = trafficLimitGB * (1024 ** 3);
      tfPct = Math.min((tfUsed / tfTotal) * 100, 100) || 0;
      tfReset = getNextResetDate(resetDay);
    }

    const dNow = new Date();
    const timeStr = `${String(dNow.getHours()).padStart(2, '0')}:${String(dNow.getMinutes()).padStart(2, '0')}:${String(dNow.getSeconds()).padStart(2, '0')}`;

    d = {
      hostname, uptime, load, cpuPct, cores,
      memTotal, memUsed, memPct, diskTotal, diskUsed, diskPct,
      rxRate, txRate, netRx, netTx,
      tfUsed, tfTotal, tfPct, tfReset, timeStr, ipInfo, locInfo
    };
  } catch (e) {
    d = { error: String(e.message || e) };
  }

  // 🛠️ 核心修改：分段式科技感进度条 (Segmented LED Bar)
  const bar = (pct, color, h = 6) => {
    const segCount = 24; // 🌟 仪表盘格栅数量，分割成24个小块
    const activeCount = Math.round((Math.max(0, Math.min(100, pct)) / 100) * segCount);
    
    return {
      type: 'stack', 
      direction: 'row', 
      height: h, 
      gap: 1.5, // 方块之间的间距
      children: Array.from({ length: segCount }).map((_, i) => {
        const isActive = i < activeCount;
        
        // 🌟 视觉魔法：已激活的格子实现从左到右的「渐变发光」效果 (透明度从 0.4 逐渐亮到 1.0)
        const op = isActive ? (0.4 + 0.6 * (i / Math.max(activeCount - 1, 1))) : 1;
        
        return {
          type: 'stack', 
          flex: 1, 
          height: h, 
          borderRadius: 1, // 微微的圆角，避免边缘过于锋利
          backgroundColor: isActive ? color : C.barBg, // 未激活时使用半透明底色
          opacity: op
        };
      })
    };
  };

  const divider = { type: 'stack', height: 1, backgroundColor: C.barBg, children: [{ type: 'spacer' }] };

  const header = () => ({
    type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
      { type: 'image', src: 'sf-symbol:server.rack', color: C.text, width: 14, height: 14 },
      { type: 'text', text: d.hostname, font: { size: 'headline', weight: 'bold' }, textColor: C.text, maxLines: 1, minScale: 0.6 },
      { type: 'spacer' },
      { type: 'text', text: `↓${fmtBytes(d.rxRate)}/s ↑${fmtBytes(d.txRate)}/s`, font: { size: 9, family: 'Menlo', weight: 'bold' }, textColor: C.dim, minScale: 0.8 },
      { type: 'text', text: '•', font: { size: 9 }, textColor: C.dim, opacity: 0.6 },
      { type: 'text', text: d.uptime, font: { size: 10, weight: 'medium' }, textColor: C.dim, maxLines: 1, minScale: 0.8 },
    ],
  });

  const footer = {
    type: 'stack', direction: 'row', alignItems: 'center', children: [
      { type: 'image', src: 'sf-symbol:arrow.triangle.2.circlepath', color: C.dim, width: 9, height: 9 },
      { type: 'text', text: ` 刷新于 ${d.timeStr}`, font: { size: 9, weight: 'medium' }, textColor: C.dim },
      { type: 'spacer' },
      { type: 'image', src: 'sf-symbol:calendar', color: C.dim, width: 9, height: 9 },
      { type: 'text', text: ` 流量重置: ${d.tfReset}`, font: { size: 9, family: 'Menlo' }, textColor: C.dim },
    ],
  };

  if (d.error) {
    return {
      type: 'widget', padding: [14, 16], gap: 8, backgroundColor: C.bg,
      children: [
        { type: 'text', text: '⚠️ Connection Failed', font: { size: 'headline', weight: 'bold' }, textColor: getTrafficColor(100) },
        { type: 'text', text: d.error, font: { size: 'caption1' }, textColor: C.dim, maxLines: 3 },
      ],
    };
  }

  if (ctx.widgetFamily === 'systemSmall') {
    return {
      type: 'widget', backgroundColor: C.bg, padding: [12, 16], gap: 5, 
      children: [
        { type: 'stack', direction: 'column', gap: 1, children: [
          { type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
            { type: 'image', src: 'sf-symbol:server.rack', color: C.text, width: 12, height: 12 },
            { type: 'text', text: d.hostname, font: { size: 'subheadline', weight: 'bold' }, textColor: C.text, maxLines: 1 },
          ]},
          { type: 'text', text: d.ipInfo, font: { size: 9, family: 'Menlo', weight: 'bold' }, textColor: C.text },
        ]},
        { type: 'spacer', length: 2 },
        ...[
          { ic: 'cpu', lb: 'CPU', pt: d.cpuPct, v: `${d.cpuPct}%`, c: C.cpu },
          { ic: 'memorychip', lb: 'MEM', pt: d.memPct, v: `${d.memPct}%`, c: C.mem },
          { ic: 'antenna.radiowaves.left.and.right', lb: 'TRAF', pt: d.tfPct, v: `${d.tfPct.toFixed(0)}%`, c: getTrafficColor(d.tfPct) }
        ].map(i => ({
          type: 'stack', direction: 'column', gap: 3, children: [
            { type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
              { type: 'image', src: `sf-symbol:${i.ic}`, color: i.c, width: 10, height: 10 },
              { type: 'text', text: i.lb, font: { size: 10, weight: 'bold' }, textColor: C.text },
              { type: 'spacer' },
              { type: 'text', text: i.v, font: { size: 10, weight: 'heavy', family: 'Menlo' }, textColor: i.c },
            ]},
            bar(i.pt, i.c, 5), // 小组件进度条稍微细一点
          ]
        }))
      ],
    };
  }

  if (ctx.widgetFamily === 'systemMedium') {
    return {
      type: 'widget', backgroundColor: C.bg, padding: [12, 16], 
      children: [
        header(),
        { type: 'spacer' },
        { type: 'stack', direction: 'column', gap: 6, children: [
          { type: 'stack', direction: 'column', gap: 3, children: [
            { type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
              { type: 'image', src: 'sf-symbol:cpu', color: C.cpu, width: 11, height: 11 },
              { type: 'text', text: `CPU ${d.cores}C`, font: { size: 11, weight: 'bold' }, textColor: C.text },
              { type: 'text', text: `${d.cpuPct}%`, font: { size: 11, weight: 'heavy', family: 'Menlo' }, textColor: C.cpu },
              { type: 'spacer' },
              { type: 'image', src: 'sf-symbol:network', color: C.text, width: 10, height: 10 },
              { type: 'text', text: d.ipInfo, font: { size: 10, family: 'Menlo', weight: 'bold' }, textColor: C.text },
              { type: 'text', text: '•', font: { size: 10 }, textColor: C.dim },
              { type: 'text', text: d.locInfo, font: { size: 10, weight: 'bold' }, textColor: C.text, maxLines: 1, minScale: 0.8 },
            ]},
            bar(d.cpuPct, C.cpu, 6),
          ]},
          { type: 'stack', direction: 'column', gap: 3, children: [
            { type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
              { type: 'image', src: 'sf-symbol:memorychip', color: C.mem, width: 11, height: 11 },
              { type: 'text', text: 'MEM', font: { size: 11, weight: 'bold' }, textColor: C.text },
              { type: 'text', text: `${d.memPct}%`, font: { size: 11, weight: 'heavy', family: 'Menlo' }, textColor: C.mem },
              { type: 'spacer' },
              { type: 'text', text: `${fmtBytes(d.memUsed)} / ${fmtBytes(d.memTotal)}`, font: { size: 10, family: 'Menlo', weight: 'medium' }, textColor: C.dim },
            ]},
            bar(d.memPct, C.mem, 6),
          ]},
          { type: 'stack', direction: 'column', gap: 3, children: [
            { type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
              { type: 'image', src: 'sf-symbol:antenna.radiowaves.left.and.right', color: getTrafficColor(d.tfPct), width: 11, height: 11 },
              { type: 'text', text: 'TRAF', font: { size: 11, weight: 'bold' }, textColor: C.text },
              { type: 'text', text: `${d.tfPct.toFixed(1)}%`, font: { size: 11, weight: 'heavy', family: 'Menlo' }, textColor: getTrafficColor(d.tfPct) },
              { type: 'spacer' },
              { type: 'text', text: `${fmtBytes(d.tfUsed)} / ${fmtBytes(d.tfTotal)}`, font: { size: 10, family: 'Menlo', weight: 'medium' }, textColor: C.dim },
            ]},
            bar(d.tfPct, getTrafficColor(d.tfPct), 6),
          ]},
          { type: 'stack', direction: 'column', gap: 3, children: [
            { type: 'stack', direction: 'row', alignItems: 'center', gap: 4, children: [
              { type: 'image', src: 'sf-symbol:internaldrive', color: C.disk, width: 11, height: 11 },
              { type: 'text', text: 'DSK', font: { size: 11, weight: 'bold' }, textColor: C.text },
              { type: 'text', text: `${d.diskPct}%`, font: { size: 11, weight: 'heavy', family: 'Menlo' }, textColor: C.disk },
              { type: 'spacer' },
              { type: 'text', text: `${fmtBytes(d.diskUsed)} / ${fmtBytes(d.diskTotal)}`, font: { size: 10, family: 'Menlo', weight: 'medium' }, textColor: C.dim },
            ]},
            bar(d.diskPct, C.disk, 6),
          ]},
        ]},
        { type: 'spacer' },
        footer,
      ],
    };
  }

  return {
    type: 'widget', backgroundColor: C.bg, padding: [14, 16], gap: 8, 
    children: [
      header(),
      divider,
      { type: 'stack', direction: 'row', alignItems: 'center', gap: 6, children: [
        { type: 'image', src: 'sf-symbol:cpu', color: C.cpu, width: 14, height: 14 },
        { type: 'text', text: `CPU ${d.cores}C`, font: { size: 12, weight: 'bold' }, textColor: C.text },
        { type: 'text', text: `${d.cpuPct}%`, font: { size: 12, weight: 'heavy', family: 'Menlo' }, textColor: C.cpu },
        { type: 'spacer' },
        { type: 'image', src: 'sf-symbol:network', color: C.text, width: 11, height: 11 },
        { type: 'text', text: d.ipInfo, font: { size: 11, family: 'Menlo', weight: 'bold' }, textColor: C.text },
        { type: 'text', text: '•', font: { size: 11 }, textColor: C.dim },
        { type: 'text', text: d.locInfo, font: { size: 11, weight: 'bold' }, textColor: C.text, maxLines: 1 },
      ]},
      bar(d.cpuPct, C.cpu, 7),
      divider,
      { type: 'stack', direction: 'row', alignItems: 'center', gap: 6, children: [
        { type: 'image', src: 'sf-symbol:memorychip', color: C.mem, width: 14, height: 14 },
        { type: 'text', text: 'MEMORY', font: { size: 12, weight: 'bold' }, textColor: C.text },
        { type: 'text', text: `${d.memPct}%`, font: { size: 12, weight: 'heavy', family: 'Menlo' }, textColor: C.mem },
        { type: 'spacer' },
        { type: 'text', text: `${fmtBytes(d.memUsed)} / ${fmtBytes(d.memTotal)}`, font: { size: 11, family: 'Menlo', weight: 'medium' }, textColor: C.dim },
      ]},
      bar(d.memPct, C.mem, 7),
      divider,
      { type: 'stack', direction: 'row', alignItems: 'center', gap: 6, children: [
        { type: 'image', src: 'sf-symbol:antenna.radiowaves.left.and.right', color: getTrafficColor(d.tfPct), width: 14, height: 14 },
        { type: 'text', text: 'TRAFFIC', font: { size: 12, weight: 'bold' }, textColor: C.text },
        { type: 'text', text: `${d.tfPct.toFixed(1)}%`, font: { size: 12, weight: 'heavy', family: 'Menlo' }, textColor: getTrafficColor(d.tfPct) },
        { type: 'spacer' },
        { type: 'text', text: `${fmtBytes(d.tfUsed)} / ${fmtBytes(d.tfTotal)}`, font: { size: 11, family: 'Menlo', weight: 'medium' }, textColor: C.dim },
      ]},
      bar(d.tfPct, getTrafficColor(d.tfPct), 7),
      divider,
      { type: 'stack', direction: 'row', alignItems: 'center', gap: 6, children: [
        { type: 'image', src: 'sf-symbol:internaldrive', color: C.disk, width: 14, height: 14 },
        { type: 'text', text: 'STORAGE', font: { size: 12, weight: 'bold' }, textColor: C.text },
        { type: 'text', text: `${d.diskPct}%`, font: { size: 12, weight: 'heavy', family: 'Menlo' }, textColor: C.disk },
        { type: 'spacer' },
        { type: 'text', text: `${fmtBytes(d.diskUsed)} / ${fmtBytes(d.diskTotal)}`, font: { size: 11, family: 'Menlo', weight: 'medium' }, textColor: C.dim },
      ]},
      bar(d.diskPct, C.disk, 7),
      { type: 'spacer' },
      footer,
    ],
  };
}