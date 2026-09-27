// Shared engine for all theme prototypes: data + capture features. Each theme only renders.
window.CaptureCore = (function () {
  const CATS = { Comida: ['restaurant', '#F59E0B'], Mercado: ['shopping_cart', '#22C55E'], Transporte: ['directions_car', '#8B5CF6'], Casa: ['home', '#3B82F6'], Servicios: ['bolt', '#EAB308'], Salud: ['favorite', '#EC4899'], Ocio: ['local_activity', '#06B6D4'], Compras: ['shopping_bag', '#EF4444'], Sueldo: ['payments', '#10B981'], Extra: ['savings', '#14B8A6'], Otros: ['more_horiz', '#94A3B8'] };
  const EXP = ['Comida', 'Mercado', 'Transporte', 'Casa', 'Servicios', 'Salud', 'Ocio', 'Compras', 'Otros'];
  const ACCS = ['Yape', 'BCP', 'BBVA Visa', 'Efectivo'];
  const MON = ['Jul', 'Ago', 'Sep', 'Oct', 'Nov'];
  const WD = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'], WDL = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
  const wdi = (d) => (d + 1) % 7;
  const TODAY = 27, DAYS = 30, BUDGET = 2400;
  const f = (n) => 'S/ ' + Number(n).toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const f0 = (n) => 'S/ ' + Math.round(n).toLocaleString('es-PE');
  const short = (n) => n >= 1000 ? (n / 1000).toFixed(1) + 'k' : n.toFixed(2);
  const SEED = [
    [1, 'Sueldo Setiembre', 3200, 'Sueldo', 'BCP', 'income'], [1, 'Alquiler', 850, 'Casa', 'Yape'], [2, 'Plaza Vea', 146.3, 'Mercado', 'BBVA Visa'], [3, 'Menú', 14, 'Comida', 'Efectivo'],
    [5, 'Luz del Sur', 92.4, 'Servicios', 'BCP'], [6, 'Cine', 38, 'Ocio', 'Yape', 0, 'Compartido'], [8, 'Metropolitano', 20, 'Transporte', 'BCP'], [9, 'Tottus', 118.7, 'Mercado', 'BBVA Visa', 0, 'Captura'],
    [11, 'Farmacia', 46.5, 'Salud', 'Yape', 0, 'Compartido'], [12, 'Cena con amigos', 72, 'Comida', 'Yape', 0, 'Compartido'], [14, 'Zapatillas', 189.9, 'Compras', 'BBVA Visa'], [15, 'Internet', 99, 'Servicios', 'BCP'],
    [16, 'Taxi', 16.5, 'Transporte', 'Yape', 0, 'Captura'], [18, 'Plaza Vea', 132.1, 'Mercado', 'BBVA Visa'], [19, 'Café', 11, 'Comida', 'Yape', 0, 'Compartido'], [20, 'Netflix', 44.9, 'Ocio', 'BBVA Visa'],
    [21, 'Menú', 15, 'Comida', 'Efectivo'], [23, 'Uber', 21.4, 'Transporte', 'BBVA Visa', 0, 'Captura'], [24, 'Mercado Surquillo', 64, 'Mercado', 'Efectivo'], [25, 'Pollo a la brasa', 58, 'Comida', 'Yape', 0, 'Compartido'],
    [25, 'Te yapearon · Freelance', 450, 'Extra', 'Yape', 'income', 'Compartido'], [26, 'Bodega', 23.6, 'Mercado', 'Yape', 0, 'Compartido'], [26, 'Tambo', 9.5, 'Comida', 'Yape', 0, 'Captura'], [27, 'Café', 9, 'Comida', 'Yape', 0, 'Compartido'], [27, 'Menú', 16, 'Comida', 'Efectivo'],
  ];
  const BATCH = [
    { st: 'ok', note: 'Yapeaste a Bodega Rosita', amt: 12, cat: 'Mercado', acc: 'Yape' },
    { st: 'ok', note: 'Yapeaste a Pollería El Rey', amt: 46, cat: 'Comida', acc: 'Yape' },
    { st: 'dup', note: 'Yapeaste a Tambo', amt: 9.5, cat: 'Comida', acc: 'Yape' },
    { st: 'ok', note: 'Plin a Carlos Ruiz', amt: 30, cat: 'Otros', acc: 'BCP' },
    { st: 'err', note: 'IMG_2291.jpg', amt: null },
    { st: 'ok', note: 'Consumo BCP · Metro', amt: 20, cat: 'Transporte', acc: 'BCP' },
    { st: 'inbox', note: 'Yape · monto borroso', amt: null, cat: 'Otros', acc: 'Yape' },
  ];
  const PR = [
    ['autostart', 'rocket_launch', 'Inicio automático', 'Sigue activa tras reiniciar', true],
    ['notif', 'notifications_active', 'Acceso a notificaciones', 'Lee avisos de Yape, Plin y bancos', true],
    ['battery', 'battery_saver', 'Batería sin restricciones', 'HyperOS no cerrará la captura', true],
    ['overlay', 'picture_in_picture', 'Mostrar sobre otras apps', 'Aviso flotante al detectar un pago', true],
    ['recents', 'lock', 'Bloquear en recientes', 'Opcional · no se cierra al limpiar', false],
  ];
  function init() {
    return {
      screen: 'home', tab: 0, selDay: TODAY, dial: false,
      tx: SEED.map((r, i) => ({ id: 't' + i, d: r[0], note: r[1], amt: r[2], cat: r[3], acc: r[4], type: r[5] || 'expense', src: r[6] || '' })),
      inbox: [
        { id: 'i1', note: 'Plin a Juan Pérez', amt: 35, cat: '', acc: 'BCP', src: 'Captura · 18:40', why: 'Falta la categoría' },
        { id: 'i2', note: 'Transferencia BBVA', amt: null, cat: 'Otros', acc: 'BBVA Visa', src: 'Compartido · 12:10', why: 'No se leyó el monto' },
      ],
      perms: { autostart: true, notif: true, battery: false, overlay: false, recents: false },
      rules: [
        { id: 'r1', match: '“Yapeaste”', from: 'Yape', type: 'expense', acc: 'Yape', cat: 'Auto', on: true },
        { id: 'r2', match: '“Te yapearon”', from: 'Yape', type: 'income', acc: 'Yape', cat: 'Extra', on: true },
        { id: 'r3', match: '“Consumo con tu tarjeta”', from: 'BCP', type: 'expense', acc: 'BCP', cat: 'Auto', on: true },
        { id: 'r4', match: 'Tambo, Oxxo, Listo', from: 'Comercio', type: 'expense', acc: 'Yape', cat: 'Comida', on: true },
        { id: 'r5', match: 'Uber, Cabify, InDrive', from: 'Comercio', type: 'expense', acc: 'BBVA Visa', cat: 'Transporte', on: false },
      ],
      capOn: true, flow: null, shade: false, heads: false, flash: false, toast: null,
    };
  }
  function cleanup(c) { clearTimeout(c._fl); clearTimeout(c._toast); clearTimeout(c._h); }
  function build(c, opt) {
    const o = Object.assign({ inc: '#16A34A', exp: '#DC2626', ok: '#16A34A', warn: '#D97706', err: '#DC2626', muted: '#94A3B8', on: '#111', off: '#CBD5E1' }, opt || {});
    const B = o.budget || BUDGET;
    const s = c.state, set = (p) => c.setState(p);
    const toast = (text, undo) => { clearTimeout(c._toast); c.setState({ toast: { text, undo: undo || null } }); c._toast = setTimeout(() => c.setState({ toast: null }), 3600); };
    const addTx = (t) => { const id = 'n' + Date.now() + Math.random().toString(36).slice(2, 6); c.setState((st) => ({ tx: [...st.tx, Object.assign({ d: TODAY, type: 'expense', src: 'Compartido' }, t, { id, fresh: true })] })); return id; };
    const rmTx = (ids) => c.setState((st) => ({ tx: st.tx.filter((t) => !ids.includes(t.id)) }));
    const go = (screen) => () => set({ screen, flow: null, dial: false, shade: false });
    const exp = s.tx.filter((t) => t.type === 'expense'), incs = s.tx.filter((t) => t.type === 'income');
    const spent = exp.reduce((a, t) => a + t.amt, 0), income = incs.reduce((a, t) => a + t.amt, 0);
    const left = B - spent, daysLeft = DAYS - TODAY + 1;
    const row = (t) => { const [icon, color] = CATS[t.cat] || CATS.Otros; const inc = t.type === 'income'; return {
      id: t.id, note: t.note, cat: t.cat, acc: t.acc, meta: t.cat + ' · ' + t.acc, icon, color, soft: color + '22', amtF: f(t.amt), signed: (inc ? '+' : '−') + f(t.amt), inc, amtColor: inc ? o.inc : o.exp,
      fresh: !!t.fresh, hasSrc: !!t.src && !t.fresh, src: t.src, undo: () => { rmTx([t.id]); toast('Movimiento deshecho'); } }; };
    const dayNums = [...new Set(s.tx.map((t) => t.d))].sort((a, b) => b - a);
    const dayLabel = (d) => d === TODAY ? 'Hoy' : d === TODAY - 1 ? 'Ayer' : WDL[wdi(d)][0].toUpperCase() + WDL[wdi(d)].slice(1) + ' ' + d;
    const mkDay = (d) => { const l = s.tx.filter((t) => t.d === d).slice().reverse(); const e = l.filter((t) => t.type === 'expense').reduce((a, t) => a + t.amt, 0), i = l.filter((t) => t.type === 'income').reduce((a, t) => a + t.amt, 0);
      return { d, dd: String(d).padStart(2, '0'), label: dayLabel(d), wd: WD[wdi(d)], wdl: WDL[wdi(d)], expF: e ? f(e) : '', incF: i ? f(i) : '', hasExp: e > 0, hasInc: i > 0, netF: (i - e >= 0 ? '+' : '−') + f(Math.abs(i - e)), rows: l.map(row) }; };
    const days = dayNums.map(mkDay);
    const byCat = EXP.map((n) => ({ n, a: exp.filter((t) => t.cat === n).reduce((x, t) => x + t.amt, 0), k: exp.filter((t) => t.cat === n).length })).filter((x) => x.a > 0).sort((a, b) => b.a - a.a);
    const BUD = Object.assign({ Comida: 300, Mercado: 500, Transporte: 120, Casa: 900, Servicios: 200, Salud: 100, Ocio: 100, Compras: 150, Otros: 50 }, o.catBud || {});
    let acc = 0; const stops = byCat.map((x) => { const a0 = acc / spent * 100; acc += x.a; return `${CATS[x.n][1]} ${a0.toFixed(2)}% ${(acc / spent * 100).toFixed(2)}%`; });
    const cats = byCat.map((x) => { const [icon, color] = CATS[x.n]; const b = BUD[x.n]; const p = x.a / b; return { name: x.n, icon, color, soft: color + '22', amtF: f(x.a), amt0: f0(x.a), pct: Math.round(x.a / spent * 100) + '%', pctDec: (x.a / spent * 100).toFixed(1) + '%', w: (x.a / byCat[0].a * 100) + '%', count: x.k + (x.k === 1 ? ' movimiento' : ' movimientos'), budF: f0(b), budW: Math.min(100, p * 100) + '%', over: p > 1, budColor: p > 1 ? o.err : color, ring: `conic-gradient(${p > 1 ? o.err : color} ${Math.min(100, p * 100)}%, ${color}22 0)`, budPct: Math.round(p * 100) + '%' }; });
    const cells = [30, 31].map((d) => ({ d, out: true })).concat(Array.from({ length: 30 }, (_, i) => ({ d: i + 1 }))).concat([1, 2, 3].map((d) => ({ d, out: true })));
    const weeks = []; for (let i = 0; i < cells.length; i += 7) weeks.push({ days: cells.slice(i, i + 7).map((x) => { const dy = x.out ? null : s.tx.filter((t) => t.d === x.d); const e = dy ? dy.filter((t) => t.type === 'expense').reduce((a, t) => a + t.amt, 0) : 0, n = dy ? dy.filter((t) => t.type === 'income').reduce((a, t) => a + t.amt, 0) : 0;
      return { d: x.d, out: !!x.out, inMonth: !x.out, today: !x.out && x.d === TODAY, sel: !x.out && x.d === s.selDay, expS: e ? short(e) : '', incS: n ? short(n) : '', hasE: e > 0, hasI: n > 0, onClick: () => !x.out && set({ selDay: x.d }) }; }) });
    const selDay = mkDay(s.selDay);
    const week = [21, 22, 23, 24, 25, 26, 27].map((d) => ({ d, l: WD[wdi(d)][0], sel: d === s.selDay, onClick: () => set({ selDay: d }) }));
    // inbox
    const inbox = s.inbox.map((it) => { const [icon, color] = CATS[it.cat] || CATS.Otros; const up = (p) => c.setState((st) => ({ inbox: st.inbox.map((x) => x.id === it.id ? Object.assign({}, x, p) : x) }));
      return { id: it.id, note: it.note, amtF: it.amt != null && it.amt !== '' ? f(it.amt) : 'S/ —', why: it.why, src: it.src, icon, color, soft: color + '22', acc: it.acc, cat: it.cat || 'Sin categoría',
        needsCat: !it.cat, needsAmt: it.amt == null || it.amt === '', canApprove: !!it.cat && it.amt != null && it.amt !== '' && Number(it.amt) > 0,
        catChips: ['Comida', 'Mercado', 'Transporte', 'Compras', 'Otros'].map((n) => ({ name: n, icon: CATS[n][0], onClick: () => up({ cat: n }) })),
        amtVal: it.amtStr || '', onAmt: (e) => { const v = e.target.value.replace(/[^\d.]/g, ''); up({ amtStr: v, amt: v ? Number(v) : null }); },
        approve: () => { if (!(it.cat && it.amt > 0)) return; const id = addTx({ note: it.note, amt: Number(it.amt), cat: it.cat, acc: it.acc, src: 'Por revisar' }); c.setState((st) => ({ inbox: st.inbox.filter((x) => x.id !== it.id) })); toast('Aprobado y registrado', id); },
        discard: () => { c.setState((st) => ({ inbox: st.inbox.filter((x) => x.id !== it.id) })); toast('Descartado'); } }; });
    const nIn = s.inbox.length;
    // perms
    const nOk = PR.filter((p) => s.perms[p[0]]).length, mandOk = PR.filter((p) => p[4]).every((p) => s.perms[p[0]]), missing = PR.filter((p) => p[4] && !s.perms[p[0]]).length;
    const perms = PR.map(([k, icon, title, sub, req]) => ({ key: k, icon, title, sub, req, ok: !!s.perms[k], todo: !s.perms[k], reqLabel: req ? 'Obligatorio' : 'Opcional', stateLabel: s.perms[k] ? 'Listo' : 'Activar', color: s.perms[k] ? o.ok : req ? o.warn : o.muted,
      track: s.perms[k] ? o.on : o.off, knob: s.perms[k] ? '22px' : '2px', toggle: () => { set({ perms: Object.assign({}, s.perms, { [k]: !s.perms[k] }) }); if (!s.perms[k]) toast(title + ' activado en HyperOS'); } }));
    // rules
    const TL = { expense: 'Gasto', income: 'Ingreso' };
    const rules = s.rules.map((r) => { const up = (p) => set({ rules: s.rules.map((x) => x.id === r.id ? Object.assign({}, x, p) : x) }); const nx = (arr, v) => arr[(arr.indexOf(v) + 1) % arr.length];
      return { id: r.id, match: r.match, from: r.from, typeL: TL[r.type], isInc: r.type === 'income', typeColor: r.type === 'income' ? o.inc : o.exp, acc: r.acc, cat: r.cat === 'Auto' ? 'Automática (IA)' : r.cat, catIcon: r.cat === 'Auto' ? 'auto_awesome' : (CATS[r.cat] || CATS.Otros)[0], on: r.on, off: !r.on,
        track: r.on ? o.on : o.off, knob: r.on ? '22px' : '2px', toggle: () => up({ on: !r.on }), cycleType: () => up({ type: r.type === 'expense' ? 'income' : 'expense' }), cycleAcc: () => up({ acc: nx(ACCS, r.acc) }), cycleCat: () => up({ cat: nx(['Auto', 'Comida', 'Mercado', 'Transporte', 'Extra', 'Otros'], r.cat) }) }; });
    // flows
    const fl = s.flow;
    const startOne = () => set({ flow: { kind: 'one', stage: 'source' }, dial: false, shade: false });
    const startBatch = () => set({ flow: { kind: 'batch', stage: 'source', i: 0 }, dial: false, shade: false });
    const startBg = () => { set({ dial: false, shade: false }); if (!mandOk) return set({ flow: { kind: 'bg', stage: 'blocked' } }); set({ flow: null, flash: true }); clearTimeout(c._h); c._h = setTimeout(() => { c.setState({ flash: false, heads: true }); }, 650); };
    const pick = () => { const k = fl.kind; set({ flow: { kind: k, stage: 'reading', i: 0 } }); clearTimeout(c._fl);
      if (k === 'one') c._fl = setTimeout(() => { const id = addTx({ note: 'Yapeaste a Bodega Don Lucho', amt: 23.5, cat: 'Mercado', acc: 'Yape' }); c.setState((st) => ({ flow: Object.assign({}, st.flow, { stage: 'done', ids: [id] }) })); }, 1700);
      else { let i = 0; const tick = () => { i++; c.setState((st) => ({ flow: Object.assign({}, st.flow, { i }) })); if (i < 7) c._fl = setTimeout(tick, 430); else c._fl = setTimeout(() => {
        const ids = BATCH.filter((b) => b.st === 'ok').map((b) => addTx({ note: b.note, amt: b.amt, cat: b.cat, acc: b.acc }));
        c.setState((st) => ({ flow: Object.assign({}, st.flow, { stage: 'done', ids }), inbox: [...st.inbox, { id: 'ib' + Date.now(), note: 'Yape · monto borroso', amt: null, cat: 'Otros', acc: 'Yape', src: 'Lote · imagen 7', why: 'No se leyó el monto' }] })); }, 450); };
        c._fl = setTimeout(tick, 430); } };
    const ST = { ok: ['check_circle', 'Registrado', o.ok], dup: ['content_copy', 'Duplicado · omitido', o.warn], err: ['error', 'No es un comprobante', o.err], inbox: ['inbox', 'Monto ilegible → Por revisar', o.warn] };
    const bi = fl && fl.kind === 'batch' ? (fl.stage === 'done' ? 7 : fl.i || 0) : 0;
    const batchItems = BATCH.map((b, n) => { const [icon, label, color] = ST[b.st]; return { n: n + 1, note: b.note, amtF: b.amt ? f(b.amt) : '—', statusIcon: icon, statusLabel: label, statusColor: color, soft: color + '1F', shown: n < bi, pending: n >= bi }; });
    const V = {
      screen: s.screen, isHome: s.screen === 'home', isCap: s.screen === 'capture', isInbox: s.screen === 'inbox', isPerms: s.screen === 'perms', isRules: s.screen === 'rules', isStats: s.screen === 'stats', isCal: s.screen === 'calendar', isBudget: s.screen === 'budget',
      goHome: go('home'), goCap: go('capture'), goInbox: go('inbox'), goPerms: go('perms'), goRules: go('rules'), goStats: go('stats'), goCal: go('calendar'), goBudget: go('budget'),
      monthLabel: 'Setiembre 2026', monthUp: 'SETIEMBRE 2026', months: MON.map((m) => ({ label: m.toUpperCase() + ' 26', sel: m === 'Sep' })),
      incomeF: f(income), expenseF: f(spent), balanceF: (income - spent >= 0 ? '+' : '−') + f(Math.abs(income - spent)), balance0: f0(income - spent), saveF: f(income - spent), savePct: ((income - spent) / income * 100).toFixed(1) + '%',
      incDay: f(income / TODAY) + '/día', expDay: f(spent / TODAY) + '/día', saveDay: f((income - spent) / TODAY) + '/día',
      budgetF: f0(B), spent0: f0(spent), leftF: f(left), left0: f0(left), perDayF: f(left / daysLeft), daysLeft, spentPct: Math.round(spent / B * 100) + '%', spentW: Math.min(100, spent / B * 100) + '%', dayW: (TODAY / DAYS * 100) + '%',
      days, recent: days.slice(0, 3), cats, donut: `conic-gradient(${stops.join(',')})`, weeks, selDay, week, wdHead: WD.map((w) => w.toUpperCase()),
      accounts: ACCS.map((a) => { const l = s.tx.filter((t) => t.acc === a); const bal = { Yape: 482.4, BCP: 2310.75, 'BBVA Visa': -612.3, Efectivo: 145 }[a]; return { name: a, balF: f(bal), neg: bal < 0, count: l.length + ' movimientos', color: { Yape: '#7C3AED', BCP: '#2563EB', 'BBVA Visa': '#0EA5E9', Efectivo: '#16A34A' }[a], icon: { Yape: 'qr_code_2', BCP: 'account_balance', 'BBVA Visa': 'credit_card', Efectivo: 'payments' }[a] }; }),
      inbox, inboxCount: nIn, hasInbox: nIn > 0, inboxEmpty: nIn === 0, inboxLabel: nIn + (nIn === 1 ? ' pendiente' : ' pendientes'), inboxMany: s.inbox.filter((x) => x.cat && x.amt > 0).length > 1,
      approveAll: () => { const ok = s.inbox.filter((x) => x.cat && x.amt > 0); ok.forEach((x) => addTx({ note: x.note, amt: Number(x.amt), cat: x.cat, acc: x.acc, src: 'Por revisar' })); c.setState((st) => ({ inbox: st.inbox.filter((x) => !(x.cat && x.amt > 0)) })); toast(ok.length + ' aprobados'); },
      perms, permLabel: nOk + ' de 5 listos', permW: (nOk / 5 * 100) + '%', mandOk, permMissing: missing, permTitle: mandOk ? 'Captura lista' : 'Faltan ' + missing + ' permisos obligatorios', permColor: mandOk ? o.ok : o.warn,
      rules, rulesOn: s.rules.filter((r) => r.on).length + ' activas',
      features: [
        ['share', 'Compartir 1 imagen', 'Desde Yape · caso “Yapeaste”', startOne], ['burst_mode', 'Compartir 7 imágenes', 'Lote con éxito, duplicado y errores', startBatch],
        ['screenshot_monitor', 'Captura en segundo plano', mandOk ? 'Lista · simula una captura' : 'Requiere permisos de HyperOS', startBg], ['notifications', 'Ver notificación fija', 'Panel de notificaciones', () => set({ shade: true, dial: false })],
        ['inbox', 'Bandeja Por revisar', nIn + (nIn === 1 ? ' pendiente' : ' pendientes'), go('inbox')], ['verified_user', 'Permisos HyperOS', nOk + ' de 5 listos', go('perms')], ['rule', 'Reglas de captura', 'Ingreso/gasto, cuenta, categoría', go('rules')],
      ].map(([icon, title, sub, onClick], i) => ({ icon, title, sub, onClick, n: i + 1, first: i === 0, warn: (i === 2 && !mandOk) || (i === 4 && nIn > 0) || (i === 5 && !mandOk) })),
      startOne, startBatch, startBg, openShade: () => set({ shade: true, dial: false }),
      capOn: s.capOn, capLabel: s.capOn ? 'Captura activa' : 'Captura en pausa', capColor: s.capOn ? o.ok : o.muted, capTrack: s.capOn ? o.on : o.off, capKnob: s.capOn ? '22px' : '2px', toggleCap: () => { set({ capOn: !s.capOn }); toast(s.capOn ? 'Captura en pausa' : 'Captura reanudada'); },
      dial: s.dial, toggleDial: () => set({ dial: !s.dial }), closeDial: () => set({ dial: false }),
      dialItems: [['share', 'Compartir 1 imagen', startOne], ['burst_mode', 'Compartir 7 imágenes', startBatch], ['screenshot_monitor', 'Captura en segundo plano', startBg]].map(([icon, label, onClick]) => ({ icon, label, onClick })),
      // themed flow sheet
      flowSheet: !!fl && ['reading', 'done', 'blocked'].includes(fl.stage), flowReading: !!fl && fl.stage === 'reading', flowDone: !!fl && fl.stage === 'done', flowBlocked: !!fl && fl.stage === 'blocked',
      flowOne: !!fl && fl.kind === 'one', flowBatch: !!fl && fl.kind === 'batch', oneReading: !!fl && fl.kind === 'one' && fl.stage === 'reading', oneDone: !!fl && fl.kind === 'one' && fl.stage === 'done', batchOn: !!fl && fl.kind === 'batch' && fl.stage !== 'source' && fl.stage !== 'sheet', batchDone: !!fl && fl.kind === 'batch' && fl.stage === 'done',
      flowTitle: !fl ? '' : fl.stage === 'blocked' ? 'Faltan permisos' : fl.kind === 'one' ? (fl.stage === 'done' ? 'Registrado' : 'Leyendo comprobante…') : (fl.stage === 'done' ? '7 imágenes procesadas' : `Leyendo ${bi} de 7…`),
      batchW: (bi / 7 * 100) + '%', batchItems, batchSummary: '4 registrados · 1 duplicado · 2 con error',
      one: { note: 'Yapeaste a Bodega Don Lucho', amtF: f(23.5), cat: 'Mercado', acc: 'Yape', icon: CATS.Mercado[0], color: CATS.Mercado[1], soft: CATS.Mercado[1] + '22', when: 'Hoy · 21:38', rule: 'Regla “Yapeaste” → Gasto · Yape', ocr: 'Lectura 97%' },
      blockedSub: `Para capturar en segundo plano, HyperOS necesita ${missing} permisos más.`,
      closeFlow: () => { clearTimeout(c._fl); set({ flow: null }); }, undoFlow: () => { rmTx((fl && fl.ids) || []); set({ flow: null }); toast('Registro deshecho'); },
      flowToPerms: go('perms'), flowToInbox: go('inbox'),
      // system overlays (child DC)
      sysOn: (!!fl && (fl.stage === 'source' || fl.stage === 'sheet')) || s.shade || s.heads || s.flash,
      sysYape: !!fl && fl.kind === 'one' && fl.stage === 'source', sysGallery: !!fl && fl.kind === 'batch' && fl.stage === 'source', sysSheet: !!fl && fl.stage === 'sheet', sysShade: s.shade, sysHeads: s.heads, sysFlash: s.flash,
      sheetTitle: fl && fl.kind === 'batch' ? 'Compartir 7 imágenes' : 'Compartir 1 imagen',
      sysToSheet: () => set({ flow: Object.assign({}, fl, { stage: 'sheet' }) }), sysPick: pick, sysClose: () => { clearTimeout(c._fl); set({ flow: null, shade: false, heads: false }); },
      shadeSub: (s.capOn ? 'Captura activa' : 'En pausa') + ' · ' + nIn + ' por revisar', shadeToggle: s.capOn ? 'Pausar' : 'Reanudar',
      shadeOpen: go('inbox'), shadeCapture: startBg, shadeToggleCap: () => set({ capOn: !s.capOn }),
      headsText: 'Plin a Tottus · S/ 18.00', headsCat: s.headsCat || 'Mercado', headsCycle: () => { const L = ['Mercado', 'Comida', 'Compras', 'Otros']; set({ headsCat: L[(L.indexOf(s.headsCat || 'Mercado') + 1) % L.length] }); }, headsSave: () => { set({ heads: false }); const id = addTx({ note: 'Plin a Tottus', amt: 18, cat: s.headsCat || 'Mercado', acc: 'BCP', src: 'Captura' }); toast('Guardado desde captura', id); },
      headsReview: () => { c.setState((st) => ({ heads: false, inbox: [...st.inbox, { id: 'ih' + Date.now(), note: 'Plin a Tottus', amt: 18, cat: '', acc: 'BCP', src: 'Captura · 21:40', why: 'Confirma la categoría' }] })); toast('Enviado a Por revisar'); },
      hasToast: !!s.toast, toastText: s.toast ? s.toast.text : '', toastUndo: !!(s.toast && s.toast.undo), undoToast: () => { rmTx([s.toast.undo]); set({ toast: null }); },
    };
    return V;
  }
  return { init, build, cleanup, f, f0, CATS };
})();
