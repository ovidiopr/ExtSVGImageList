# ![TExtSVGImageList](images/TExtSVGImageList_150.png)ExtSVGImageList

A Lazarus/FPC component that extends the standard `TImageList` with native SVG support. SVG sources are stored losslessly inside the `.lfm` form file and rasterized at runtime at every required Hi-DPI resolution, so icons always look sharp on any display, from a 96 DPI laptop screen to a 4K monitor.

`TExtSVGImageList` started from the code of `TBGRASVGImageList` (part of the `BGRAControls` package) and evolved into a full drop-in replacement for the standard LCL TImageList. While `TBGRASVGImageList` focuses on SVG rendering through `BGRABitmap`, `TExtSVGImageList` inherits directly from `TImageList`, meaning any LCL control that accepts a `TImageList` (toolbars, list views, tree views, action lists, and so on) works with it without any code changes. On top of that it adds automatic Hi-DPI rasterization at multiple scale factors, lazy SVG parsing with a parsed-object cache, and a richer rendering API that lets you draw any entry to a `TCanvas` or `TBGRABitmap` at an arbitrary size and opacity.

## Features

- **Drop-in replacement for `TImageList`** — inherits directly from it, so any LCL control that accepts a `TImageList` (toolbars, list views, tree views, action lists, …) works without modification.
- **SVG stored in the form file** — no external image files to distribute; the raw SVG source is serialized as a binary property inside the `.lfm`. The rasterized bitmaps are not stored, so the `.lfm` stays small.
- **Automatic Hi-DPI rasterization** — at startup the component renders each SVG at 100 % plus a list of extra scalings (125 %, 150 %, and 200 % by default), and registers all scalings with the LCL so the correct one is picked automatically for the active DPI.
- **Configurable scalings** — the extra scalings are a published `Scales` collection, editable in the Object Inspector, and can also be replaced from code with `SetScaling`.
- **Lazy SVG parsing** — `TBGRASVG` objects are parsed on first use and cached, so unused entries cost nothing.
- **Incremental updates** — `Add`, `Remove`, `Move`, `Exchange` and `Replace` update only the affected raster entries instead of rebuilding the whole list. `BeginUpdate`/`EndUpdate` batch several changes into a single rebuild and a single consumer notification.
- **Flexible alignment control** — images can be positioned using either the alignment hints embedded in the SVG itself, or explicit horizontal/vertical alignment properties on the component.
- **Direct rendering API** — individual SVGs can be drawn to a `TCanvas`, a `TBGRABitmap`, or retrieved as a `TBitmap` or `TBGRABitmap` at any pixel size, independently of the rasterized image list.
- **Visual designer editor** — a double-click in the IDE opens a dedicated editor for adding, removing, replacing, and reordering SVG entries, with a live preview pane.

## Requirements

