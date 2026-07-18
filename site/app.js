/* ------------------------------------------------------------------ i18n */
const STRINGS = {
  en: {
    "nav.how": "How it works",
    "nav.features": "Features",
    "nav.install": "Install",
    "hero.eyebrow": "macOS menu bar app · free & open source",
    "hero.line1": "Your desk just",
    "hero.line2": "became a keyboard.",
    "hero.lede": "Tap Spaces listens for the sound of a knock, works out which corner of the desk you hit, and fires the shortcut you bound to that spot. Everything runs on-device — audio is never recorded or sent anywhere.",
    "hero.get": "Get it with Homebrew",
    "hero.download": "Download",
    "zone.TL": "Top left",
    "zone.TR": "Top right",
    "zone.BL": "Bottom left",
    "zone.BR": "Bottom right",
    "desk.hint": "Tap anywhere on the desk",
    "desk.sound": "sound",
    "desk.caption": "This is how it feels — on the real desk your knuckles do the clicking.",
    "how.title": "One knock, three moves",
    "how.1.t": "The mic hears the hit",
    "how.1.d": "A knock is a broadband transient. The detector high-passes the stream, catches the onset and freezes a 200 ms window around it.",
    "how.2.t": "The spot is fingerprinted",
    "how.2.d": "Every point on your desk rings differently. 56 acoustic features — spectrum, decay, resonance — are matched against your calibration taps.",
    "how.3.t": "The shortcut fires",
    "how.3.d": "The zone's key combo is posted to whatever app is frontmost. Default bindings switch desktops and open Mission Control — rebind them to anything.",
    "ft.title": "Small app, sharp edges",
    "ft.private.t": "Private by design",
    "ft.private.d": "No network code in the binary. Audio lives in memory for a fifth of a second, becomes 56 numbers, and is gone. Nothing is recorded, nothing leaves the Mac.",
    "ft.zones.t": "Four zones, any shortcut",
    "ft.zones.d": "Each corner of the desk holds one binding — including combos macOS reserves for itself, like ⌃← and ⌘⇥.",
    "ft.cal.t": "Calibrates in a minute",
    "ft.cal.d": "Tap each zone 20–30 times, watch the accuracy number climb. Leave-one-out cross-validation, honestly reported.",
    "ft.menubar.t": "Menu bar only",
    "ft.menubar.d": "No Dock icon, no window in your way. A quiet status item that tells you the model's accuracy at a glance.",
    "ft.signed.t": "Signed and notarised",
    "ft.signed.d": "Developer ID signature, Apple notarisation, hardened runtime. Opens without a Gatekeeper warning.",
    "ft.open.t": "Open source",
    "ft.open.d": "Swift, no dependencies, every DSP decision documented in the code. Read it, build it, bend it.",
    "shots.caption": "Calibration board, live confidence per zone, and the toast that confirms every fired shortcut.",
    "in.title": "Install",
    "in.copy": "Copy",
    "in.copied": "Copied",
    "in.c1": "# add the tap and allow it",
    "in.c2": "# install",
    "in.note": "Needs macOS 14 or newer. On first run the app walks you through its two permissions: Microphone, to hear the taps, and Accessibility, to press the keys.",
    "fo.source": "Source",
    "fo.releases": "Releases",
    "fo.tap": "Homebrew tap",
    "title": "Tap Spaces — your desk just became a keyboard",
  },
  tr: {
    "nav.how": "Nasıl çalışır",
    "nav.features": "Özellikler",
    "nav.install": "Kurulum",
    "hero.eyebrow": "macOS menü çubuğu uygulaması · ücretsiz ve açık kaynak",
    "hero.line1": "Masan artık",
    "hero.line2": "bir klavye.",
    "hero.lede": "Tap Spaces vuruş sesini dinler, masanın hangi köşesine vurduğunu çözer ve o noktaya bağladığın kısayolu çalıştırır. Her şey cihaz üzerinde döner — ses hiçbir zaman kaydedilmez veya gönderilmez.",
    "hero.get": "Homebrew ile kur",
    "hero.download": "İndir",
    "zone.TL": "Sol üst",
    "zone.TR": "Sağ üst",
    "zone.BL": "Sol alt",
    "zone.BR": "Sağ alt",
    "desk.hint": "Masanın herhangi bir yerine vur",
    "desk.sound": "ses",
    "desk.caption": "His tam olarak bu — gerçek masada tıklamayı parmak boğumların yapar.",
    "how.title": "Tek vuruş, üç hamle",
    "how.1.t": "Mikrofon vuruşu duyar",
    "how.1.d": "Vuruş geniş bantlı bir geçici sinyaldir. Dedektör akışı yüksek geçiren filtreden geçirir, başlangıcı yakalar ve etrafındaki 200 ms'lik pencereyi dondurur.",
    "how.2.t": "Nokta parmak izine çevrilir",
    "how.2.d": "Masanın her noktası farklı tınlar. 56 akustik özellik — spektrum, sönüm, rezonans — kalibrasyon vuruşlarınla karşılaştırılır.",
    "how.3.t": "Kısayol ateşlenir",
    "how.3.d": "Bölgenin tuş kombinasyonu öndeki uygulamaya gönderilir. Varsayılanlar masaüstü değiştirir ve Mission Control açar — hepsini yeniden bağlayabilirsin.",
    "ft.title": "Küçük uygulama, keskin ayrıntılar",
    "ft.private.t": "Tasarım gereği gizli",
    "ft.private.d": "Binary'de ağ kodu yok. Ses bellekte saniyenin beşte biri kadar yaşar, 56 sayıya dönüşür ve yok olur. Hiçbir şey kaydedilmez, hiçbir şey Mac'ten çıkmaz.",
    "ft.zones.t": "Dört bölge, her kısayol",
    "ft.zones.d": "Masanın her köşesi bir bağ tutar — macOS'un kendine ayırdığı ⌃← ve ⌘⇥ gibi kombinasyonlar dahil.",
    "ft.cal.t": "Bir dakikada kalibre olur",
    "ft.cal.d": "Her bölgeye 20–30 kez vur, doğruluk sayısının yükselişini izle. Leave-one-out çapraz doğrulama, dürüstçe raporlanır.",
    "ft.menubar.t": "Sadece menü çubuğu",
    "ft.menubar.d": "Dock simgesi yok, yolunu kesen pencere yok. Modelin doğruluğunu tek bakışta söyleyen sessiz bir durum simgesi.",
    "ft.signed.t": "İmzalı ve notarize",
    "ft.signed.d": "Developer ID imzası, Apple notarization, hardened runtime. Gatekeeper uyarısı olmadan açılır.",
    "ft.open.t": "Açık kaynak",
    "ft.open.d": "Swift, bağımlılık yok, her DSP kararı kodda belgeli. Oku, derle, kendine göre bük.",
    "shots.caption": "Kalibrasyon panosu, bölge başına canlı güven ve her ateşlenen kısayolu doğrulayan bildirim.",
    "in.title": "Kurulum",
    "in.copy": "Kopyala",
    "in.copied": "Kopyalandı",
    "in.c1": "# tap'i ekle ve izin ver",
    "in.c2": "# kur",
    "in.note": "macOS 14 veya üzeri gerekir. İlk açılışta uygulama iki iznini adım adım anlatır: vuruşları duymak için Mikrofon, tuşlara basmak için Erişilebilirlik.",
    "fo.source": "Kaynak",
    "fo.releases": "Sürümler",
    "fo.tap": "Homebrew tap",
    "title": "Tap Spaces — masan artık bir klavye",
  },
};

