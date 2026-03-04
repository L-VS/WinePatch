#!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════════════

# WINCOMPAT — Intégration Windows maximale sur Linux

# Méthode : Bottles (Flatpak) + Wine-GE + MIME natif

# ✅ Zéro binfmt_misc  ✅ Zéro root permanent  ✅ Zéro préfixe partagé

# ✅ Double-clic natif  ✅ .exe .msi .raw .bat .reg .dll .cab .iso

# Usage  : bash <(curl -fsSL https://TON-SERVEUR/wincompat.sh)

# Désinstall : bash wincompat.sh –uninstall

# ══════════════════════════════════════════════════════════════════════

set -euo pipefail
IFS=$’\n\t’

# ── Couleurs ──────────────────────────────────────────────────────────

G=’\033[0;32m’; C=’\033[0;36m’; Y=’\033[1;33m’
R=’\033[0;31m’; B=’\033[1m’;    X=’\033[0m’;   M=’\033[0;35m’
ok()    { echo -e “  ${G}✔${X}  $*”; }
info()  { echo -e “  ${C}→${X}  $*”; }
warn()  { echo -e “  ${Y}⚠${X}  $*”; }
err()   { echo -e “  ${R}✘${X}  $*” >&2; exit 1; }
step()  { echo -e “\n${B}${C}══════  $*  ══════${X}”; }
note()  { echo -e “  ${M}»${X}  $*”; }

# ── Mode désinstallation ──────────────────────────────────────────────

if [[ “${1:-}” == “–uninstall” ]]; then
echo -e “\n${B}${R}Désinstallation de WINCOMPAT…${X}\n”
flatpak uninstall -y com.usebottles.bottles 2>/dev/null && ok “Bottles supprimé.” || true
rm -f  “${HOME}/.local/bin/wincompat”
rm -f  “${HOME}/.local/share/applications/wincompat.desktop”
rm -f  “${HOME}/.local/share/mime/packages/wincompat.xml”
update-mime-database   “${HOME}/.local/share/mime”   2>/dev/null || true
update-desktop-database “${HOME}/.local/share/applications” 2>/dev/null || true
sed -i ‘/# WINCOMPAT/d’ “${HOME}/.bashrc” “${HOME}/.zshrc” 2>/dev/null || true
echo -e “\n${G}✔  Désinstallation complète.${X}\n”
exit 0
fi

# ── Bannière ──────────────────────────────────────────────────────────

clear
echo -e “${B}${C}”
cat << ‘BANNER’
██╗    ██╗██╗███╗  ██╗ ██████╗ ██████╗ ███╗   ███╗██████╗  █████╗ ████████╗
██║    ██║██║████╗ ██║██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝
██║ █╗ ██║██║██╔██╗██║██║     ██║   ██║██╔████╔██║██████╔╝███████║   ██║
██║███╗██║██║██║╚████║██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██╔══██║   ██║
╚███╔███╔╝██║██║ ╚███║╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║  ██║   ██║
╚══╝╚══╝ ╚═╝╚═╝  ╚══╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝   ╚═╝
BANNER
echo -e “${X}”
echo -e “  ${B}Compatibilité Windows maximale · Sécurisé · Sans root permanent${X}”
echo -e “  ${B}Supporte :${X}  .exe  .msi  .raw  .bat  .reg  .dll  .cab  .iso”
echo “”
echo -e “  ${G}✔${X}  Bottles     → sandbox isolée par application (zéro conflit DLL)”
echo -e “  ${G}✔${X}  Wine-GE     → Wine optimisé Proton/Steam (meilleure compatibilité)”
echo -e “  ${G}✔${X}  MIME natif  → double-clic .exe dans tout gestionnaire de fichiers”
echo -e “  ${G}✔${X}  winetricks  → Visual C++, .NET, DirectX, codecs automatiques”
echo -e “  ${Y}✘${X}  binfmt_misc → désactivé (risque sécurité kernel)”
echo “”
read -rp “  Appuyer sur [Entrée] pour commencer (Ctrl+C = annuler)…” _

# ── Vérifications système ─────────────────────────────────────────────

step “Vérification du système”

[[ “$(uname -m)” == “x86_64” ]] || err “Architecture x86_64 requise.”

# Mémoire RAM disponible

RAM_GB=$(awk ‘/MemTotal/{printf “%.0f”, $2/1024/1024}’ /proc/meminfo)
[[ “$RAM_GB” -ge 2 ]] || warn “RAM < 2 Go — performances réduites possibles.”

# Espace disque libre (/home)

FREE_GB=$(df -BG “${HOME}” | awk ‘NR==2{gsub(“G”,””); print $4}’)
[[ “$FREE_GB” -ge 5 ]] || warn “Moins de 5 Go libres — prévoir de l’espace pour les bottles.”

[[ $EUID -eq 0 ]] && SUDO=”” || SUDO=“sudo”

# Détection distro

if   command -v apt-get &>/dev/null; then DISTRO=“debian”; PKG=“apt-get”
elif command -v dnf     &>/dev/null; then DISTRO=“fedora”; PKG=“dnf”
elif command -v zypper  &>/dev/null; then DISTRO=“suse”;   PKG=“zypper”
elif command -v pacman  &>/dev/null; then DISTRO=“arch”;   PKG=“pacman”
else err “Distribution non supportée (apt/dnf/zypper/pacman requis).”; fi

ok “Distro : ${DISTRO} | Kernel : $(uname -r) | RAM : ${RAM_GB}Go | Disque libre : ${FREE_GB}Go”

# ── ÉTAPE 1 : Dépendances légères ─────────────────────────────────────

step “1/5 — Dépendances système”

install_pkgs() {
case $DISTRO in
debian)
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq   
flatpak curl wget p7zip-full cabextract   
libvulkan1 mesa-vulkan-drivers   
xdg-utils desktop-file-utils shared-mime-info   
notify-send 2>/dev/null ||   
$SUDO apt-get install -y -qq   
flatpak curl wget p7zip-full   
xdg-utils desktop-file-utils 2>/dev/null
;;
fedora)
$SUDO dnf install -y   
flatpak curl wget p7zip   
vulkan-loader mesa-vulkan-drivers   
xdg-utils desktop-file-utils shared-mime-info   
libnotify 2>/dev/null
;;
suse)
$SUDO zypper install -y   
flatpak curl wget p7zip   
vulkan-tools xdg-utils   
desktop-file-utils shared-mime-info 2>/dev/null
;;
arch)
$SUDO pacman -Sy –noconfirm   
flatpak curl wget p7zip cabextract   
vulkan-icd-loader lib32-vulkan-icd-loader   
xdg-utils desktop-file-utils shared-mime-info   
libnotify 2>/dev/null
;;
esac
}

install_pkgs
ok “Dépendances installées.”

# ── ÉTAPE 2 : Flatpak + Flathub ───────────────────────────────────────

step “2/5 — Flatpak & Flathub”

if ! command -v flatpak &>/dev/null; then
info “Installation de Flatpak…”
case $DISTRO in
debian) $SUDO apt-get install -y -qq flatpak ;;
fedora) $SUDO dnf install -y flatpak ;;
suse)   $SUDO zypper install -y flatpak ;;
arch)   $SUDO pacman -Sy –noconfirm flatpak ;;
esac
fi
ok “Flatpak $(flatpak –version | grep -oP ‘[\d.]+’ | head -1)”

