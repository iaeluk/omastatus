# OmaStatus

System status for Omarchy — temperature, CPU, memory, network, storage, battery and GPU in the top bar.

Monitor de sistema para Omarchy na top bar. Temperatura, CPU, memória, rede, disco, bateria e GPU com layout totalmente configurável.

## Install

```sh
omarchy plugin add https://github.com/iaeluk/omastatus.git --enable
```

Enable/disable without removing:

```sh
omarchy plugin disable iaeluk.omastatus
omarchy plugin enable iaeluk.omastatus
```

Update:

```sh
omarchy plugin update iaeluk.omastatus
```

## Usage

- **Bar:** shows pinned sensors with icon + value. Right-click refreshes. Fixed widths keep it stable.
- **Click** the bar item → dropdown with accordions per group. Each row shows icon, label, value and `☑/☐` if pinned.
- **Pin/unpin:** click a row to toggle.
- **Accordion:** click group header to expand/collapse. All start collapsed.
- **Order pinned:** click the gear `` in the header → `ORDEM NA BARRA` appears with `↑ ↓` to move and `✕` to remove. Order is saved and reflected in the bar.
- **Interval:** header shows `ATUALIZADO A CADA Xs` with `−`/`+` to change `updateTime` (1–60s).

## Configure

Move the widget:

```sh
omarchy bar move iaeluk.omastatus --section left|center|right
```

Or edit `~/.config/omarchy/shell.json`:

```json
{ "id": "iaeluk.omastatus", "hotSensors": ["_memory_usage_"], "updateTime": 2 }
```

Full schema in `manifest.json:barWidget.schema` (30+ keys).

Languages: `EN`/`PT`/`ZH`/`ES`/`JA` — auto-detected from `Qt.locale`, fallback `EN`.

## Remove

```sh
omarchy plugin remove iaeluk.omastatus --yes
```

## License

MIT — see `LICENSE`.