let lang = localStorage.getItem("ts-lang")
  || (navigator.language?.startsWith("tr") ? "tr" : "en");

function applyLang() {
  const dict = STRINGS[lang];
  document.documentElement.lang = lang;
  document.title = dict["title"];
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const s = dict[el.dataset.i18n];
    if (s) el.textContent = s;
  });
  document.querySelectorAll("[data-lang-opt]").forEach((el) =>
    el.classList.toggle("on", el.dataset.langOpt === lang));
}

document.getElementById("langToggle").addEventListener("click", () => {
  lang = lang === "en" ? "tr" : "en";
  localStorage.setItem("ts-lang", lang);
  applyLang();
});
applyLang();

/* ------------------------------------------------------------------ desk */
const desk = document.getElementById("desk");
const toast = document.getElementById("toast");
const toastZone = document.getElementById("toastZone");
const toastKey = document.getElementById("toastKey");
const meter = document.getElementById("meter");
const soundToggle = document.getElementById("soundToggle");

const KEYS = { TL: "⌃↑", TR: "⌃↓", BL: "⌃←", BR: "⌃→" };
const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

let soundOn = false;
let audioCtx = null;

soundToggle.addEventListener("click", (e) => {
  e.stopPropagation();
  soundOn = !soundOn;
  soundToggle.setAttribute("aria-pressed", String(soundOn));
});