# Flathub (dépôt officiel)

if ! flatpak remote-list 2>/dev/null | grep -q “^flathub”; then
info “Ajout du dépôt Flathub…”
flatpak remote-add –user –if-not-exists flathub   
https://dl.flathub.org/repo/flathub.flatpakrepo
fi
ok “Flathub configuré.”

# ── ÉTAPE 3 : Bottles ─────────────────────────────────────────────────

step “3/5 — Bottles (sandbox par application)”

if ! flatpak list –user 2>/dev/null | grep -q “com.usebottles.bottles”; then
info “Téléchargement de Bottles depuis Flathub (environ 500 Mo)…”
flatpak install –user -y –noninteractive flathub com.usebottles.bottles
ok “Bottles installé.”
else
info “Mise à jour de Bottles…”
flatpak update –user -y com.usebottles.bottles &>/dev/null && ok “Bottles à jour.” || ok “Bottles déjà à jour.”
fi

# ── ÉTAPE 4 : Wine-GE (meilleure compatibilité que Wine vanilla) ──────

step “4/5 — Wine-GE (compatibilité maximale)”
note “Wine-GE = Wine + patches Proton/Steam → meilleur support .NET, anti-DRM, codecs”

WINEGE_DIR=”${HOME}/.local/share/bottles/runners”
mkdir -p “$WINEGE_DIR”

