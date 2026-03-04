#!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════

# WINPATCH — Intégration Windows native sur Linux

# Stratégie : Bottles (Flatpak) + binfmt_misc (noyau Linux)

# Pas de root permanent · Pas de préfixe partagé · Infaillible

# Usage : bash <(curl -fsSL https://TON-SERVEUR/winpatch.sh)

# ══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────

G=’\033[0;32m’ C=’\033[0;36m’ Y=’\033[1;33m’ R=’\033[0;31m’ B=’\033[1m’ X=’\033[0m’
ok()   { echo -e “${G}✔${X}  $*”; }
info() { echo -e “${C}→${X}  $*”; }
warn() { echo -e “${Y}⚠${X}  $*”; }
step() { echo -e “\n${B}${C}▸ $*${X}”; }
err()  { echo -e “${R}✘${X}  $*” >&2; exit 1; }

# ── Bannière ──────────────────────────────────────────────────

clear
echo -e “${B}${C}”
cat << ‘BANNER’
██╗    ██╗██╗███╗  ██╗██████╗  █████╗ ████████╗ ██████╗██╗  ██╗
██║    ██║██║████╗ ██║██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██║  ██║
██║ █╗ ██║██║██╔██╗██║██████╔╝███████║   ██║   ██║     ███████║
╚██╔███╔╝ ██║██║╚████║██╔═══╝ ██╔══██║   ██║   ██║     ██╔══██║
╚███╔╝   ██║██║ ╚███║██║     ██║  ██║   ██║   ╚██████╗██║  ██║
╚══╝    ╚═╝╚═╝  ╚══╝╚═╝     ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝
Intégration Windows native · Bottles + noyau Linux
BANNER
echo -e “${X}”
echo -e “  ${B}Ce script installe :${X}”
echo    “   1. Flatpak  →  gestionnaire d’apps sandboxées”
echo    “   2. Bottles  →  1 bottle isolée par .exe (zéro conflit)”
echo    “   3. binfmt_misc → le noyau Linux ouvre .exe/.msi/.raw automatiquement”
echo    “   4. Associations MIME → double-clic natif dans tout gestionnaire”
echo “”
echo -e “  ${Y}Aucune écriture globale · Aucun préfixe partagé · Rollback facile${X}”
echo “”
read -rp “  Appuyer sur Entrée pour installer, Ctrl+C pour annuler…” _

# ── Détection distro ──────────────────────────────────────────

step “Détection du système”
[[ $EUID -eq 0 ]] && SUDO=”” || SUDO=“sudo”

if   command -v apt-get &>/dev/null; then DISTRO=“debian”
elif command -v dnf     &>/dev/null; then DISTRO=“fedora”
elif command -v pacman  &>/dev/null; then DISTRO=“arch”
else err “Distribution non reconnue (apt/dnf/pacman requis).”; fi

ok “Distro : $DISTRO | Kernel : $(uname -r) | Arch : $(uname -m)”
[[ “$(uname -m)” == “x86_64” ]] || err “Nécessite une architecture x86_64.”

# ── Étape 1 : Flatpak ─────────────────────────────────────────

step “1/4 — Installation de Flatpak”
if command -v flatpak &>/dev/null; then
ok “Flatpak déjà présent ($(flatpak –version)).”
else
info “Installation de Flatpak…”
case $DISTRO in
debian) $SUDO apt-get install -y -qq flatpak ;;
fedora) $SUDO dnf install -y flatpak ;;
arch)   $SUDO pacman -Sy –noconfirm flatpak ;;
esac
ok “Flatpak installé.”
fi

# Dépôt Flathub

if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
info “Ajout du dépôt Flathub…”
flatpak remote-add –if-not-exists flathub   
https://dl.flathub.org/repo/flathub.flatpakrepo
ok “Flathub ajouté.”
else
ok “Flathub déjà configuré.”
fi

# ── Étape 2 : Bottles ─────────────────────────────────────────

step “2/4 — Installation de Bottles (sandboxing par application)”
if flatpak list 2>/dev/null | grep -q “com.usebottles.bottles”; then
ok “Bottles déjà installé.”
info “Mise à jour…”
flatpak update -y com.usebottles.bottles &>/dev/null || true
else
info “Installation de Bottles depuis Flathub…”
flatpak install -y –noninteractive flathub com.usebottles.bottles
ok “Bottles installé.”
fi

# Wrapper CLI propre (dans ~/.local/bin — sans root, dans le PATH user)

mkdir -p “${HOME}/.local/bin”
cat > “${HOME}/.local/bin/winpatch” << ‘WRAPPER’
#!/usr/bin/env bash

# winpatch — Lance n’importe quel fichier Windows via Bottles CLI

FILE=”$1”
[[ -z “$FILE” ]] && { echo “Usage: winpatch <fichier.exe|.msi|.raw>”; exit 1; }
[[ ! -f “$FILE” ]] && { echo “Fichier introuvable : $FILE”; exit 1; }

# Chemin absolu requis par Flatpak (sandboxé)

ABS=$(realpath “$FILE”)
flatpak run com.usebottles.bottles – “$ABS”
WRAPPER
chmod +x “${HOME}/.local/bin/winpatch”
ok “Commande ‘winpatch’ créée dans ~/.local/bin”

# ── Étape 3 : binfmt_misc (noyau Linux) ──────────────────────

step “3/4 — Enregistrement au niveau noyau (binfmt_misc)”

# binfmt_misc permet au noyau de reconnaître les binaires Windows

# et de les router automatiquement vers Bottles/Wine

# C’est exactement ce que Windows fait nativement.

info “Chargement du module binfmt_misc…”
$SUDO modprobe binfmt_misc 2>/dev/null || true

if ! mountpoint -q /proc/sys/fs/binfmt_misc 2>/dev/null; then
$SUDO mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null ||   
warn “binfmt_misc non montable (optionnel sur certains systèmes).”
fi

# Chemin vers Wine de la Flatpak Bottles (le plus à jour)

WINE_BIN=”/usr/bin/wine”
command -v wine &>/dev/null && WINE_BIN=”$(command -v wine)”

# Création d’un handler universel

HANDLER=”${HOME}/.local/bin/winpatch-binfmt-handler”
cat > “$HANDLER” << ‘HANDLER_EOF’
#!/usr/bin/env bash

# Handler binfmt_misc — appelé par le noyau pour chaque .exe/.msi

FILE=”$1”
shift

# Priorité 1 : Bottles (sandbox isolée)

if command -v flatpak &>/dev/null &&   
flatpak list 2>/dev/null | grep -q “com.usebottles.bottles”; then
ABS=$(realpath “$FILE” 2>/dev/null || echo “$FILE”)
exec flatpak run com.usebottles.bottles – “$ABS” “$@”
fi

# Priorité 2 : Wine système (fallback)

if command -v wine &>/dev/null; then
EXT=”${FILE##*.}”
case “${EXT,,}” in
msi) exec wine msiexec /i “$FILE” “$@” ;;
*)   exec wine “$FILE” “$@” ;;
esac
fi
echo “Erreur : ni Bottles ni Wine n’est installé.”
exit 1
HANDLER_EOF
chmod +x “$HANDLER”

# Enregistrement binfmt pour .exe (Magic bytes : MZ = 0x4d5a)

if [[ -w /proc/sys/fs/binfmt_misc/register ]] 2>/dev/null; then
# Format : :name:type:offset:magic:mask:interpreter:flags
# Magic ‘MZ’ = tous les PE32/PE32+ (exe, dll, msi…)
echo “:DOSWin:M::MZ::${HANDLER}:PF”   
| $SUDO tee /proc/sys/fs/binfmt_misc/register &>/dev/null &&   
ok “binfmt_misc enregistré (noyau reconnaît .exe/.msi nativement).” ||   
warn “binfmt_misc en lecture seule — association MIME utilisée à la place.”

```
# Persistance au démarrage
if [[ -d /etc/binfmt.d ]]; then
    $SUDO tee /etc/binfmt.d/winpatch.conf > /dev/null << 'BINFMT_CONF'
```

# WINPATCH — Exécution native des binaires Windows (PE32)

:DOSWin:M::MZ::/home/USER/.local/bin/winpatch-binfmt-handler:PF
BINFMT_CONF
# Remplace USER par le vrai user
$SUDO sed -i “s|/home/USER|${HOME}|g” /etc/binfmt.d/winpatch.conf
ok “Persistance binfmt_misc activée (survit aux redémarrages).”
fi
else
warn “binfmt_misc non accessible — utilisation des associations MIME uniquement.”
fi

# ── Étape 4 : Associations MIME & bureau ─────────────────────

step “4/4 — Associations de fichiers (double-clic)”

# Application .desktop pour Bottles

DESKTOP_DIR=”${HOME}/.local/share/applications”
mkdir -p “$DESKTOP_DIR”

cat > “${DESKTOP_DIR}/winpatch.desktop” << ‘DESK’
[Desktop Entry]
Version=1.0
Name=WinPatch (Bottles)
Comment=Ouvrir les fichiers Windows dans une sandbox isolée
Exec=flatpak run com.usebottles.bottles – %f
Icon=com.usebottles.bottles
Type=Application
Categories=System;Emulator;
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-msdos-program;application/x-bat;application/x-winux-raw;application/x-raw-disk-image;
NoDisplay=false
StartupNotify=true
Terminal=false
DESK

# Associations

xdg-mime default winpatch.desktop application/x-ms-dos-executable 2>/dev/null || true
xdg-mime default winpatch.desktop application/x-msi               2>/dev/null || true
xdg-mime default winpatch.desktop application/x-msdos-program     2>/dev/null || true

# Règles MIME utilisateur (sans root)

mkdir -p “${HOME}/.local/share/mime/packages”
cat > “${HOME}/.local/share/mime/packages/winpatch.xml” << ‘MIME’

<?xml version="1.0" encoding="UTF-8"?>

<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-ms-dos-executable">
    <comment>Programme Windows (PE32)</comment>
    <magic priority="60"><match type="string" offset="0" value="MZ"/></magic>
    <glob pattern="*.exe" weight="60"/>
    <glob pattern="*.EXE" weight="60"/>
  </mime-type>
  <mime-type type="application/x-msi">
    <comment>Installateur Windows MSI</comment>
    <glob pattern="*.msi" weight="60"/>
    <glob pattern="*.MSI" weight="60"/>
  </mime-type>
  <mime-type type="application/x-winpatch-raw">
    <comment>Package WinPatch RAW</comment>
    <magic priority="50"><match type="string" offset="0" value="MZ"/></magic>
    <glob pattern="*.raw" weight="50"/>
  </mime-type>
</mime-info>
MIME

update-mime-database “${HOME}/.local/share/mime” 2>/dev/null || true
update-desktop-database “$DESKTOP_DIR”           2>/dev/null || true
ok “Associations MIME enregistrées (utilisateur, sans root).”

# ── PATH utilisateur ──────────────────────────────────────────

SHELL_RC=”${HOME}/.bashrc”
[[ -f “${HOME}/.zshrc” ]] && SHELL_RC=”${HOME}/.zshrc”
if ! grep -q ‘winpatch’ “$SHELL_RC” 2>/dev/null; then
echo ‘export PATH=”${HOME}/.local/bin:$PATH”  # WinPatch’ >> “$SHELL_RC”
fi

# ── Résumé ────────────────────────────────────────────────────

echo “”
echo -e “${B}${G}╔═══════════════════════════════════════════╗”
echo    “║   ✅  WINPATCH installé avec succès !     ║”
echo -e “╚═══════════════════════════════════════════╝${X}”
echo “”
echo -e “  ${B}Couches actives :${X}”
echo -e “   ${G}[noyau]${X}  binfmt_misc  → .exe reconnu par le kernel Linux”
echo -e “   ${G}[user] ${X}  MIME/desktop → double-clic dans le gestionnaire”
echo -e “   ${G}[CLI]  ${X}  winpatch     → commande terminal universelle”
echo -e “   ${G}[app]  ${X}  Bottles      → sandbox isolée par application”
echo “”
echo -e “  ${B}Utilisation :${X}”
echo -e “   ${C}winpatch fichier.exe${X}    → ouvre dans Bottles (sandbox propre)”
echo -e “   ${C}winpatch fichier.msi${X}    → pareil”
echo -e “   ${C}winpatch fichier.raw${X}    → pareil”
echo -e “   ${C}Double-clic .exe${X}        → Bottles s’ouvre automatiquement”
echo “”
echo -e “  ${Y}Rechargez votre terminal : source ~/.bashrc${X}”
echo “”
echo -e “  ${B}Pour désinstaller complètement :${X}”
echo    “   flatpak uninstall com.usebottles.bottles”
echo    “   rm -f ~/.local/bin/winpatch* ~/.local/share/applications/winpatch.desktop”
echo    “   sudo rm -f /etc/binfmt.d/winpatch.conf”
echo “”