/* A knock, synthesised: a low thump plus a short noise click. */
function knock() {
  if (!soundOn) return;
  audioCtx ||= new (window.AudioContext || window.webkitAudioContext)();
  const t = audioCtx.currentTime;

  const thump = audioCtx.createOscillator();
  const thumpGain = audioCtx.createGain();
  thump.frequency.setValueAtTime(160, t);
  thump.frequency.exponentialRampToValueAtTime(52, t + 0.09);
  thumpGain.gain.setValueAtTime(0.5, t);
  thumpGain.gain.exponentialRampToValueAtTime(0.001, t + 0.16);
  thump.connect(thumpGain).connect(audioCtx.destination);
  thump.start(t); thump.stop(t + 0.18);

  const len = Math.floor(audioCtx.sampleRate * 0.03);
  const buf = audioCtx.createBuffer(1, len, audioCtx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const click = audioCtx.createBufferSource();
  click.buffer = buf;
  const clickGain = audioCtx.createGain();
  clickGain.gain.value = 0.12;
  const bp = audioCtx.createBiquadFilter();
  bp.type = "bandpass"; bp.frequency.value = 2400; bp.Q.value = 0.8;
  click.connect(bp).connect(clickGain).connect(audioCtx.destination);
  click.start(t);
}

let toastTimer = null;
let meterTimer = null;

function tapAt(x, y) {
  const rect = desk.getBoundingClientRect();
  desk.classList.add("touched");

  // ripples from the exact hit point
  for (const cls of ["", "r2", "r3"]) {
    const r = document.createElement("i");
    r.className = "ripple " + cls;
    r.style.left = x + "px";
    r.style.top = y + "px";
    desk.appendChild(r);
    r.addEventListener("animationend", () => r.remove());
  }

  // which quadrant was hit
  const zone = (y < rect.height / 2 ? "T" : "B") + (x < rect.width / 2 ? "L" : "R");
  desk.querySelectorAll(".dz").forEach((el) => {
    el.classList.toggle("hit", el.dataset.zone === zone);
  });

  // toast, exactly like the app's
  toastZone.textContent = STRINGS[lang]["zone." + zone];
  toastKey.textContent = KEYS[zone];
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    toast.classList.remove("show");
    desk.querySelectorAll(".dz.hit").forEach((el) => el.classList.remove("hit"));
  }, 1700);

  // mic level spike and decay
  clearInterval(meterTimer);
  let level = 100;
  meter.style.width = level + "%";
  meterTimer = setInterval(() => {
    level *= 0.72;
    meter.style.width = Math.max(4, level) + "%";
    if (level < 5) clearInterval(meterTimer);
  }, 70);

  knock();
}

desk.addEventListener("pointerdown", (e) => {
  if (e.target.closest(".sound-toggle")) return;
  const rect = desk.getBoundingClientRect();
  tapAt(e.clientX - rect.left, e.clientY - rect.top);
});

/* one self-demonstrating tap so the page explains itself */
if (!reduced) {
  setTimeout(() => {
    if (desk.classList.contains("touched")) return;
    const rect = desk.getBoundingClientRect();
    tapAt(rect.width * 0.22, rect.height * 0.7);
    desk.classList.remove("touched");
  }, 1400);
}

/* ------------------------------------------------------------------ field
   The page background is an acoustic surface: a lattice of sample points.
   The cursor presses into it like a fingertip; any click drops a wave that
   propagates through the lattice the way a knock travels through a desk.  */
