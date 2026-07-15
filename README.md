# Head Over Heels (Retrospec remake) — R36S / ArkOS port

Run the classic **Head Over Heels** — the 2003 Windows remake by **Retrospec** — on your **R36S** retro handheld (ArkOS, Rockchip RK3326), fully offline, straight from the Ports menu.

This is a wrapper port: it runs the original x86 Windows game through **Box64 + Wine (WoW64) + Weston/Xwayland**, tuned until it plays smoothly on the RK3326's 4×A35 cores and 1GB of RAM.

> 🇧🇷 [Versão em português abaixo](#-português-br)

---

## What you get

- The full 2003 Retrospec remake (isometric classic by Jon Ritman & Bernie Drummond, remade by the Retrospec team) playable on the R36S
- Smooth gameplay and audio (DirectX windowed mode + Wine virtual desktop + tuned Box64 dynarec)
- Gamepad controls mapped out of the box (gptokeyb)
- **SELECT + START** quits back to EmulationStation
- zram swap enabled during play (the game + Wine are tight in 1GB of RAM)

Tested on **R36S with ArkOS**. Other RK3326 devices (RG351x, RGB20S, GameForce Chi…) with ArkOS/PortMaster-style setups may work, but are untested.

## Installation

1. Download **`headoverheels-r36s.zip`** from the [Releases page](../../releases) (~250MB).
2. Extract it into the **`ports`** folder of your roms SD card. You should end up with:
   ```
   roms/ports/Head Over Heels.sh
   roms/ports/headoverheels/   (box64, winebin64/, weston_pkg.squashfs, ...)
   ```
3. **Get the game** (not included — it's Retrospec's freeware):
   - Download the free 2003 remake here: https://www.old-games.com/download/5770/head-over-heels
   - Install or extract it on a PC.
4. Copy the **contents** of the installed game folder into:
   ```
   roms/ports/headoverheels/gamedata/
   ```
   It must contain `HoH.exe`, `HoHOriginal.dat`, `Sound/`, `Docs/`…
   (Don't worry about `alleg40.dll` — the port automatically swaps in an unpacked copy, the original UPX-packed one crashes Box64.)
5. Refresh the games list / restart EmulationStation and launch **Head Over Heels** from Ports.

⏳ **First launch takes ~1 extra minute** (it extracts a slim Wine prefix to the internal ext4 partition, ~90MB). Later launches are faster.

## Controls

| Button | Action |
|---|---|
| D-pad / left stick | Move |
| A | Jump / Teleport (Space) |
| B | Pick up / Drop (Enter) — confirm in menus |
| X | Fire doughnut (LCtrl) |
| Y | Swap Head/Heels (RCtrl) |
| L1 / R1 | Jump + carry (M) |
| START / SELECT | Menu / back (Esc) |
| **SELECT + START (hold)** | **Quit to EmulationStation** |

## Requirements

- R36S (or similar RK3326 handheld) running **ArkOS**
- **PortMaster** installed (the launcher uses its `control.txt` helpers)
- ~800MB free on the roms card + ~100MB free on the internal ext4 partition

## Troubleshooting

- **"ARQUIVOS DO JOGO NAO ENCONTRADOS" screen** → you skipped step 4; copy the game files into `gamedata/`.
- **Black screen / instant exit** → check the logs written next to the port: `log.txt`, `inner.log`, `game.log`, `weston.log` in `roms/ports/headoverheels/`.
- **Slow?** Make sure nothing else heavy is running; the port already forces the performance governor.

## How it works (tech notes)

- **Box64 0.4.3** (built for RK3326, glibc 2.30) runs **Wine 10.0 amd64 WoW64**, which runs the 32-bit `HoH.exe` without needing box86/32-bit libs.
- Display is **Weston (DRM) + Xwayland** via binarycounter's Westonpack; the game renders through Wine's DirectDraw→OpenGL path on Mesa **swrast** (kernel 4.4 has no Panfrost, and the Mali blob is GLES-only).
- The game runs in **`-r0` DirectX windowed mode** inside a **Wine virtual desktop** (`explorer /desktop=HoH,640x480`) with window decorations disabled — this was the key to smooth video, unbroken audio and stable keyboard focus. (Fun fact: the game's own manual calls the GDI mode we started with "the slowest solution". It was right.)
- Box64 dynarec tuned: `SAFEFLAGS=1 STRONGMEM=1 BIGBLOCK=1 CALLRET=1`; `FASTNAN/FASTROUND` are **off** (they crash this game at startup).
- Input: **gptokeyb** creates a virtual keyboard (uinput) targeting the `HoH.exe` process (Box64 renames its process, so targeting "box64" would break the quit combo).
- 640MB **zram** swap is enabled at launch; the whole stack fits (tightly) in 1GB.

## Credits & licenses

- **Game**: [Retrospec](http://retrospec.sgn.net) — Head Over Heels remake (2003), freeware. Original game by Jon Ritman & Bernie Drummond (Ocean, 1987). Game files are **not** distributed with this port.
- **[Box64](https://github.com/ptitSeb/box64)** by ptitSeb — GPLv3. This port ships a stock **v0.4.3** binary built with `-DRK3326=ON`; source at the link.
- **Wine builds**: [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds) — `wine-10.0-amd64-wow64` (LGPL).
- **Westonpack** (`weston_pkg_0.2.aarch64.squashfs`) by **binarycounter**, distributed via [PortMaster](https://portmaster.games) runtimes.
- **Allegro 4** (`alleg40.dll`) — [giftware license](https://liballeg.org/license.html); an unpacked copy is included.
- Port scripts (this repo): MIT.

---

## 🇧🇷 Português (BR)

Rode o clássico **Head Over Heels** (remake de 2003 da **Retrospec** para Windows) no seu **R36S** com ArkOS, direto do menu Ports, 100% offline.

### Instalação

1. Baixe o **`headoverheels-r36s.zip`** na [página de Releases](../../releases) (~250MB).
2. Extraia dentro da pasta **`ports`** do cartão de roms (fica `roms/ports/Head Over Heels.sh` + `roms/ports/headoverheels/`).
3. **Baixe o jogo** (não incluído — é freeware da Retrospec): https://www.old-games.com/download/5770/head-over-heels — instale/extraia num PC.
4. Copie o **conteúdo** da pasta do jogo para `roms/ports/headoverheels/gamedata/` (precisa ter `HoH.exe`, `HoHOriginal.dat`, `Sound/`…). O `alleg40.dll` é trocado automaticamente por uma cópia descompactada (a original trava o Box64).
5. Atualize a lista de jogos e abra **Head Over Heels** em Ports.

⏳ **A primeira execução demora ~1 minuto a mais** (extrai o prefixo do Wine). Depois fica mais rápido.

### Controles

Direcional move; **A** pula, **B** pega/solta (confirma nos menus), **X** atira rosquinha, **Y** troca Head/Heels, **L1/R1** pula carregando, **START/SELECT** = Esc. **Segure SELECT+START para sair** do jogo.

### Problemas?

Veja os logs em `roms/ports/headoverheels/` (`log.txt`, `inner.log`, `game.log`). Se aparecer a tela "ARQUIVOS DO JOGO NAO ENCONTRADOS", falta copiar os arquivos do jogo pro `gamedata/`.

---

*Keywords: R36S, ArkOS, PortMaster, RK3326, box64, wine, Head Over Heels, Retrospec, port, handheld, RG351, isometric, ZX Spectrum remake*
