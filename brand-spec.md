# Flugger Brand Specification

## Brand idea

Flugger is a calm, focused workbench for the tight Flutter run–observe–reload loop. It should feel like a dependable macOS instrument: warm, precise, and fast without looking like a terminal theme or an official Flutter product.

## Color system

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Accent | `#C65D2E` | `#E88B4C` | Primary actions, active filters, run-state emphasis |
| Accent soft | `#F3D8C8` | `#4A2A1D` | Selection and hover backgrounds |
| Background | `#F3EFE7` | `#171815` | Main workspace |
| Surface | `#FBF9F4` | `#20211D` | Console and raised controls |
| Text primary | `#25231F` | `#F4F0E8` | Primary copy |
| Text secondary | `#706B61` | `#AAA49A` | Supporting copy and metadata |
| Divider | `#D7D0C4` | `#3A3B34` | Structure and separators |
| Success | `#3F7D58` | `#76B98A` | Running and completed states |
| Warning | `#A96A20` | `#E2A85B` | Starting and stopping states |
| Error | `#B84B41` | `#E47B72` | Failures and destructive actions |

Use copper as a single brand accent. Semantic colors appear only when their meaning is active.

## Typography

- **Interface:** SF Pro, using the system font for controls, headings, and body copy.
- **Console:** SF Mono through SwiftUI's monospaced system design.
- **Scale:** 22 pt display, 15 pt heading, 13 pt body, 11 pt caption.

## Layout tokens

- Spacing: 4, 8, 12, 16, 24, 32 pt.
- Corner radii: 6, 10, 14 pt.
- Interactive targets: at least 44×44 pt.
- Default window: 1120×720 pt; minimum 820×520 pt.

## Signature detail

The console's run-state spine is the sole expressive motion: neutral at rest, copper while transitioning, green while running, and red after failure. Transition states may pulse gently unless Reduce Motion is enabled.

## Icon

The icon is a graphite instrument tile with a large copper terminal prompt. It must remain readable at 16 px, contain no words, and avoid Flutter colors and trademarks.

## Voice

Short, direct, and operational. State what happened and the next useful action. Avoid celebratory language, vague errors, and marketing-style welcome copy.