(function field() {
  const canvas = document.getElementById("field");
  const ctx = canvas.getContext("2d");
  const SPACING = 34;
  const MOUSE_R = 170;
  const WAVE_SPEED = 0.42;   // px per ms
  const WAVE_LIFE = 2600;    // ms

  let dots = [];
  let waves = [];
  let mx = -1e4, my = -1e4;
  let w = 0, h = 0, dpr = 1;
  let running = false;

  function resize() {
    dpr = Math.min(devicePixelRatio || 1, 2);
    w = innerWidth; h = innerHeight;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    dots = [];
    const offX = (w % SPACING) / 2, offY = (h % SPACING) / 2;
    for (let y = offY; y <= h; y += SPACING)
      for (let x = offX; x <= w; x += SPACING)
        dots.push({ x, y });
  }

  function drawStatic() {
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = "rgba(236, 231, 220, 0.075)";
    for (const d of dots) ctx.fillRect(d.x - 1, d.y - 1, 2, 2);
  }

  function frame(now) {
    ctx.clearRect(0, 0, w, h);
    waves = waves.filter((wv) => now - wv.t0 < WAVE_LIFE);

    // warm lamp glow following the cursor, under the lattice
    if (mx > -9000) {
      const lamp = ctx.createRadialGradient(mx, my, 0, mx, my, 300);
      lamp.addColorStop(0, "rgba(226, 189, 119, 0.085)");
      lamp.addColorStop(1, "rgba(226, 189, 119, 0)");
      ctx.fillStyle = lamp;
      ctx.fillRect(mx - 300, my - 300, 600, 600);
    }

    for (const d of dots) {
      let ox = 0, oy = 0, glow = 0;

      const mdx = d.x - mx, mdy = d.y - my;
      const md = Math.hypot(mdx, mdy);
      if (md < MOUSE_R && md > 0.001) {
        const push = (1 - md / MOUSE_R) ** 2 * 24;
        ox += (mdx / md) * push;
        oy += (mdy / md) * push;
        glow += (1 - md / MOUSE_R) * 0.9;
      }

      for (const wv of waves) {
        const age = now - wv.t0;
        const wdx = d.x - wv.x, wdy = d.y - wv.y;
        const wd = Math.hypot(wdx, wdy);
        if (wd < 0.001) continue;
        const ring = age * WAVE_SPEED;
        const g = Math.exp(-((wd - ring) ** 2) / (2 * 42 ** 2));
        const amp = g * 22 * Math.exp(-age / 900);
        ox += (wdx / wd) * amp;
        oy += (wdy / wd) * amp;
        glow += g * Math.exp(-age / 900) * 1.1;
      }

      glow = Math.min(glow, 1);
      const s = 1.6 + glow * 1.6;
      if (glow > 0.02) {
        // warm grey at rest, champagne gold as the wave passes through
        const r = Math.round(172 + glow * 60);
        const gc = Math.round(152 + glow * 37);
        const b = Math.round(122 + glow * 5);
        ctx.fillStyle = `rgba(${r}, ${gc}, ${b}, ${0.06 + glow * 0.55})`;
      } else {
        ctx.fillStyle = "rgba(236, 231, 220, 0.075)";
      }
      ctx.fillRect(d.x + ox - s / 2, d.y + oy - s / 2, s, s);
    }

    if (running) requestAnimationFrame(frame);
  }

  function start() {
    if (!running) { running = true; requestAnimationFrame(frame); }
  }
  function stop() { running = false; }

  window.dropWave = (x, y) => {
    waves.push({ x, y, t0: performance.now() });
    if (waves.length > 8) waves.shift();
  };

  resize();
  addEventListener("resize", resize);

  if (reduced) { drawStatic(); return; }

  addEventListener("pointermove", (e) => { mx = e.clientX; my = e.clientY; }, { passive: true });
  addEventListener("pointerleave", () => { mx = my = -1e4; });
  addEventListener("pointerdown", (e) => dropWave(e.clientX, e.clientY), { passive: true });
  document.addEventListener("visibilitychange", () =>
    document.hidden ? stop() : start());

  // a first wave so the surface introduces itself, then a quiet ambient
  // knock every few seconds so the page never sits completely still
  setTimeout(() => dropWave(innerWidth * 0.5, innerHeight * 0.35), 600);
  setInterval(() => {
    if (!document.hidden) {
      dropWave(innerWidth * (0.1 + Math.random() * 0.8),
               innerHeight * (0.1 + Math.random() * 0.8));
    }
  }, 7000);
  start();
})();

/* ------------------------------------------------------------------ reveals */
const io = new IntersectionObserver((entries) => {
  for (const en of entries) {
    if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); }
  }
}, { threshold: 0.15 });
document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

/* ------------------------------------------------------------------ copy */
const copyBtn = document.getElementById("copyBtn");
copyBtn.addEventListener("click", async () => {
  const cmd = [
    "brew tap adilmustafayilmaz/tap",
    "brew trust adilmustafayilmaz/tap",
    "brew install --cask tap-spaces",
  ].join("\n");
  try {
    await navigator.clipboard.writeText(cmd);
    copyBtn.textContent = STRINGS[lang]["in.copied"];
    copyBtn.classList.add("done");
    setTimeout(() => {
      copyBtn.textContent = STRINGS[lang]["in.copy"];
      copyBtn.classList.remove("done");
    }, 1600);
  } catch { /* clipboard unavailable — the commands are selectable */ }
});

/* ------------------------------------------------------------------ version */
fetch("https://api.github.com/repos/adilmustafayilmaz/Tap-Spaces/releases/latest")
  .then((r) => (r.ok ? r.json() : null))
  .then((rel) => {
    const v = rel?.tag_name?.replace(/^v/, "");
    if (!v) return;
    document.getElementById("verBadge").textContent = v;
    document.getElementById("verFoot").textContent = v;
  })
  .catch(() => {});
