#!/bin/bash
# Head Over Heels (remake Retrospec 2003) no R36S via Box64 + Wine amd64 WoW64 + Weston(Xwayland). 100% OFFLINE.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi
source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/headoverheels"
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

WINEDIR="$GAMEDIR/winebin64"
BOX64="$GAMEDIR/box64"
PREFIX="$HOME/.wine-hoh64"
WESTON="/tmp/wstn"

$ESUDO chmod 666 /dev/tty0 2>/dev/null
say(){ echo "$1"; printf "%s\n" "$1" > /dev/tty0 2>/dev/null; printf "%s\n" "$1" > /dev/tty1 2>/dev/null; }
cls(){ printf "\033c" > /dev/tty0 2>/dev/null; printf "\033c" > /dev/tty1 2>/dev/null; }

cls; say "Head Over Heels - preparando (1a vez demora)..."
$ESUDO chmod +x "$BOX64" "$GAMEDIR/run_inner.sh" 2>/dev/null
chmod +x "$BOX64" "$GAMEDIR/run_inner.sh" 2>/dev/null
[ -f "$BOX64" ] || { say "ERRO: box64 ausente."; sleep 8; pm_finish; exit 1; }
[ -f "$WINEDIR/bin/wine" ] || { say "ERRO: wine ausente."; sleep 8; pm_finish; exit 1; }
[ -f "$GAMEDIR/weston_pkg.squashfs" ] || { say "ERRO: weston ausente."; sleep 8; pm_finish; exit 1; }
if [ ! -f "$GAMEDIR/gamedata/HoH.exe" ]; then
  say ""
  say "=== ARQUIVOS DO JOGO NAO ENCONTRADOS ==="
  say "Baixe o remake gratuito da Retrospec (Head Over Heels, 2003),"
  say "instale/extraia no PC e copie o CONTEUDO da pasta do jogo para:"
  say "  roms/ports/headoverheels/gamedata/"
  say "(precisa ter HoH.exe, HoHOriginal.dat, Sound/ etc.)"
  sleep 15; pm_finish; exit 1
fi
# o alleg40.dll do instalador original vem compactado (UPX) e crasha o box64:
# garante a versao descompactada por cima
if [ -f "$GAMEDIR/alleg40_unpacked.dll" ]; then
  cmp -s "$GAMEDIR/alleg40_unpacked.dll" "$GAMEDIR/gamedata/alleg40.dll" 2>/dev/null \
    || cp -f "$GAMEDIR/alleg40_unpacked.dll" "$GAMEDIR/gamedata/alleg40.dll" 2>/dev/null
fi

# libera espaco: remove o prefixo antigo do box86 (.wine-hoh) se existir
[ -e "$HOME/.wine-hoh" ] && { $ESUDO rm -rf "$HOME/.wine-hoh" 2>/dev/null; rm -rf "$HOME/.wine-hoh" 2>/dev/null; }

# ===== 1) extrai o prefixo win64 enxuto (symlinks -> winebin64). Marker .hoh_slim64 =====
if [ ! -f "$PREFIX/.hoh_slim64" ]; then
  say "Extraindo prefixo do wine (win64)..."
  $ESUDO rm -rf "$PREFIX"; rm -rf "$PREFIX"; mkdir -p "$PREFIX"
  tar -xzf "$GAMEDIR/hohprefix64.tar.gz" -C "$PREFIX" \
    && touch "$PREFIX/.hoh_slim64" && echo "prefixo extraido OK" || echo "FALHA ao extrair prefixo"
fi
# wine roda como ROOT (westonwrap usa sudo) -> prefixo precisa pertencer a root
$ESUDO chown -R root:root "$PREFIX" 2>/dev/null
echo "prefixo: $(du -sh "$PREFIX" 2>/dev/null | cut -f1)  dono: $(stat -c '%U' "$PREFIX" 2>/dev/null)  livre /: $(df -h / | awk 'NR==2{print $4}')"

# ===== 2) monta o runtime Weston =====
$ESUDO mkdir -p "$WESTON"
$ESUDO umount "$WESTON" 2>/dev/null
$ESUDO mount "$GAMEDIR/weston_pkg.squashfs" "$WESTON" 2>/dev/null \
  && echo "weston montado OK" || echo "MOUNT WESTON FALHOU"
[ -f "$WESTON/westonwrap.sh" ] && echo "westonwrap.sh: OK" || echo "westonwrap.sh: AUSENTE"

