#!/bin/bash
# Roda DENTRO do Weston (DISPLAY=:0). box64 + wine amd64 WoW64 (HoH.exe 32-bit).
# Settings de dynarec podem ser sobrescritos por $GAMEDIR/hohtest.env (teste remoto).
GAMEDIR="${GAMEDIR:-/roms/ports/headoverheels}"
LOG="$GAMEDIR/inner.log"
exec > "$LOG" 2>&1

echo "===== run_inner (box64 + wine wow64) ====="
echo "[inner] $(date '+%H:%M:%S') user=$(id -un) DISPLAY=$DISPLAY"
echo "[inner] box64: $("$BOX64" --version 2>&1 | head -1)"

unset LD_PRELOAD
export WINEDEBUG=-all
export XDG_SESSION_TYPE=x11
export MESA_EXTENSION_MAX_YEAR=2003
export BOX64_SHOWSEGV=1
# SOFTGL=0 (default): GL nativo (mesa escolhe swrast; llvmpipe estourava a RAM).
SOFTGL="${SOFTGL:-0}"

# ---- defaults de PRODUCAO (validados 14/jul/2026, config "M1") ----
# -r0 = DirectX windowed (manual: -r4/GDI e o mais lento; -r3 fullscreen dava
# flicker no gdi e stutter de audio). Windowed + desktop virtual + ddraw=gl
# (swrast) = rapido, audio liso, foco de teclado estavel.
# FASTNAN/FASTROUND ficam FORA: causavam crash na inicializacao, ganho infimo.
export BOX64_DYNAREC=1
export BOX64_DYNAREC_SAFEFLAGS=1
export BOX64_DYNAREC_STRONGMEM=1
export BOX64_DYNAREC_BIGBLOCK=1
export BOX64_DYNAREC_CALLRET=1
RES="-r0"

# ---- overrides para teste remoto ----
if [ -f "$GAMEDIR/hohtest.env" ]; then
  echo "[inner] === hohtest.env ativo ==="
  cat "$GAMEDIR/hohtest.env"
  . "$GAMEDIR/hohtest.env"
fi
echo "[inner] SAFEFLAGS=$BOX64_DYNAREC_SAFEFLAGS STRONGMEM=$BOX64_DYNAREC_STRONGMEM BIGBLOCK=$BOX64_DYNAREC_BIGBLOCK CALLRET=$BOX64_DYNAREC_CALLRET FASTNAN=$BOX64_DYNAREC_FASTNAN FASTROUND=$BOX64_DYNAREC_FASTROUND RES=$RES"

if [ "$SOFTGL" = "1" ]; then
  export LIBGL_ALWAYS_SOFTWARE=1
  export GALLIUM_DRIVER=llvmpipe
fi
# DDRAW=gdi|gl : renderer do wined3d p/ DirectDraw (registro do prefixo)
DDRAW="${DDRAW:-gl}"
REG="$WINEPREFIX/user.reg"
if [ -f "$REG" ]; then
  sed -i '/^\[Software\\\\Wine\\\\Direct3D\]/,/^$/d' "$REG"
  printf '\n[Software\\\\Wine\\\\Direct3D] 1752500000\n"renderer"="%s"\n' "$DDRAW" >> "$REG"
  # janela sem decoracao (barra de titulo) dentro do desktop virtual
  sed -i '/^\[Software\\\\Wine\\\\X11 Driver\]/,/^$/d' "$REG"
  printf '\n[Software\\\\Wine\\\\X11 Driver] 1752500000\n"Decorated"="N"\n' >> "$REG"
  echo "[inner] ddraw renderer=$DDRAW, decoracao=off"
fi

cd "$GAMEDIR/gamedata" || { echo "[inner] sem gamedata"; exit 1; }

# GFXCARD: driver do Allegro p/ modos AUTODETECT (-r1/-r2). Vazio = nao forcar.
GFXCARD="${GFXCARD:-}"
{
  if [ -n "$GFXCARD" ]; then printf '[graphics]\ngfx_card = %s\n\n' "$GFXCARD"; fi
  printf '[sound]\ndigi_card = %s\nmidi_card = none\n\n[joystick]\njoytype = none\n' "${DIGI:-WaveOut}"
} > allegro.cfg
echo "[inner] allegro.cfg: gfx_card=${GFXCARD:-auto} digi=${DIGI:-WaveOut}"

"$BOX64" "$WINEDIR/bin/wineserver" -k 2>/dev/null; sleep 1
"$BOX64" "$WINEDIR/bin/wineserver" -p -f >/dev/null 2>&1 &
sleep 3

echo "[inner] ===== JOGO: HoH.exe $RES ($(date '+%H:%M:%S')) ====="
# LIMITCPU=1 (via hohtest.env): deixa o core 0 livre p/ rede/IRQ (debug remoto)
RUNPFX=""
[ "$LIMITCPU" = "1" ] && command -v taskset >/dev/null && RUNPFX="taskset -c 1-3"
# VDESK=1 (default): desktop virtual do wine — a janela X nunca e recriada,
# entao o foco de teclado nao se perde na transicao intro->menu (DirectInput).
if [ "${VDESK:-1}" = "1" ]; then
  echo "[inner] usando desktop virtual 640x480"
  $RUNPFX "$BOX64" "$WINEDIR/bin/wine" explorer /desktop=HoH,640x480 "HoH.exe" $RES > "$GAMEDIR/game.log" 2>&1
else
  $RUNPFX "$BOX64" "$WINEDIR/bin/wine" "HoH.exe" $RES > "$GAMEDIR/game.log" 2>&1
fi
RC=$?
echo "[inner] wine saiu codigo $RC em $(date '+%H:%M:%S')"
echo "----- crashes no game.log -----"
grep -aiE 'page fault|SIGSEGV|Unhandled|BOX64.*Signal' "$GAMEDIR/game.log" 2>/dev/null | tail -6
"$BOX64" "$WINEDIR/bin/wineserver" -k 2>/dev/null
echo "[inner] FIM"