| Dependency | Notes |
|---|---|
| [Lazarus](https://www.lazarus-ide.org/) | 2.0 or later recommended |
| [FPC](https://www.freepascal.org/) | 3.2.0 or later (3.2.2+ preferred) |
| [BGRAControls](https://github.com/bgrabitmap/bgracontrols) | Must be installed as a Lazarus package |

BGRAControls provides `TBCSVGViewer`, `TBGRABitmap`, `TBGRASVG`, and the SVG rendering engine. Install it through the Lazarus **Online Package Manager** or manually from its
repository before installing `ExtSVGImageList`.

## Installation

1. Open Lazarus.
2. Choose **Package → Open Package File (.lpk)** and open `extsvgimagelist.lpk`.
3. Click **Compile**, then **Install**.
4. Lazarus will rebuild the IDE. After restart, `TExtSVGImageList` appears on the **Misc** component palette tab.

## Quick Start

1. Drop a `TExtSVGImageList` onto a form.
2. Double-click it to open the SVG Image List editor.
3. Click **Add** and select one or more `.svg` files.
4. Assign the component to any control's `Images` property, exactly as you would a standard `TImageList`.

```pascal
// At runtime you can also add SVGs programmatically:
var
  SVGSource: string;
  Stream: TFileStream;
begin
  Stream := TFileStream.Create('icons/save.svg', fmOpenRead);
  try
    SetLength(SVGSource, Stream.Size);
    Stream.ReadBuffer(SVGSource[1], Stream.Size);
  finally
    Stream.Free;
  end;
  ExtSVGImageList1.Add(SVGSource);
end;
```

## Published Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `Width` | `integer` | `16` | Base image width in pixels (inherited from `TImageList`; changing it triggers re-rasterization). |
| `Height` | `integer` | `16` | Base image height in pixels (same behavior as `Width`). |
| `ReferenceDPI` | `integer` | `96` | The DPI at which `Width` × `Height` is defined. Used only by `GetScaledSize`; changing it does not re-rasterize. |
| `UseSVGAlignment` | `boolean` | `False` | When `True`, honors the alignment hints embedded in the SVG source. When `False`, the `HorizontalAlignment` and `VerticalAlignment` properties govern placement. |
| `HorizontalAlignment` | `TAlignment` | `taCenter` | Horizontal placement of the SVG within its cell when `UseSVGAlignment` is `False`. |
| `VerticalAlignment` | `TTextLayout` | `tlCenter` | Vertical placement of the SVG within its cell when `UseSVGAlignment` is `False`. |
| `Scales` | `TExtSVGScaleCollection` | 125, 150, 200 | Extra scales generated besides 100 %, each one a percentage of `Width` × `Height`. See [Scales](#scales). |
| `OnRenderError` | event | — | Called with the entry index and the exception when an entry cannot be rendered. A transparent placeholder is used, so raster indexes stay aligned with the SVG entries. |

## How Rasterization Works

The raster image list is rebuilt synchronously whenever an SVG entry, `Width`/`Height`, `Scales` or an alignment property changes, both at design time and at runtime. The rebuild is deferred while the component is being loaded (it is built once in `Loaded`) and inside `BeginUpdate`/`EndUpdate`, where it happens once at `EndUpdate`.

The 100 % scaling is always produced, plus one scaling per item in `Scales`. With the default scales, four scales are produced per entry on every platform:

| Slot | Scale | Typical size (base 16 px) |
|---|---|---|
| 1 | 100 % | 16 × 16 |
| 2 | 125 % | 20 × 20 |
| 3 | 150 % | 24 × 24 |
| 4 | 200 % | 32 × 32 |

Scalings whose scaled width rounds to the same pixel size are generated only once.

## Scales

Besides the 100 % scaling, which is always generated, the component produces a configurable list of extra scales. Each scale is a percentage of the image list's `Width` and `Height`, so changing the base size keeps every scaling proportional. The defaults are 125 %, 150 %, and 200 %, on every platform.

### At design time

Select the `Scales` property in the Object Inspector and click its **…** button to open the collection editor, where you can add, remove, and reorder items. Each item has a single `Percent` property, and its name in the editor shows the value (for example `125 %`). Values outside 1–1000 are clamped to that range. An empty list means "100 % only" and is stored explicitly, so it survives a reload.

### At runtime

```pascal
ExtSVGImageList1.SetScaling([125, 150, 200]);  // the defaults
ExtSVGImageList1.SetScaling([150, 300]);       // custom scales
ExtSVGImageList1.SetScaling([]);               // 100 % only
```

`SetScaling` takes the same percentages as the `Scales` property and replaces the whole list in a single step, which triggers one re-rasterization. Values outside 1–1000 raise `ERangeError` before anything is changed, so the current scales stay untouched. Passing the list that is already in effect does nothing.

## Managing entries at runtime

| Method | Notes |
|---|---|
| `Add(SVG)`, `Replace(Index, SVG)` | Raise an exception on invalid SVG, leaving the list unchanged. |
| `Remove(Index)` / `Delete(Index)`, `Clear` | `Delete(-1)` clears the list. |
| `Move`, `Exchange` | Reorder entries. |
| `SetSize(W, H)` | Changes `Width` and `Height` with a single rebuild. |
| `SVGCount`, `SVGString[Index]` | Number of entries and their raw source. |

`Assign` copies the SVG sources, scales and alignment settings from another `TExtSVGImageList`. Assigning any other image list raises `EConvertError`, because it has no SVG sources.

## SVG Alignment

Two alignment modes are available, controlled by `UseSVGAlignment`:

**`UseSVGAlignment = False` (default)**  
The SVG is drawn into its cell according to `HorizontalAlignment` (`taLeftJustify`, `taCenter`, `taRightJustify`) and `VerticalAlignment` (`tlTop`, `tlCenter`, `tlBottom`). This is the most predictable mode and works well with SVGs that do not embed explicit alignment or viewBox hints.

**`UseSVGAlignment = True`**  
BGRABitmap's own SVG renderer interprets any alignment or preserveAspectRatio attributes present in the SVG source. Use this when your SVGs carry their own layout intent.

Both modes can be overridden per-call on every `Draw`, `GetBitmap`, and
`GetBGRABitmap` overload that accepts an `AUseSVGAlignment` parameter.

## Designer Editor

Double-clicking the component in the Lazarus form designer opens the
**SVG Image List Editor**:

- **Add / Remove** — load one or more SVG files from disk or delete existing entries. Files that are not valid SVG are skipped and listed in an error message.
- **Replace** — swap the SVG source of an existing entry without changing its index.
- **Up / Down** — reorder entries.
- **Entry list** — shows the actual rasterized image of each entry, at the size controls will use.
- **Preview pane** — shows the selected SVG rendered at full size, respecting the current alignment settings.
- **Alignment toolbar** — sets `HorizontalAlignment` and `VerticalAlignment` interactively; disabled when `UseSVGAlignment` is checked.

The designer only marks the form as modified when at least one change has actually been made, so cancelling without editing leaves the project clean.

## License

These components are released under the **GNU Lesser General Public License v2.1 or later (LGPL-2.1-or-later)**.

You are free to use, study, modify, and redistribute them under the terms of the LGPL. If you distribute a modified version of these library components, you must do so under the same license.

See [https://www.gnu.org/licenses/lgpl-2.1.html](https://www.gnu.org/licenses/lgpl-2.1.html) for the full license text.

> **Note for application developers:** `ExtSVGImageList` is licensed under the LGPL with the same linking exception as `Free Pascal` and `Lazarus`. This allows the component to be linked into commercial and closed-source applications without disclosing your overall application's source code. Only modifications made directly to the `ExtSVGImageList` library must remain open source under the LGPL.

## Disclaimer

> I am not a professional programmer. This component is a hobby project, written for my own use and shared in the hope that others may find it useful. It has been developed and tested to the best of my ability, but comes with **no warranty of any kind**. Use it at your own risk. Bug reports and suggestions are welcome, but I cannot guarantee timely responses or fixes.
