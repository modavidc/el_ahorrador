(function () {
  const R = window.React, e = R.createElement;
  const L = 12.6; let SC = 0.74;
  const cl = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const p = (t, a, b) => cl((t - a) / (b - a));
  const eo = x => 1 - Math.pow(1 - x, 3);
  const eio = x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  const SEG = [[0, 3.2, 'Paga'], [3.2, 5.3, 'Compartir'], [5.3, 8.4, 'El Ahorrador'], [8.4, L, 'Listo']];
  const FK = [[0, 190, 470, 0], [0.9, 125, 425, 1], [1.3, 110, 392, 1], [1.6, 110, 392, 1], [2.9, 70, 408, 1], [3.3, 60, 400, 1], [3.6, 60, 400, 1], [4.3, 150, 335, 1], [4.8, 192, 296, 1], [5.15, 192, 296, 1], [5.6, 235, 360, 0], [L, 235, 360, 0]];
  const TAPS = [1.4, 3.4, 5.0];
  const YP = '#6F2A8C';
  const ms = (name, size, color, extra) => e('span', { className: 'ms', 'aria-hidden': 'true', style: Object.assign({ fontSize: size, color, lineHeight: 1 }, extra || {}) }, name);
  const abs = (s) => Object.assign({ position: 'absolute' }, s);

  function finger(t) {
    let i = 0; while (i < FK.length - 2 && t > FK[i + 1][0]) i++;
    const a = FK[i], b = FK[i + 1], k = eio(p(t, a[0], b[0]));
    const x = a[1] + (b[1] - a[1]) * k, y = a[2] + (b[2] - a[2]) * k, o = a[3] + (b[3] - a[3]) * k;
    const tap = TAPS.find(tt => t >= tt && t < tt + .5);
    const pr = tap != null ? p(t, tap, tap + .5) : 0;
    const press = tap != null && t < tap + .18;
    return [
      tap != null ? e('span', { key: 'rip', style: abs({ left: x - 22, top: y - 22, width: 44, height: 44, borderRadius: 999, border: '2px solid rgba(255,255,255,.9)', boxShadow: '0 0 0 1px rgba(0,0,0,.15)', transform: `scale(${.4 + pr * .9})`, opacity: 1 - pr, pointerEvents: 'none', zIndex: 30 }) }) : null,
      e('span', { key: 'f', style: abs({ left: x - 14, top: y - 14, width: 28, height: 28, borderRadius: 999, background: 'rgba(255,255,255,.55)', border: '1.5px solid rgba(0,0,0,.35)', boxShadow: '0 4px 12px rgba(0,0,0,.25)', opacity: o, transform: `scale(${press ? .82 : 1})`, transition: 'transform .12s', pointerEvents: 'none', zIndex: 31 }) })
    ];
  }

  function payScreen(t, sym) {
    const amt = t < .45 ? '' : t < .75 ? '1' : '16';
    const pressed = t >= 1.4 && t < 1.6;
    return e('div', { key: 'pay', style: abs({ inset: 0, background: '#fff', display: 'flex', flexDirection: 'column' }) },
      e('div', { style: { background: YP, color: '#fff', padding: '26px 14px 14px', display: 'flex', alignItems: 'center', gap: 8 } },
        ms('arrow_back', 16, '#fff'), e('span', { style: { fontSize: 12, fontWeight: 600 } }, 'Yapear a')),
      e('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '22px 14px 0' } },
        e('span', { style: { width: 44, height: 44, borderRadius: 999, background: '#EDE3F2', color: YP, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, fontWeight: 700 } }, 'RQ'),
        e('span', { style: { fontSize: 13, fontWeight: 600, color: '#222' } }, 'Rosa Quispe M.'),
        e('span', { style: { fontSize: 10, color: '#888' } }, '••• ••• 482'),
        e('div', { style: { marginTop: 26, display: 'flex', alignItems: 'baseline', gap: 4, color: '#222', borderBottom: `2px solid ${YP}`, padding: '0 16px 4px', minWidth: 120, justifyContent: 'center' } },
          e('span', { style: { fontSize: 18, fontWeight: 600 } }, 'S/'),
          e('span', { style: { fontSize: 40, fontWeight: 700, minWidth: 10 } }, amt),
          e('span', { style: { width: 2, height: 32, background: YP, opacity: Math.floor(t * 2.5) % 2 ? 0 : 1, alignSelf: 'center' } })),
        e('span', { style: { fontSize: 10, color: '#888', marginTop: 10 } }, 'Almuerzo')),
      e('div', { style: abs({ left: 16, right: 16, top: 372, height: 40, borderRadius: 999, background: YP, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, fontWeight: 700, opacity: amt ? 1 : .45, transform: `scale(${pressed ? .96 : 1})`, transition: 'transform .12s, opacity .2s' }) }, 'Yapear'));
  }

  function successScreen(t, sym) {
    const k = eo(p(t, 1.8, 2.15));
    const pressed = t >= 3.4 && t < 3.6;
    return e('div', { key: 'ok', style: abs({ inset: 0, background: YP, color: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '40px 14px 0', opacity: k, transform: `scale(${.96 + .04 * k})` }) },
      e('span', { style: { width: 40, height: 40, borderRadius: 999, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${eo(p(t, 1.95, 2.35))})` } }, ms('check', 26, YP)),
      e('span', { style: { fontSize: 18, fontWeight: 700, marginTop: 12 } }, '¡Yapeaste!'),
      e('div', { style: { display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 8 } }, e('span', { style: { fontSize: 18, fontWeight: 600 } }, 'S/'), e('span', { style: { fontSize: 44, fontWeight: 700, lineHeight: 1 } }, '16')),
      e('span', { style: { fontSize: 13, fontWeight: 600, marginTop: 10 } }, 'Rosa Quispe M.'),
      e('span', { style: { fontSize: 10, opacity: .8, marginTop: 4 } }, '26 set. 2026 · 01:12 p. m.'),
      e('div', { style: { marginTop: 22, width: '100%', background: '#fff', color: '#333', borderRadius: 12, padding: '10px 12px', display: 'flex', flexDirection: 'column', gap: 8, fontSize: 10 } },
        e('div', { style: { display: 'flex', justifyContent: 'space-between' } }, e('span', { style: { color: '#888' } }, 'Nro. de operación'), e('span', { style: { fontWeight: 600 } }, '04812345')),
        e('div', { style: { display: 'flex', justifyContent: 'space-between' } }, e('span', { style: { color: '#888' } }, 'Destino'), e('span', { style: { fontWeight: 600 } }, 'Yape'))),
      e('div', { style: abs({ left: 12, right: 12, top: 382, height: 36, display: 'flex', gap: 8 }) },
        e('div', { style: { flex: 1, borderRadius: 999, background: '#fff', color: YP, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: 11, fontWeight: 700, transform: `scale(${pressed ? .94 : 1})`, transition: 'transform .12s', boxShadow: t > 2.6 && t < 3.4 ? '0 0 0 3px rgba(255,255,255,.35)' : 'none' } }, ms('share', 14, YP), 'Compartir'),
        e('div', { style: { flex: 1, borderRadius: 999, border: '1.5px solid rgba(255,255,255,.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 700 } }, 'Ir a inicio')));
  }

  function shareSheet(t) {
    const k = eo(p(t, 3.55, 3.95));
    const sel = t >= 5.0;
    const apps = [['chat', '#25A55F', 'WhatsApp'], ['mail', '#D0463B', 'Gmail'], ['cloud_upload', '#3B7BD6', 'Drive'], ['MM', 'var(--accent)', 'El Ahorrador'], ['sms', '#3C8C7E', 'Mensajes'], ['bluetooth', '#5A6B85', 'Bluetooth'], ['content_copy', '#6B6B6B', 'Copiar'], ['more_horiz', '#6B6B6B', 'Más']];
    return e('div', { key: 'sh', style: abs({ inset: 0, zIndex: 5 }) },
      e('div', { style: abs({ inset: 0, background: 'rgba(0,0,0,.45)', opacity: k }) }),
      e('div', { style: abs({ left: 0, right: 0, bottom: 0, height: 212, background: '#fff', borderRadius: '16px 16px 0 0', transform: `translateY(${(1 - k) * 100}%)`, padding: '8px 0 0', display: 'flex', flexDirection: 'column' }) },
        e('span', { style: { width: 28, height: 3, borderRadius: 9, background: '#D5D5D8', alignSelf: 'center' } }),
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 8, padding: '10px 14px 6px' } },
          e('span', { style: { width: 22, height: 30, borderRadius: 4, background: YP, flex: 'none' } }),
          e('div', { style: { display: 'flex', flexDirection: 'column' } }, e('span', { style: { fontSize: 11, fontWeight: 600, color: '#222' } }, 'Compartir imagen'), e('span', { style: { fontSize: 9, color: '#888' } }, 'constancia-yape.png'))),
        e('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', rowGap: 10, padding: '8px 0 0' } },
          apps.map(([ic, bg, lb], i) => {
            const mm = ic === 'MM';
            const pulse = mm && sel ? 1 + .12 * Math.sin(p(t, 5.0, 5.35) * Math.PI) : 1;
            return e('div', { key: i, style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 } },
              e('span', { style: { width: 40, height: 40, borderRadius: mm ? 12 : 999, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${pulse})`, boxShadow: mm && t > 4.4 ? '0 0 0 3px var(--surface), 0 0 0 5px var(--accent)' : 'none', transition: 'box-shadow .25s' } }, mm ? ms('savings', 22, 'var(--accent-ink)', { fontVariationSettings: "'FILL' 1" }) : ms(ic, 20, '#fff')),
              e('span', { style: { fontSize: 8.5, color: '#333', fontWeight: mm ? 700 : 400, textAlign: 'center', lineHeight: 1.15, maxWidth: 52 } }, lb));
          }))));
  }

  function mmScreen(t, sym) {
    const k = eo(p(t, 5.3, 5.7));
    const reading = t < 6.45;
    const rows = [['payments', 'Monto', sym + ' 16.00', 6.45], ['restaurant', 'Categoría', 'Almuerzo', 6.95], ['account_balance', 'Cuenta', 'BCP Soles · Yape', 7.45]];
    const done = eo(p(t, 7.95, 8.3));
    const scanY = 8 + ((t - 5.5) % .9) / .9 * 94;
    return e('div', { key: 'mm', style: abs({ inset: 0, zIndex: 8, background: 'var(--surface)', transform: `translateY(${(1 - k) * 100}%)`, display: 'flex', flexDirection: 'column', padding: '26px 14px 0' }) },
      e('div', { style: { display: 'flex', alignItems: 'center', gap: 8 } },
        e('span', { style: { width: 20, height: 20, borderRadius: 6, background: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center' } }, ms('savings', 13, 'var(--accent-ink)', { fontVariationSettings: "'FILL' 1" })),
        e('span', { style: { fontSize: 12, fontWeight: 600, color: 'var(--ink)' } }, 'El Ahorrador')),
      e('div', { style: { alignSelf: 'center', marginTop: 18, width: 78, height: 112, borderRadius: 8, background: YP, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 8px', gap: 5, boxShadow: 'var(--e3)' } },
        e('span', { style: { width: 14, height: 14, borderRadius: 99, background: '#fff' } }),
        e('span', { style: { width: 40, height: 4, borderRadius: 2, background: 'rgba(255,255,255,.9)' } }),
        e('span', { style: { fontSize: 15, fontWeight: 700, color: '#fff', lineHeight: 1 } }, 'S/ 16'),
        e('span', { style: { width: 48, height: 3, borderRadius: 2, background: 'rgba(255,255,255,.6)' } }),
        e('span', { style: { width: '100%', height: 24, borderRadius: 4, background: '#fff', marginTop: 4 } }),
        reading ? e('span', { style: abs({ left: 0, right: 0, top: scanY, height: 2, background: 'var(--accent)', boxShadow: '0 0 0 1px rgba(255,255,255,.4)' }) }) : null,
        !reading ? e('span', { style: abs({ inset: 0, border: '2px solid var(--success)', borderRadius: 8, opacity: eo(p(t, 6.45, 6.7)) }) }) : null),
      e('div', { style: { height: 20, marginTop: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: 11, color: 'var(--ink-2)' } },
        reading ? [e('span', { key: 's', style: { width: 12, height: 12, borderRadius: 99, border: '2px solid var(--line-strong)', borderTopColor: 'var(--accent)', transform: `rotate(${t * 720}deg)` } }), e('span', { key: 'l' }, 'Leyendo comprobante')] : e('span', null, 'Comprobante leído')),
      e('div', { style: { display: 'flex', flexDirection: 'column', marginTop: 8, borderTop: '1px solid var(--line)' } },
        rows.map(([ic, lb, v, at], i) => {
          const r = eo(p(t, at, at + .3));
          return e('div', { key: i, style: { display: 'flex', alignItems: 'center', gap: 10, height: 42, borderBottom: '1px solid var(--line)', opacity: r, transform: `translateY(${(1 - r) * 8}px)` } },
            e('span', { style: { width: 26, height: 26, borderRadius: 8, background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' } }, ms(ic, 15, 'var(--ink-2)')),
            e('span', { style: { fontSize: 10, color: 'var(--ink-2)', width: 52 } }, lb),
            e('span', { style: { flex: 1, fontSize: 11.5, fontWeight: 600, color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, v),
            ms('check_circle', 16, 'var(--success)', { fontVariationSettings: "'FILL' 1", transform: `scale(${eo(p(t, at + .15, at + .4))})` }));
        })),
      e('div', { style: abs({ left: 14, right: 14, top: 382, height: 38, borderRadius: 999, background: 'var(--success)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: 12, fontWeight: 700, opacity: done, transform: `scale(${.9 + .1 * done})` }) }, ms('check', 16, '#fff'), 'Guardado'));
  }

  function listScreen(t, sym) {
    const k = eo(p(t, 8.3, 8.65));
    const ins = eo(p(t, 8.8, 9.25));
    const hl = 1 - p(t, 10.2, 11.2);
    const toast = eo(p(t, 9.3, 9.6)) * (1 - p(t, 11.3, 11.6));
    const row = (ic, n, sub, a, extra) => e('div', { style: Object.assign({ display: 'flex', alignItems: 'center', gap: 10, height: 48, padding: '0 14px', borderBottom: '1px solid var(--line)' }, extra || {}) },
      e('span', { style: { width: 30, height: 30, borderRadius: 8, background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' } }, ms(ic, 17, 'var(--ink-2)')),
      e('div', { style: { flex: 1, minWidth: 0 } }, e('div', { style: { fontSize: 11.5, fontWeight: 500, color: 'var(--ink)' } }, n), e('div', { style: { fontSize: 9.5, color: 'var(--ink-2)', marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, sub)),
      e('span', { style: { fontSize: 11.5, fontWeight: 600, color: 'var(--ink)', whiteSpace: 'nowrap' } }, '− ' + sym + ' ' + a));
    return e('div', { key: 'ls', style: abs({ inset: 0, zIndex: 10, background: 'var(--canvas)', opacity: k, display: 'flex', flexDirection: 'column' }) },
      e('div', { style: { background: 'var(--surface)', padding: '26px 14px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' } }, e('span', { style: { fontSize: 16, fontWeight: 600, color: 'var(--ink)' } }, 'Movimientos'), ms('search', 18, 'var(--ink)')),
      e('div', { style: { background: 'var(--surface)', marginTop: 8 } },
        e('div', { style: { padding: '10px 14px 6px', fontSize: 10, color: 'var(--ink-2)', display: 'flex', justifyContent: 'space-between' } }, e('span', null, 'Hoy · dom 27'), e('span', null, '− ' + sym + ' ' + (t > 9 ? '39.40' : '23.40'))),
        e('div', { style: { height: 48 * ins, overflow: 'hidden' } },
          row('restaurant', 'Rosa Quispe M.', 'Almuerzo · BCP Soles · Yape', '16.00', { background: `color-mix(in oklab, var(--accent) ${Math.round(hl * 12)}%, var(--surface))` })),
        row('local_cafe', 'Café Tostado', 'Café · BCP Soles · Yape', '8.50'),
        row('local_taxi', 'Uber a oficina', 'Taxi · BCP Visa', '14.90')),
      e('div', { style: { background: 'var(--surface)', marginTop: 8 } },
        e('div', { style: { padding: '10px 14px 6px', fontSize: 10, color: 'var(--ink-2)' } }, 'Ayer · sáb 26'),
        row('shopping_cart', 'Plaza Vea', 'Supermercado · BCP Visa', '186.30'),
        row('delivery_dining', 'Rappi · pizza', 'Delivery · BCP Visa', '42.00')),
      e('div', { style: abs({ left: 12, right: 12, top: 388, height: 36, borderRadius: 10, background: '#222', color: '#fff', display: 'flex', alignItems: 'center', padding: '0 12px', gap: 8, fontSize: 11, opacity: toast, transform: `translateY(${(1 - toast) * 14}px)` }) },
        ms('check_circle', 15, '#7ED3A0', { fontVariationSettings: "'FILL' 1" }), e('span', { style: { flex: 1 } }, 'Registrado · ' + sym + ' 16.00'), e('span', { style: { fontWeight: 700, color: '#FFB4A8' } }, 'Deshacer')));
  }

  function ShareDemo(props) {
    const sym = props.sym || 'S/'; SC = props.scale || 0.74;
    const [t, setT] = R.useState(0);
    const [playing, setPlaying] = R.useState(true);
    const ref = R.useRef({ t: 0, last: 0 });
    R.useEffect(() => {
      if (!playing) return;
      const r0 = ref.current; r0.last = performance.now();
      const id = setInterval(() => { const r = ref.current, now = performance.now(); r.t = (r.t + Math.min(.1, (now - r.last) / 1000)) % L; r.last = now; setT(r.t); }, 33);
      return () => clearInterval(id);
    }, [playing]);
    const seek = (s) => { ref.current.t = s; setT(s); };
    const loopFade = 1 - p(t, L - .3, L);
    const layers = [];
    if (t < 2.2) layers.push(payScreen(t, sym));
    if (t >= 1.8 && t < 5.8) layers.push(successScreen(t, sym));
    if (t >= 3.5 && t < 5.8) layers.push(shareSheet(t));
    if (t >= 5.3 && t < 8.7) layers.push(mmScreen(t, sym));
    if (t >= 8.3) layers.push(listScreen(t, sym));
    const cur = SEG.findIndex(s => t >= s[0] && t < s[1]);
    return e('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, background: 'var(--surface-2)', borderRadius: 16, padding: '14px 12px 8px' } },
      e('div', { style: { width: 236 * SC, height: 456 * SC, flex: 'none' } },
      e('div', { role: 'img', 'aria-label': 'Animación: pagas con Yape, tocas Compartir, eliges El Ahorrador y el movimiento se registra solo', style: { width: 236, height: 456, borderRadius: 30, border: '8px solid #111', background: '#111', position: 'relative', overflow: 'hidden', boxShadow: '0 14px 34px rgba(0,0,0,.22)', transform: `scale(${SC})`, transformOrigin: '0 0' } },
        e('div', { style: abs({ inset: 0, overflow: 'hidden', borderRadius: 22, opacity: loopFade, fontFamily: 'inherit' }) },
          layers,
          e('div', { style: abs({ left: 0, right: 0, top: 0, height: 20, zIndex: 20, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 12px', fontSize: 9, fontWeight: 600, color: t < 5.3 ? '#fff' : 'var(--ink)' }) }, e('span', null, '13:12'), e('span', { style: { display: 'flex', gap: 3 } }, ms('signal_cellular_alt', 10, 'inherit'), ms('wifi', 10, 'inherit'), ms('battery_full', 10, 'inherit'))),
          finger(t)))),
      e('div', { style: { width: '100%', display: 'flex', alignItems: 'center', gap: 10 } },
        e('button', { onClick: () => setPlaying(!playing), 'aria-label': playing ? 'Pausar' : 'Reproducir', style: { width: 32, height: 32, borderRadius: 999, border: 'none', background: 'var(--surface)', color: 'var(--ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flex: 'none', padding: 0 } }, ms(playing ? 'pause' : 'play_arrow', 20, 'var(--ink)', { fontVariationSettings: "'FILL' 1" })),
        e('div', { style: { flex: 1, display: 'grid', gridTemplateColumns: SEG.map(s => (s[1] - s[0]) + 'fr').join(' '), gap: 4 } },
          SEG.map((s, i) => e('button', { key: i, onClick: () => seek(s[0] + .01), 'aria-label': 'Ir a ' + s[2], style: { border: 'none', background: 'transparent', padding: '4px 0', cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: 5, minWidth: 0, textAlign: 'left' } },
            e('span', { style: { height: 3, borderRadius: 9, background: 'var(--line-strong)', overflow: 'hidden', display: 'block' } }, e('span', { style: { display: 'block', height: '100%', background: 'var(--ink)', width: (p(t, s[0], s[1]) * 100) + '%' } })),
            e('span', { style: { fontSize: 10.5, fontWeight: i === cur ? 600 : 400, color: i === cur ? 'var(--ink)' : 'var(--ink-2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, s[2]))))));
  }
  window.ShareDemoAhorrador = ShareDemo;
  if (typeof module !== 'undefined') module.exports = { ShareDemoAhorrador: ShareDemo };
})();
