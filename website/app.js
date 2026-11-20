(() => {
  'use strict';

  const TRANSLATIONS = {
    en: {
      pageTitle: 'NyxWatch — Walk away. Stay protected.',
      'nav.overview': 'Overview',
      'nav.sequence': 'Sequence',
      'nav.modes': 'Modes',
      'nav.bento': 'Features',
      'nav.platforms': 'Platforms',
      'nav.cta': 'Download for Mac',
      'nav.install': 'Install',

      'hero.title': 'Walk away.<br /><span>Stay protected.</span>',
      'hero.subtitle':
        "NyxWatch for macOS detects physical activity, sends a text alert and locks your Mac. No recording.",
      'hero.ctaSecondary': 'See how it works',
      'demo.open': 'Watch demo',
      'demo.title': 'NyxWatch corporate demo',
      'demo.close': 'Close video',
      'demo.download': 'Download the video',

      'seq.c1Eyebrow': '01 · ARMING',
      'seq.c1Title': 'Armed in a keystroke.',
      'seq.c1Desc':
        'Press Cmd + Esc or simply walk away. Optional Bluetooth RSSI proximity arms the sentinel automatically.',
      'seq.c2Eyebrow': '02 · MONITORING',
      'seq.c2Title': 'Protection active.',
      'seq.c2Desc':
        "Detects activity, USB connections, lid closure and power changes without reading typed keys or recording your screen.",
      'seq.c3Eyebrow': "03 · ALERT & LOCK",
      'seq.c3Title': "Activity detected. Mac locked.",
      'seq.c3Desc':
        "Both response modes lock macOS immediately. Flag adds a visible flash and a spoken warning.",
      'seq.c4Eyebrow': "04 · TEXT ALERTS",
      'seq.c4Title': 'Direct to your devices.',
      'seq.c4Desc':
        "A timestamp and the event type go to the notification channels you configure. No photos, video, audio or screen contents.",
      'seq.armed': 'Protection active',
      'seq.monitoring': "Activity, USB, lid and power monitored",
      'seq.locked': 'Device locked',
      'seq.detected': 'Intrusion detected',

      'modes.eyebrow': 'Response modes',
      'modes.title': 'Two modes. Total control.',
      'modes.subtitle':
        "Choose a quiet lock or add an audible warning. Both modes protect your session without recording.",
      'modes.stealthBtn': "Alert + Lock",
      'modes.flagBtn': 'Flag Mode',
      'modes.pillAV': "No recording",

      'modes.stealthTag': "ALERT + LOCK",
      'modes.stealthPreviewStatus': "Activity detected. Session locked. Text alert sent to your configured channels.",
      'modes.stealthPill2': "Immediate Lock",
      'modes.stealthPill3': "Text Alerts",
      'modes.stealthTitle': "Protect your session. Respect privacy.",
      'modes.stealthDesc':
        "NyxWatch detects physical activity, locks macOS immediately and sends an event notification. It never reads typed keys, captures the screen or records the camera or microphone.",
      'modes.stealthItem1': "Activity detection from the system idle timer; no typed content",
      'modes.stealthItem2': "Immediate macOS lock without waiting for network delivery",
      'modes.stealthItem3': "Text alerts via your configured WhatsApp, Telegram, iMessage or LAN receiver",
      'modes.stealthItem4': "Text-only retry queue for the optional local WhatsApp bridge",

      'modes.flagTag': 'FULL DETERRENCE',
      'modes.flagPreviewStatus': "Immediate lock, visible flash and spoken warning.",
      'modes.flagPill2': 'Flash + Voice',
      'modes.flagPill3': "macOS Lock",
      'modes.flagTitle': 'Immediate physical deterrence and instant lockdown.',
      'modes.flagDesc':
        "Flag locks macOS immediately, adds a visible flash and speaks a warning. Notifications contain only the event type and timestamp.",
      'modes.flagItem1': "No camera, microphone, screen capture or keystroke recording",
      'modes.flagItem2': 'High-visibility screen flash + spoken voice deterrence',
      'modes.flagItem3': "Your existing wallpaper stays unchanged",
      'modes.flagItem4': "Text alerts; optional local WhatsApp bridge retry",

      'bento.eyebrow': 'Features',
      'bento.title': 'Protection, built in.',
      'bento.subtitle': "Detection runs on your Mac. Delivery uses the notification services you configure.",
      'bento.c1Tag': "Privacy",
      'bento.c1Title': "Protection without recording.",
      'bento.c1Desc':
        "No keylogging, screenshots, camera, microphone or face recognition. The Mac build requests none of those recording permissions.",
      'bento.c2Tag': 'Instant Arming',
      'bento.c2Title': 'Arm in a keystroke.',
      'bento.c2Desc':
        'Arm from any app with a single global shortcut, or enable optional Bluetooth Low Energy RSSI proximity auto-arming when you walk away.',
      'bento.c3Tag': 'Multi-Vector',
      'bento.c3Title': 'Know when someone touches your device.',
      'bento.c3Desc':
        "Detects activity from system idle time, USB device connections, volume mounts, lid closure and charger disconnection. It does not inspect USB contents or identify malicious devices.",
      'bento.c4Tag': "Text Notifications",
      'bento.c4Title': 'Alerts on your devices.',
      'bento.c4Desc':
        "Event type and timestamp are sent to your chosen services. WhatsApp, Telegram and iMessage use their own infrastructure; a LAN receiver is also supported.",
      'bento.c5Tag': 'Resilient Privacy',
      'bento.c5Title': 'Automatic retry when you reconnect.',
      'bento.c5Desc':
        "The optional local WhatsApp bridge retries queued text alerts after a delivery failure. Locking happens immediately even when the network is unavailable.",

      'install.mac.open.title': "Open NyxWatch",
      'install.mac.open.body': "Open Applications in Finder and double-click NyxWatch. Look for its N logo in the menu bar and on the floating button. Protection starts off.",
      'install.win.python.link': "Get Python for Windows",
      'install.win.python.title': "Install Python",
      'install.win.python.body': "Open the official Python download page and install Python 3. When the installation is finished, close the installer.",
      'install.win.folder.title': "Open PowerShell in the project folder",
      'install.win.folder.body': "Open the extracted NyxWatch folder in File Explorer. Click the address bar, type powershell and press Enter. Then paste the line below and press Enter.",
      'install.win.deps.title': "Prepare NyxWatch",
      'install.win.deps.body': "Copy and run each line in order. Wait for each one to finish before you paste the next. The first creates a local Python environment and the second installs the packages.",
      'install.win.open.title': "Start in Flag mode with protection off",
      'install.win.open.body': "Run the line below. Look for Armed: False in PowerShell. To close NyxWatch, press Ctrl + C in the same window.",
      'install.linux.python.title': "Make sure Python is ready",
      'install.linux.python.body': "Open Terminal and run the first line. If Python or venv is missing on Ubuntu or Debian, run the second line and wait for it to finish.",
      'install.linux.folder.title': "Open Terminal in the project folder",
      'install.linux.folder.body': "Open the extracted NyxWatch folder in your file manager. Right-click an empty spot and choose Open in Terminal. Then run the line below.",
      'install.linux.deps.title': "Prepare NyxWatch",
      'install.linux.deps.body': "Copy and run each line in order. Wait for each one to finish before you paste the next.",
      'install.linux.open.title': "Start in Flag mode with protection off",
      'install.linux.open.body': "Run the line below. Look for Armed: False. To close NyxWatch, press Ctrl + C. Input detection can be limited on Wayland.",
      'platforms.title': "Install NyxWatch",
      'platforms.subtitle': "The Mac installer below is the privacy-focused release. Other platform sources are separate prototypes.",
      'install.files.title': "Install on your Mac",
      'install.files.body': "Download the Mac installer, open the DMG and drag NyxWatch to Applications. For macOS 13 or later, on Apple Silicon and Intel. Source code is available on GitHub.",
      'install.files.download': "Download for Mac (.dmg)",
      'install.files.link': "View source on GitHub",
      'install.android.body': "The repository has Android source files. An APK or a complete Android Studio project is needed before you can install it.",
      'install.android.badge': "Source files only",
      'install.ios.body': "The repository has a Swift file for iPhone. An Xcode project or an app distributed through TestFlight or the App Store is needed to install it.",
      'install.ios.badge': "Source files only",
      'install.mac.badge': "Drag and drop",
      'install.win.badge': "Run with Python",
      'install.linux.badge': "Run with Python",
      'platforms.copy': 'Copy',
      'platforms.copied': 'Copied',

      'footer.tagline': 'On-device intrusion detection.',
      'footer.top': 'Back to top ↑',
      'install.mac.download.title': "Download and open the DMG",
      'install.mac.download.body': "Click Download for Mac, then open NyxWatch.dmg from Downloads. A window with NyxWatch and the Applications folder appears.",
      'install.mac.drag.title': "Drag NyxWatch to Applications",
      'install.mac.drag.body': "Drag the NyxWatch icon onto Applications in that window. Wait for the copy to finish. If you are updating, quit NyxWatch first and choose Replace when macOS asks.",
      'install.mac.security.title': "Apple notarization",
      'install.mac.security.body': "This installer is signed with Developer ID and notarized by Apple.",
      'install.mac.security.link': "Apple’s first-launch guide",
    },

    fr: {
      pageTitle: 'NyxWatch — Éloignez-vous. Restez protégé.',
      'nav.overview': 'Aperçu',
      'nav.sequence': 'Séquence',
      'nav.modes': 'Modes',
      'nav.bento': 'Fonctionnalités',
      'nav.platforms': 'Plateformes',
      'nav.cta': 'Télécharger pour Mac',
      'nav.install': 'Installer',

      'hero.title': 'Éloignez-vous.<br /><span>Restez protégé.</span>',
      'hero.subtitle':
        "NyxWatch pour macOS détecte une activité physique, envoie une alerte texte et verrouille votre Mac. Sans enregistrement.",
      'hero.ctaSecondary': 'Voir comment ça marche',
      'demo.open': 'Voir la démo',
      'demo.title': 'Vidéo de démonstration NyxWatch en anglais',
      'demo.close': 'Fermer la vidéo',
      'demo.download': 'Télécharger la vidéo',

      'seq.c1Eyebrow': '01 · ARMEMENT',
      'seq.c1Title': 'Armé en un raccourci.',
      'seq.c1Desc':
        'Appuyez sur Cmd + Esc ou éloignez-vous simplement. La proximité Bluetooth RSSI optionnelle arme la sentinelle automatiquement.',
      'seq.c2Eyebrow': '02 · SURVEILLANCE',
      'seq.c2Title': 'La protection s’active.',
      'seq.c2Desc':
        "Détecte l’activité, les connexions USB, la fermeture du capot et les changements d’alimentation sans lire les touches saisies ni enregistrer l’écran.",
      'seq.c3Eyebrow': "03 · ALERTE ET VERROUILLAGE",
      'seq.c3Title': "Activité détectée. Mac verrouillé.",
      'seq.c3Desc':
        "Les deux modes verrouillent macOS immédiatement. Flag ajoute un flash visible et un avertissement vocal.",
      'seq.c4Eyebrow': "04 · ALERTES TEXTE",
      'seq.c4Title': 'Directement sur vos appareils.',
      'seq.c4Desc':
        "L’heure et le type d’événement sont envoyés aux canaux configurés. Aucune photo, vidéo, piste audio ni contenu d’écran.",
      'seq.armed': 'Protection active',
      'seq.monitoring': "Activité, USB, capot et alimentation surveillés",
      'seq.locked': 'Appareil verrouillé',
      'seq.detected': 'Intrusion détectée',

      'modes.eyebrow': 'Modes de réponse',
      'modes.title': 'Deux modes. Contrôle total.',
      'modes.subtitle':
        "Choisissez le verrouillage discret ou ajoutez un avertissement sonore. Les deux modes protègent votre session sans enregistrement.",
      'modes.stealthBtn': "Alerte + Verrouillage",
      'modes.flagBtn': 'Mode Flag',
      'modes.pillAV': "Sans enregistrement",

      'modes.stealthTag': "ALERTE ET VERROUILLAGE",
      'modes.stealthPreviewStatus': "Activité détectée. Session verrouillée. Alerte texte envoyée aux canaux configurés.",
      'modes.stealthPill2': "Verrouillage immédiat",
      'modes.stealthPill3': "Alertes texte",
      'modes.stealthTitle': "Protégez votre session. Respectez la vie privée.",
      'modes.stealthDesc':
        "NyxWatch détecte une activité physique, verrouille macOS immédiatement et envoie une notification. Il ne lit jamais les touches saisies, ne capture pas l’écran et n’enregistre ni caméra ni microphone.",
      'modes.stealthItem1': "Détection par le compteur d’inactivité système, sans contenu saisi",
      'modes.stealthItem2': "Verrouillage immédiat sans attendre le réseau",
      'modes.stealthItem3': "Alertes texte via WhatsApp, Telegram, iMessage ou votre récepteur local configuré",
      'modes.stealthItem4': "File de réessai texte pour le pont WhatsApp local optionnel",

      'modes.flagTag': 'DISSUASION TOTALE',
      'modes.flagPreviewStatus': "Verrouillage immédiat, flash visible et avertissement vocal.",
      'modes.flagPill2': 'Flash + Voix',
      'modes.flagPill3': "Verrouillage macOS",
      'modes.flagTitle': 'Dissuasion physique immédiate et verrouillage instantané.',
      'modes.flagDesc':
        "Flag verrouille macOS immédiatement, ajoute un flash visible et prononce un avertissement. Les notifications contiennent uniquement le type d’événement et l’heure.",
      'modes.flagItem1': "Aucun enregistrement caméra, micro, écran ou frappes",
      'modes.flagItem2': 'Flash visuel haute visibilité + dissuasion vocale parlée',
      'modes.flagItem3': "Votre fond d’écran reste inchangé",
      'modes.flagItem4': "Alertes texte et réessai via le pont WhatsApp local optionnel",

      'bento.eyebrow': 'Fonctionnalités',
      'bento.title': 'La protection intégrée.',
      'bento.subtitle': "La détection fonctionne sur votre Mac. L’envoi utilise les services de notification que vous configurez.",
      'bento.c1Tag': "Vie privée",
      'bento.c1Title': "La protection sans enregistrement.",
      'bento.c1Desc':
        "Aucune collecte des frappes, capture d’écran, caméra, microphone ni reconnaissance faciale. La version Mac ne demande aucune de ces permissions d’enregistrement.",
      'bento.c2Tag': 'Armement instantané',
      'bento.c2Title': 'Activez la protection en un raccourci.',
      'bento.c2Desc':
        'Armez depuis n’importe quelle app d’un simple raccourci, ou activez l’armement automatique par proximité Bluetooth Low Energy (RSSI).',
      'bento.c3Tag': 'Multi-vecteurs',
      'bento.c3Title': 'Détectez les manipulations de votre appareil.',
      'bento.c3Desc':
        "Détecte l’activité par le temps d’inactivité système, les connexions USB, le montage des volumes, la fermeture du capot et le débranchement du chargeur. N’inspecte pas le contenu USB et n’identifie pas les périphériques malveillants.",
      'bento.c4Tag': "Notifications texte",
      'bento.c4Title': 'Des alertes sur vos appareils.',
      'bento.c4Desc':
        "Le type d’événement et l’heure sont envoyés aux services choisis. WhatsApp, Telegram et iMessage utilisent leur propre infrastructure ; un récepteur LAN est également possible.",
      'bento.c5Tag': 'Confidentialité résiliente',
      'bento.c5Title': 'Nouvel envoi dès la reconnexion.',
      'bento.c5Desc':
        "Le pont WhatsApp local optionnel réessaie les alertes texte après un échec d’envoi. Le verrouillage reste immédiat même sans réseau.",

      'install.mac.open.title': "Ouvre NyxWatch",
      'install.mac.open.body': "Ouvre Applications dans le Finder et double-clique sur NyxWatch. Son logo N apparaît dans la barre des menus et sur le bouton flottant. La protection démarre désactivée.",
      'install.win.python.link': "Télécharger Python pour Windows",
      'install.win.python.title': "Installe Python",
      'install.win.python.body': "Ouvre la page officielle de téléchargement et installe Python 3. Ferme l’installateur quand c’est terminé.",
      'install.win.folder.title': "Ouvre PowerShell dans le dossier du projet",
      'install.win.folder.body': "Ouvre le dossier NyxWatch décompressé dans l’Explorateur de fichiers. Clique sur la barre d’adresse, écris powershell et appuie sur Entrée. Colle ensuite la ligne ci-dessous et appuie sur Entrée.",
      'install.win.deps.title': "Prépare NyxWatch",
      'install.win.deps.body': "Copie et lance chaque ligne dans l’ordre. Attends que la première se termine avant de coller la suivante. La première prépare un environnement Python dans le dossier. La seconde installe les bibliothèques.",
      'install.win.open.title': "Ouvre le mode Flag avec la protection désactivée",
      'install.win.open.body': "Lance la ligne ci-dessous. Vérifie que PowerShell affiche Armed: False. Pour fermer NyxWatch, fais Ctrl + C dans la même fenêtre.",
      'install.linux.python.title': "Vérifie que Python est prêt",
      'install.linux.python.body': "Ouvre Terminal et lance la première ligne. Si Python ou venv manque sur Ubuntu ou Debian, lance la seconde et attends la fin.",
      'install.linux.folder.title': "Ouvre Terminal dans le dossier du projet",
      'install.linux.folder.body': "Ouvre le dossier NyxWatch décompressé dans ton gestionnaire de fichiers. Fais un clic droit dans un espace vide et choisis Ouvrir dans un terminal. Lance ensuite la ligne ci-dessous.",
      'install.linux.deps.title': "Prépare NyxWatch",
      'install.linux.deps.body': "Copie et lance chaque ligne dans l’ordre. Attends que la première se termine avant de coller la suivante.",
      'install.linux.open.title': "Ouvre le mode Flag avec la protection désactivée",
      'install.linux.open.body': "Lance la ligne ci-dessous. Vérifie que le message Armed: False apparaît. Pour fermer NyxWatch, fais Ctrl + C. La détection peut être limitée sous Wayland.",
      'platforms.title': "Installer NyxWatch",
      'platforms.subtitle': "L’installateur Mac ci-dessous est la version sans enregistrement. Les sources des autres plateformes restent des prototypes distincts.",
      'install.files.title': "Installe NyxWatch sur ton Mac",
      'install.files.body': "Télécharge l’installateur Mac, ouvre le DMG et glisse NyxWatch dans Applications. Pour macOS 13 ou plus récent, sur Apple Silicon et Intel. Le code source reste disponible sur GitHub.",
      'install.files.download': "Télécharger pour Mac (.dmg)",
      'install.files.link': "Voir le code sur GitHub",
      'install.android.body': "Le dépôt contient des fichiers sources Android. Il faut un APK ou un projet Android Studio complet avant de pouvoir l’installer.",
      'install.android.badge': "Fichiers sources",
      'install.ios.body': "Le dépôt contient un fichier Swift pour iPhone. Il faut un projet Xcode ou une application distribuée via TestFlight ou l’App Store pour l’installer.",
      'install.ios.badge': "Fichiers sources",
      'install.mac.badge': "Glisser-déposer",
      'install.win.badge': "Lancer avec Python",
      'install.linux.badge': "Lancer avec Python",
      'platforms.copy': 'Copier',
      'platforms.copied': 'Copié',

      'footer.tagline': 'Détection des intrusions sur l’appareil.',
      'footer.top': 'Retour en haut ↑',
      'install.mac.download.title': "Télécharge et ouvre le DMG",
      'install.mac.download.body': "Clique sur Télécharger pour Mac, puis ouvre NyxWatch.dmg dans Téléchargements. Une fenêtre avec NyxWatch et le dossier Applications apparaît.",
      'install.mac.drag.title': "Glisse NyxWatch dans Applications",
      'install.mac.drag.body': "Glisse l’icône NyxWatch sur Applications dans cette fenêtre. Attends la fin de la copie. Pour une mise à jour, quitte d’abord NyxWatch et choisis Remplacer lorsque macOS le demande.",
      'install.mac.security.title': "Notarisation Apple",
      'install.mac.security.body': "Cet installateur est signé avec un certificat Developer ID et notarié par Apple.",
      'install.mac.security.link': "Le guide Apple pour le premier lancement",
    }
  };

  const state = {
    lang: 'en',
    mode: 'stealth'
  };

  // DOM Elements
  const langToggleBtn = document.getElementById('lang-toggle');
  const modeStage = document.getElementById('mode-stage');
  const modeTabs = document.querySelectorAll('.mode-tab');
  const miniBusted = document.getElementById('mini-busted');

  function t(key) {
    const dict = TRANSLATIONS[state.lang] || TRANSLATIONS.en;
    return dict[key] || key;
  }

  function applyTranslations() {
    document.documentElement.lang = state.lang;
    document.title = t('pageTitle');

    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      const val = t(key);
      if (key === 'hero.title') {
        el.innerHTML = val;
      } else {
        el.textContent = val;
      }
    });

    // Update language toggle visual state
    langToggleBtn.querySelectorAll('.lang-toggle__option').forEach((opt) => {
      opt.classList.toggle('is-active', opt.getAttribute('data-lang') === state.lang);
    });

    // Re-sync dynamic widgets with current language
    renderModeState();
  }

  function renderModeState() {
    const isFlag = state.mode === 'flag';
    const prefix = isFlag ? 'flag' : 'stealth';

    modeStage.setAttribute('data-active-mode', state.mode);
    modeStage.setAttribute('aria-labelledby', `mode-${state.mode}`);
    miniBusted.hidden = !isFlag;

    document.getElementById('mode-preview-tag').textContent = t(`modes.${prefix}Tag`);
    document.getElementById('mode-preview-status').textContent = t(`modes.${prefix}PreviewStatus`);
    document.getElementById('mode-pill-2').textContent = t(`modes.${prefix}Pill2`);
    document.getElementById('mode-pill-3').textContent = t(`modes.${prefix}Pill3`);
    document.getElementById('mode-details-title').textContent = t(`modes.${prefix}Title`);
    document.getElementById('mode-details-desc').textContent = t(`modes.${prefix}Desc`);
    document.getElementById('mode-item-1').textContent = t(`modes.${prefix}Item1`);
    document.getElementById('mode-item-2').textContent = t(`modes.${prefix}Item2`);
    document.getElementById('mode-item-3').textContent = t(`modes.${prefix}Item3`);
    document.getElementById('mode-item-4').textContent = t(`modes.${prefix}Item4`);

    modeTabs.forEach((tab) => {
      const active = tab.getAttribute('data-mode') === state.mode;
      tab.classList.toggle('is-active', active);
      tab.setAttribute('aria-selected', String(active));
      tab.tabIndex = active ? 0 : -1;
    });
  }

  async function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return;
    }
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }

  // Event Listeners
  langToggleBtn.addEventListener('click', () => {
    state.lang = state.lang === 'en' ? 'fr' : 'en';
    applyTranslations();
  });

  modeTabs.forEach((tab, index) => {
    tab.addEventListener('keydown', (event) => {
      const destinations = { ArrowLeft: index - 1, ArrowRight: index + 1, Home: 0, End: modeTabs.length - 1 };
      if (!Object.hasOwn(destinations, event.key)) return;
      event.preventDefault();
      const next = modeTabs[(destinations[event.key] + modeTabs.length) % modeTabs.length];
      next.click();
      next.focus();
    });
    tab.addEventListener('click', () => {
      state.mode = tab.getAttribute('data-mode');
      renderModeState();
    });
  });

  document.querySelectorAll('.copy-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const text = btn.getAttribute('data-copy');
      try {
        await copyText(text);
        btn.classList.add('is-copied');
        btn.textContent = t('platforms.copied');
        setTimeout(() => {
          btn.classList.remove('is-copied');
          btn.textContent = t('platforms.copy');
        }, 1600);
      } catch (_) {
        // Ignore clipboard denial silently
      }
    });
  });

  function initScrollSequence() {
    const section = document.getElementById('overview');
    const stage = section.querySelector('.sequence-sticky');
    const device = stage.querySelector('.sequence-device');
    const keyboard = device.querySelector('.sequence-keyboard');
    const keyRows = [
      'esc F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 ⏻',
      '~ 1 2 3 4 5 6 7 8 9 0 − + ⌫',
      '⇥ Q W E R T Y U I O P [ ] |',
      '⇪ A S D F G H J K L ; : ↵',
      '⇧ Z X C V B N M , . / ⇧',
      'fn ⌃ ⌥ ⌘ space ⌘ ⌥ ← ↑ ↓ →'
    ];
    for (const labels of keyRows) {
      const row = document.createElement('div');
      for (const label of labels.split(' ')) {
        const key = document.createElement('span');
        key.textContent = label === 'space' ? '' : label;
        key.classList.toggle('sequence-key--space', label === 'space');
        row.append(key);
      }
      keyboard.append(row);
    }

    const rail = stage.querySelector('.sequence-rail');
    const buttons = [...rail.querySelectorAll('[data-chapter-target]')];
    const captions = [...stage.querySelectorAll('.sequence-caption')];
    const intro = stage.querySelector('.hero__layout');
    const navbar = document.getElementById('navbar');
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const fullScreenAt = 0.43;
    const intrusionAt = 0.61;
    const pullBackAt = 0.77;
    const chapters = [
      { start: 0, target: 0.15 },
      { start: 0.24, target: 0.51 },
      { start: intrusionAt, target: 0.73 },
      { start: 0.86, target: 0.95 }
    ];
    const stackedLayout = window.matchMedia('(max-width: 760px), (max-width: 1000px) and (min-height: 621px)');
    const clamp = (value) => Math.max(0, Math.min(value, 1));
    const mix = (from, to, amount) => from + (to - from) * amount;
    const ease = (from, to, progress) => {
      const amount = clamp((progress - from) / (to - from));
      return amount ** 3 * (amount * (6 * amount - 15) + 10);
    };

    let frame = 0;
    let lastFrame;
    let startY;
    let scrollDistance;
    let stageWidth;
    let stageHeight;
    let progress;
    let activeChapter = -1;
    let closeupScale = 1;

    function measure() {
      startY = window.scrollY + section.getBoundingClientRect().top - navbar.offsetHeight;
      scrollDistance = Math.max(1, section.offsetHeight - stage.offsetHeight);
      stageWidth = stage.clientWidth;
      stageHeight = stage.clientHeight;
      const renderScale = Number(getComputedStyle(device).getPropertyValue('--render-scale'));
      const widthRatio = stageWidth * renderScale / device.offsetWidth;
      const heightRatio = stageHeight * renderScale / device.offsetHeight;
      // Overscan keeps the bezel outside the viewport in portrait and landscape.
      closeupScale = Math.max(widthRatio, heightRatio) * 1.13;
      schedule();
    }

    function draw(p) {
      const opening = 1 - (1 - clamp(p / 0.22)) ** 3;
      const approach = ease(0.12, fullScreenAt, p);
      const retreat = ease(pullBackAt, 0.92, p);
      const armed = p >= fullScreenAt;
      const titleFade = ease(0.015, 0.105, p);
      const center = ease(0.025, 0.29, p);
      const stacked = stackedLayout.matches;
      const tilt = mix(50, 82, opening) - retreat * 9;
      const lid = mix(0, 98, opening);
      const pushIn = 0.83 * (closeupScale / 0.83) ** approach;
      const cameraScale = mix(pushIn, stacked ? 0.69 : 0.84, retreat);
      const aim = mix(-0.25, 0.50, opening) - retreat * 0.07;
      const zoom = motion.matches ? 0.83 : cameraScale;

      stage.style.setProperty('--lid-angle', `${lid}deg`);
      stage.style.setProperty('--deck-angle', `${tilt}deg`);
      stage.style.setProperty('--yaw', `${mix(-17, 0, opening) + retreat * 10}deg`);
      stage.style.setProperty('--aim', aim);
      stage.style.setProperty('--zoom', zoom);
      stage.style.setProperty('--camera-x', `${stageWidth * mix(stacked ? 0.52 : 0.73, 0.50, center)}px`);
      stage.style.setProperty('--camera-y', `${stageHeight * (mix(stacked ? 0.57 : 0.49, 0.50, center) - retreat * 0.11)}px`);
      stage.style.setProperty('--closeup', motion.matches ? 0 : approach * (1 - retreat));
      stage.style.setProperty('--intro', 1 - titleFade);
      stage.style.setProperty('--captions', motion.matches ? 1 : 1 - ease(0.20, 0.27, p) + ease(intrusionAt, 0.70, p));
      intro.inert = titleFade > 0.99;
      stage.style.setProperty('--screen-on', ease(0.12, 0.24, p));
      stage.classList.toggle('is-armed', armed);
      stage.classList.toggle('is-locking', p >= intrusionAt);
      stage.style.setProperty('--scan', ease(0.24, 0.39, p));
      stage.style.setProperty('--scan-opacity', ease(0.24, 0.28, p) * (1 - ease(0.36, 0.42, p)));
      stage.style.setProperty('--channels', ease(chapters[3].start, 0.94, p));
    }

    function render(now) {
      frame = 0;
      const target = clamp((window.scrollY - startY) / scrollDistance);
      const elapsed = lastFrame === undefined ? 1000 / 60 : Math.min(now - lastFrame, 50);
      const settle = progress === undefined || motion.matches || Math.abs(target - progress) < 0.0004;
      progress = settle ? target : mix(progress, target, 1 - Math.exp(-elapsed / 82));
      lastFrame = settle ? undefined : now;

      stage.classList.toggle('is-playing', progress > 0.11);
      navbar.classList.toggle('is-over-screen', !motion.matches && progress >= fullScreenAt && progress < pullBackAt);
      const chapter = chapters.findLastIndex(({ start }) => progress >= start);
      if (chapter !== activeChapter) {
        activeChapter = chapter;
        buttons.forEach((button, index) => {
          const active = index === chapter;
          button.classList.toggle('is-active', active);
          if (active) button.setAttribute('aria-current', 'step');
          else button.removeAttribute('aria-current');
          captions[index].classList.toggle('is-active', active);
        });
      }

      rail.style.setProperty('--progress', `${progress * 100}%`);
      const pose = motion.matches ? (progress > 0.11 ? chapters[chapter].target : 0) : progress;
      draw(pose);
      if (progress !== target) schedule();
    }

    function schedule() {
      if (!frame) frame = requestAnimationFrame(render);
    }

    buttons.forEach((button, index) => {
      button.addEventListener('click', () => {
        window.scrollTo({
          top: startY + chapters[index].target * scrollDistance,
          behavior: motion.matches ? 'instant' : 'smooth'
        });
      });
    });

    window.addEventListener('scroll', schedule, { passive: true });
    const observer = new ResizeObserver(measure);
    observer.observe(section);
    observer.observe(stage);
    observer.observe(device);
    motion.addEventListener('change', schedule);
    measure();
  }

  initScrollSequence();

  // Initial render
  applyTranslations();
})();