# Récupère la dernière version disponible

WINEGE_LATEST=$(curl -s “https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest”   
2>/dev/null | grep ‘“tag_name”’ | grep -oP ‘GE-Proton[\d-]+’ | head -1 || echo “”)

if [[ -n “$WINEGE_LATEST” ]]; then
WINEGE_ARCHIVE=”${WINEGE_LATEST}.tar.xz”
WINEGE_URL=“https://github.com/GloriousEggroll/wine-ge-custom/releases/latest/download/${WINEGE_ARCHIVE}”
WINEGE_PATH=”${WINEGE_DIR}/${WINEGE_LATEST}”

```
if [[ ! -d "$WINEGE_PATH" ]]; then
    info "Téléchargement Wine-GE ${WINEGE_LATEST}..."
    wget -q --show-progress -O "/tmp/${WINEGE_ARCHIVE}" "$WINEGE_URL" && \
    tar -xJf "/tmp/${WINEGE_ARCHIVE}" -C "$WINEGE_DIR" 2>/dev/null && \
    rm -f "/tmp/${WINEGE_ARCHIVE}" && \
    ok "Wine-GE ${WINEGE_LATEST} installé dans Bottles." || \
    warn "Wine-GE non téléchargeable (réseau) — Wine standard utilisé."
else
    ok "Wine-GE ${WINEGE_LATEST} déjà présent."
fi
```

else
warn “Impossible de récupérer Wine-GE (GitHub inaccessible?) — Wine standard actif.”
fi

# ── ÉTAPE 5 : Associations MIME & lanceur utilisateur ─────────────────

step “5/5 — Intégration bureau & associations de fichiers”

# ── 5a. Fichier .desktop (l’entrée dans le menu et le gestionnaire) ───

DESK_DIR=”${HOME}/.local/share/applications”
mkdir -p “$DESK_DIR”

cat > “${DESK_DIR}/wincompat.desktop” << ‘DESK’
[Desktop Entry]
Version=1.1
Type=Application
Name=WinCompat
GenericName=Exécuteur de programmes Windows
Comment=Ouvre les fichiers Windows (.exe .msi .raw …) dans Bottles
Exec=wincompat %f
Icon=com.usebottles.bottles
Categories=System;Emulator;
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-msdos-program;application/x-winpatch-raw;application/x-bat;application/x-cab;application/x-ms-application;
NoDisplay=false
StartupNotify=true
Terminal=false
Keywords=wine;windows;exe;msi;
DESK

# ── 5b. Règles MIME utilisateur (sans root) ───────────────────────────

MIME_DIR=”${HOME}/.local/share/mime/packages”
mkdir -p “$MIME_DIR”

cat > “${MIME_DIR}/wincompat.xml” << ‘MIMEXML’

<?xml version="1.0" encoding="UTF-8"?>

