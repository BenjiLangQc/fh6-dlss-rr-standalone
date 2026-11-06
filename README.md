# FH6 DLSS Ray Reconstruction (standalone)

A standalone mod (**no ReShade needed**) that makes Forza Horizon 6 use **DLSS Ray Reconstruction** instead of DLSS
Super Resolution, and feeds it the game's **raw ray-traced GI**, so RR does the denoising instead of the game's
own GI denoiser.

Looking for the ReShade add-on version with live hotkeys? It's a separate project:
[BenjiLangQc/fh6-dlss-rr](https://github.com/BenjiLangQc/fh6-dlss-rr).

Personal, offline-tested mod. FH6 is an online game: injecting code into it could be flagged. Play offline.

## Requirements
- NVIDIA RTX GPU, FH6 with **DLSS** on and **ray-traced GI** set to Medium or High.
- The game's own Streamline files (shipped with FH6), including `sl.dlss_d.dll` / `nvngx_dlssd.dll`.

## Install
1. Copy `xinput1_3.dll` into the game folder (next to `forzahorizon6.exe`). FH6 loads it at startup; it passes every
   controller call on to the real Windows `xinput1_3.dll`, so controllers keep working.
2. Don't combine it with the ReShade add-on version (`fh6rr.addon64`). Use one version at a time.

On first launch the mod writes `fh6rr.ini` and `fh6rr.log` next to it.
Uninstall: delete `xinput1_3.dll` (and `fh6rr.ini` / `fh6rr.log`).

## Settings
All settings are read **at launch**; restart the game after changing them. There are no hotkeys: the GI bypass is
applied when the game creates its GI shaders, so it can't be switched mid-game.

```ini
[fh6rr]
rr=1          ; DLSS Ray Reconstruction on (1) or off (0)
gi_bypass=1   ; bypass the game's GI denoiser so RR denoises the raw GI (needs rr=1)
gi_scale=0    ; raw GI brightness: 0 = x1 (matches the game), 1 = xPI, 2 = x2, 3 = x0.5
gi_ao=2       ; raw GI occlusion from ray hit distance: 0 = off, 1 = soft 0.25 m, 2 = soft 1 m (matches the game), 3 = hard 1.5 m
```

Works with RTSS / MSI Afterburner overlays and DLSS frame generation.

## How it works
1. **Loading:** the mod is a proxy `xinput1_3.dll`, which FH6 imports, so it loads before Streamline initializes.
2. **Ray Reconstruction:** hooks Streamline's `slInit` and adds DLSS Ray Reconstruction (`kFeatureDLSS_RR`) to the
   game's feature list. Each frame, instead of the game's DLSS-SR evaluate, it runs a compute pass that decodes FH6's
   G-buffer into RR guides (diffuse albedo, specular albedo, world normal + roughness), tags them, sets RR options
   (the game's DLSS mode and output size, camera matrices from `slSetConstants`) and evaluates RR through Streamline.
3. **GI denoiser bypass:** when the game creates its GI temporal and spatial denoise pipelines, the mod gives them
   replacement shaders. The temporal pass converts the raw 1-ray GI into the format the game's GI resolve reads; the
   spatial pass only passes that through. The lighting therefore receives noisy GI, and RR cleans it.

Details of every decoded format, and the pitfalls hit on the way, are in [`notes/`](notes/).

## Build
Run `fetch_deps.bat` once (clones MinHook at the pinned commit into `external/`), then `build.bat`
(VS 2022 Build Tools, Windows SDK 10.0.26100 for `dxc.exe`). Output: `build\xinput1_3.dll`.

Third-party code in `external/`: NVIDIA Streamline headers (MIT), MinHook (BSD-2, fetched).

## Known limits
- Tied to the current FH6 build: the GI shader identities and G-buffer layout can change with a game patch.
  If the GI shaders change, the bypass simply stays inactive (RR still works).
- Scalar specular (flagged materials) uses F0 = 0.04; RT6 colored F0 is used where the game uses it.