# ===== 3) XDG runtime + PERFORMANCE (CPU/GPU/DDR no maximo) =====
export XDG_RUNTIME_DIR=/run/user/0
$ESUDO mkdir -p "$XDG_RUNTIME_DIR"; $ESUDO chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
for g in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo performance | $ESUDO tee "$g" >/dev/null 2>&1; done
MAXF=$(cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq 2>/dev/null)
[ -n "$MAXF" ] && echo "$MAXF" | $ESUDO tee /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq >/dev/null 2>&1
for d in /sys/class/devfreq/*/governor; do echo performance | $ESUDO tee "$d" >/dev/null 2>&1; done

# ===== 3c) OOM mitigation: zram swap (RAM comprimida) - exit 137 anterior foi falta de RAM =====
$ESUDO sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null
if [ "$(free -m 2>/dev/null | awk '/Swap:/{print $2}')" -lt 250 ]; then
  $ESUDO modprobe zram 2>/dev/null
  if [ -e /sys/block/zram0/disksize ]; then
    $ESUDO swapoff /dev/zram0 2>/dev/null; echo 1 | $ESUDO tee /sys/block/zram0/reset >/dev/null 2>&1
    echo lz4 | $ESUDO tee /sys/block/zram0/comp_algorithm >/dev/null 2>&1
    echo 640M | $ESUDO tee /sys/block/zram0/disksize >/dev/null 2>&1
    $ESUDO mkswap /dev/zram0 >/dev/null 2>&1
    $ESUDO swapon -p 10 /dev/zram0 2>/dev/null && echo "zram swap ligado"
  fi
fi
echo "MEM: $(free -m 2>/dev/null | awk '/Mem:/{print $2"MB tot, "$7"MB disp"} /Swap:/{print "swap "$2"MB"}' | tr '\n' ' ')"

# ===== 4) controles: gptokeyb como ROOT (cria /dev/uinput E mata box64). SAIR = SELECT + START =====
$ESUDO env SDL_GAMECONTROLLERCONFIG_FILE="$SDL_GAMECONTROLLERCONFIG_FILE" HOME="$HOME" \
  $GPTOKEYB "HoH.exe" -c "$GAMEDIR/headoverheels.gptk" &
pm_platform_helper "$BOX64" >/dev/null 2>&1 &
sleep 2

# ===== 5) lanca wine DENTRO do Weston (drm gl kiosk system) =====
BOX64LP="$WINEDIR/lib/wine/x86_64-unix:$WINEDIR/lib:$WINEDIR/lib64:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"
echo "=== LANCANDO via westonwrap (box64 + wine wow64) ==="
$ESUDO env \
  GAMEDIR="$GAMEDIR" WINEDIR="$WINEDIR" BOX64="$BOX64" \
  WINEPREFIX="$PREFIX" WINEARCH=win64 WINEDEBUG=-all \
  WINELOADER="$WINEDIR/bin/wine" WINESERVER="$WINEDIR/bin/wineserver" \
  WINEDLLOVERRIDES="mscoree,mshtml=" \
  BOX64_NOBANNER=1 BOX64_PATH="$WINEDIR/bin" BOX64_LD_LIBRARY_PATH="$BOX64LP" \
  XDG_RUNTIME_DIR=/run/user/0 CRUSTY_FPS=1 \
  PATH="$WINEDIR/bin:/usr/bin:/bin" \
  "$WESTON/westonwrap.sh" drm gl kiosk system "$GAMEDIR/run_inner.sh" > "$GAMEDIR/weston.log" 2>&1
echo "=== westonwrap terminou (codigo $?) ==="
echo "----- FPS (crusty) -----"; grep -E 'FPS' "$GAMEDIR/weston.log" 2>/dev/null | tail -10
echo "----- inner.log -----"; cat "$GAMEDIR/inner.log" 2>/dev/null | grep -viE '^[0-9a-f]{4}:fixme:' | tail -40
echo "----- OOM? (dmesg) -----"; $ESUDO dmesg 2>/dev/null | grep -iE 'out of memory|oom-kill|killed process|lowmem' | tail -8 | tee "$GAMEDIR/oom.log"

# ===== 6) limpeza =====
$ESUDO umount "$WESTON" 2>/dev/null
$ESUDO kill -9 "$(pidof gptokeyb)" 2>/dev/null
"$BOX64" "$WINEDIR/bin/wineserver" -k 2>/dev/null
$ESUDO kill -9 "$(pidof wineserver)" 2>/dev/null
pm_finish