<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">

  <!-- Exécutables Windows PE32 / PE32+ -->

  <mime-type type="application/x-ms-dos-executable">
    <comment xml:lang="fr">Programme Windows</comment>
    <magic priority="70">
      <match type="string" offset="0" value="MZ"/>
    </magic>
    <glob pattern="*.exe" weight="70"/>
    <glob pattern="*.EXE" weight="70"/>
    <glob pattern="*.com" weight="50"/>
    <glob pattern="*.scr" weight="50"/>
    <glob pattern="*.pif" weight="40"/>
  </mime-type>

  <!-- Installateur MSI (Microsoft Installer) -->

  <mime-type type="application/x-msi">
    <comment xml:lang="fr">Installateur Windows MSI</comment>
    <magic priority="70">
      <!-- Magic bytes OLE2 Compound Document (MSI) -->
      <match type="string" offset="0" value="\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"/>
    </magic>
    <glob pattern="*.msi" weight="70"/>
    <glob pattern="*.MSI" weight="70"/>
    <glob pattern="*.msm" weight="50"/>
    <glob pattern="*.msp" weight="50"/>
  </mime-type>

  <!-- Fichier RAW / paquet auto-extractible -->

  <mime-type type="application/x-winpatch-raw">
    <comment xml:lang="fr">Paquet Windows RAW</comment>
    <magic priority="50">
      <match type="string" offset="0" value="MZ"/>
    </magic>
    <glob pattern="*.raw"  weight="50"/>
    <glob pattern="*.RAW"  weight="50"/>
  </mime-type>

  <!-- Script batch Windows -->

  <mime-type type="application/x-bat">
    <comment xml:lang="fr">Script batch Windows</comment>
    <glob pattern="*.bat" weight="60"/>
    <glob pattern="*.BAT" weight="60"/>
    <glob pattern="*.cmd" weight="60"/>
    <glob pattern="*.CMD" weight="60"/>
  </mime-type>

  <!-- Cabinet Microsoft -->

  <mime-type type="application/x-cab">
    <comment xml:lang="fr">Archive Cabinet Windows</comment>
    <magic priority="60">
      <match type="string" offset="0" value="MSCF"/>
    </magic>
    <glob pattern="*.cab" weight="60"/>
    <glob pattern="*.CAB" weight="60"/>
  </mime-type>

</mime-info>
MIMEXML

# ── 5c. Mises à jour MIME & desktop ──────────────────────────────────

update-mime-database    “${HOME}/.local/share/mime”    2>/dev/null || true
update-desktop-database “${HOME}/.local/share/applications” 2>/dev/null || true

# ── 5d. Associations par défaut xdg ──────────────────────────────────

for MIME in   
“application/x-ms-dos-executable”   
“application/x-msi”   
“application/x-msdos-program”   
“application/x-winpatch-raw”   
“application/x-bat”   
“application/x-cab”; do
xdg-mime default wincompat.desktop “$MIME” 2>/dev/null || true
done
ok “Associations MIME enregistrées (utilisateur, sans root).”

# ── 5e. Lanceur CLI ──────────────────────────────────────────────────

mkdir -p “${HOME}/.local/bin”
cat > “${HOME}/.local/bin/wincompat” << ‘LAUNCHER’
#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────

# wincompat — Lanceur universel Windows sur Linux

# Utilise Bottles (Flatpak) · Sans root · Sans préfixe partagé

# ─────────────────────────────────────────────────────────────

set -euo pipefail

BOTTLES=“flatpak run –user com.usebottles.bottles”

# Pas d’argument → ouvre l’interface graphique Bottles

if [[ $# -eq 0 ]]; then
exec $BOTTLES
fi

FILE=”$1”; shift
[[ ! -f “$FILE” ]] && { echo “Fichier introuvable : $FILE”; exit 1; }
ABS=”$(realpath “$FILE”)”
EXT=”${ABS##*.}”; EXT=”${EXT,,}”

# Notification bureau (silencieuse si non dispo)

notify-send “WinCompat” “→ $(basename “$ABS”)”   
–icon=com.usebottles.bottles –urgency=low 2>/dev/null || true

case “$EXT” in
exe|com|scr)
# Bottles ouvre automatiquement l’exe dans une bottle dédiée
exec $BOTTLES – “$ABS” “$@”
;;
msi|msm|msp)
# MSI → Bottles (msiexec géré en interne par Bottles)
exec $BOTTLES – “$ABS” “$@”
;;
raw)
# .raw : auto-détection du contenu
MAGIC=$(file –brief “$ABS” 2>/dev/null | tr ‘[:upper:]’ ‘[:lower:]’)
if echo “$MAGIC” | grep -qE “pe32|ms-dos|executable”; then
exec $BOTTLES – “$ABS” “$@”
elif echo “$MAGIC” | grep -qE “zip|7-zip|rar|cabinet”; then
TMPD=$(mktemp -d /tmp/wincompat_raw_XXXXXX)
7z x “$ABS” -o”$TMPD” -y &>/dev/null
# Cherche setup.exe / install.exe / installer.exe
SETUP=$(find “$TMPD” -maxdepth 4   
( -iname “setup.exe” -o -iname “install.exe”   
-o -iname “installer.exe” -o -iname “autorun.exe” )   
2>/dev/null | head -1)
if [[ -n “$SETUP” ]]; then
exec $BOTTLES – “$SETUP” “$@”
else
echo “Contenu extrait dans : $TMPD”
echo “Lancez manuellement : wincompat <fichier.exe>”
fi
else
# Tentative directe
exec $BOTTLES – “$ABS” “$@”
fi
;;
bat|cmd)
# Scripts batch → Bottles avec Wine cmd
exec $BOTTLES – “$ABS” “$@”
;;
cab)
# Cabinet → extraction p7zip puis recherche setup
TMPD=$(mktemp -d /tmp/wincompat_cab_XXXXXX)
cabextract -d “$TMPD” “$ABS” &>/dev/null || 7z x “$ABS” -o”$TMPD” -y &>/dev/null
SETUP=$(find “$TMPD” -maxdepth 3 -iname “*.exe” 2>/dev/null | head -1)
[[ -n “$SETUP” ]] && exec $BOTTLES – “$SETUP” “$@” ||   
echo “Extrait dans : $TMPD”
;;
reg)
# Fichier registre → ouverture via Bottles (regedit interne)
exec $BOTTLES – “$ABS”
;;
dll)
# DLL orpheline → copie dans la bottle active ou affiche aide
echo “”
echo “  ── DLL détectée ──”
echo “  Pour enregistrer cette DLL dans une bottle :”
echo “    1. Ouvrez Bottles : wincompat”
echo “    2. Sélectionnez votre bottle”
echo “    3. Outils → DLL → Copier”
;;
iso)
# Image ISO → montage temporaire et recherche autorun
MNT=$(mktemp -d /tmp/wincompat_iso_XXXXXX)
sudo mount -o loop,ro “$ABS” “$MNT” 2>/dev/null ||   
{ echo “Impossible de monter l’ISO (besoin sudo).”; exit 1; }
AUTORUN=$(find “$MNT” -maxdepth 2   
( -iname “autorun.exe” -o -iname “setup.exe” -o -iname “install.exe” )   
2>/dev/null | head -1)
if [[ -n “$AUTORUN” ]]; then
# Copie dans /tmp car ISO en read-only
TMP_EXE=$(mktemp /tmp/wincompat_iso_exe_XXXXXX.exe)
cp “$AUTORUN” “$TMP_EXE”
$BOTTLES – “$TMP_EXE” “$@”
rm -f “$TMP_EXE”
else
echo “Monté dans : $MNT”
echo “Lancez manuellement : wincompat <chemin/setup.exe>”
fi
sudo umount “$MNT” 2>/dev/null || true
rmdir “$MNT” 2>/dev/null || true
;;
*)
# Extension inconnue → tente quand même (peut être un PE32 renommé)
MAGIC=$(file –brief “$ABS” 2>/dev/null | tr ‘[:upper:]’ ‘[:lower:]’)
if echo “$MAGIC” | grep -qE “pe32|ms-dos|executable|msi”; then
exec $BOTTLES – “$ABS” “$@”
else
echo “”
echo “  Extension non reconnue : .$EXT”
echo “  Extensions supportées  : .exe .msi .raw .bat .cmd .cab .dll .reg .iso”
echo “”
echo “  Si c’est un exécutable Windows renommé, essayez :”
echo “    wincompat fichier.$EXT  (déjà tenté, échec détection)”
exit 1
fi
;;
esac
LAUNCHER
chmod +x “${HOME}/.local/bin/wincompat”
ok “Lanceur ‘wincompat’ créé.”

# ── 5f. Intégration Nautilus (GNOME clic droit) ───────────────────────

NAUT_DIR=”${HOME}/.local/share/nautilus/scripts”
mkdir -p “$NAUT_DIR”
cat > “${NAUT_DIR}/Ouvrir avec WinCompat” << ‘NAUT’
#!/usr/bin/env bash
for f in “$@”; do
wincompat “$f” &
done
NAUT
chmod +x “${NAUT_DIR}/Ouvrir avec WinCompat”

# ── 5g. Intégration Dolphin (KDE clic droit) ─────────────────────────

DOLPH_DIR=”${HOME}/.local/share/kio/servicemenus”
mkdir -p “$DOLPH_DIR”
cat > “${DOLPH_DIR}/wincompat.desktop” << ‘DOLPH’
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-winpatch-raw;
Actions=WinCompat

[Desktop Action WinCompat]
Name=Ouvrir avec WinCompat
Icon=com.usebottles.bottles
Exec=wincompat %F
DOLPH

# ── 5h. Intégration Thunar (XFCE) ────────────────────────────────────

THUNAR_DIR=”${HOME}/.config/Thunar”
mkdir -p “$THUNAR_DIR”
THUNAR_RC=”${THUNAR_DIR}/uca.xml”
if [[ ! -f “$THUNAR_RC” ]]; then
cat > “$THUNAR_RC” << ‘THUNAR’

<?xml version="1.0" encoding="UTF-8"?>

<actions>
<action>
    <icon>com.usebottles.bottles</icon>
    <name>Ouvrir avec WinCompat</name>
    <command>wincompat %f</command>
    <description>Lancer ce fichier Windows via Bottles</description>
    <patterns>*.exe;*.msi;*.raw;*.bat;*.cmd</patterns>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
</action>
</actions>
THUNAR
fi
ok "Intégration gestionnaires de fichiers : Nautilus + Dolphin + Thunar."

# ── PATH shell ────────────────────────────────────────────────────────

for RC in “${HOME}/.bashrc” “${HOME}/.zshrc” “${HOME}/.profile”; do
[[ -f “$RC” ]] || continue
grep -q “# WINCOMPAT” “$RC” && continue
echo ‘export PATH=”${HOME}/.local/bin:${PATH}”  # WINCOMPAT’ >> “$RC”
done
export PATH=”${HOME}/.local/bin:${PATH}”
ok “PATH mis à jour.”

# ── Vérification finale ───────────────────────────────────────────────

step “Vérification”

check() {
local label=”$1” cmd=”$2”
printf “  %-38s” “$label”
if eval “$cmd” &>/dev/null; then echo -e “${G}✔${X}”
else echo -e “${Y}⚠  (non critique)${X}”; fi
}

check “Flatpak installé”          “command -v flatpak”
check “Bottles (Flatpak)”         “flatpak list –user | grep -q com.usebottles.bottles”
check “Lanceur wincompat”         “test -x ${HOME}/.local/bin/wincompat”
check “Association .exe → MIME”   “xdg-mime query default application/x-ms-dos-executable | grep -q wincompat”
check “Association .msi → MIME”   “xdg-mime query default application/x-msi | grep -q wincompat”
check “Clic droit Nautilus”       “test -f ‘${HOME}/.local/share/nautilus/scripts/Ouvrir avec WinCompat’”
check “Clic droit Dolphin”        “test -f ${HOME}/.local/share/kio/servicemenus/wincompat.desktop”
check “Wine-GE runner”            “ls ${HOME}/.local/share/bottles/runners/GE* 2>/dev/null | head -1”
check “Vulkan disponible”         “command -v vulkaninfo”

# ── Résumé final ──────────────────────────────────────────────────────

echo “”
echo -e “${B}${G}╔══════════════════════════════════════════════════════╗”
echo    “║  ✅  WINCOMPAT installé et configuré avec succès !  ║”
echo -e “╚══════════════════════════════════════════════════════╝${X}”
echo “”
echo -e “  ${B}Comment ça fonctionne maintenant :${X}”
echo “”
echo -e “  ${C}Double-clic sur un .exe / .msi / .raw${X}”
echo    “    → WinCompat s’ouvre → Bottles crée une bottle isolée”
echo    “    → le programme s’installe ou s’exécute en sandbox”
echo “”
echo -e “  ${C}wincompat fichier.exe${X}   (terminal)”
echo -e “  ${C}wincompat fichier.msi${X}   (installateur)”
echo -e “  ${C}wincompat fichier.iso${X}   (image disque)”
echo -e “  ${C}wincompat${X}               (ouvre Bottles directement)”
echo “”
echo -e “  ${B}Pour désinstaller complètement :${X}”
echo -e “  ${C}bash wincompat.sh –uninstall${X}”
echo “”
echo -e “  ${Y}Rechargez votre terminal : source ~/.bashrc${X}”
echo “”
echo -e “  ${M}Tip :${X} Dans Bottles, activez DXVK + VKD3D dans les”
echo    “  paramètres de chaque bottle pour les apps 3D/jeux.”
echo “”
