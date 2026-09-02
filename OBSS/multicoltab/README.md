# multicoltab

`multicoltab` is a non-floating table environment whose rows may continue in
the next `multicols` column or on the next page. It also works in ordinary
one-column text, where rows continue only on later pages.

Author and maintainer: Andres Zanzani, `azanzani@gmail.com`.

## Overview

There is one environment and one normal row syntax:

```latex
left cell & right cell \\
```

`multicoltab` reads every top-level `\\` as the end of a source row. It then
typesets that row as an independent `tabularx`. Consequently, LaTeX may break
**between rows** but never in the middle of a row.

The final `\\` is optional. Use `\newline` for a line break inside a cell. A
`\\` inside braces is also safe because it is not treated as an outer row end.

The complete body is read before any row is printed. This lets the package
measure natural `l`, `c` and `r` columns across the complete table and use the
same column widths for every row. A small allowance is added to those measured
widths so a cell whose text is exactly at the measured width is not split at a
hyphenation point. Use `X` or a fixed-width paragraph column for cells that are
intended to contain long, wrapping text.

## Minimal example

```latex
\usepackage{multicol}
\usepackage{multicoltab}

\begin{multicols}{2}
\begin{multicoltab}{@{}p{1.8cm}X@{}}
  Armor & Reduces the damage received by a character. \\
  Shield & Can improve the character's defense. \\
  Torch & Provides light in dark places.
\end{multicoltab}
\end{multicols}
```

The default table width is the current `\linewidth`, so the same code fits
each `multicols` column automatically.

## Environment interface

```latex
\begin{multicoltab}[<options>]{<column specification>}
  <rows>
\end{multicoltab}
```

The optional argument is a comma-separated key list:

| Option | Default | Effect |
| --- | --- | --- |
| `width=<length>` | `\linewidth` | Width of every emitted row. |
| `row-sep=<length>` | `0pt` | Vertical space after each row. |
| `break-penalty=<integer>` | `0` | Higher values make a break after a normal row less desirable. |

`width=\linewidth` normally needs no adjustment: inside `multicols`, it is
the width of the current column. A heading is kept with its following row
regardless of `break-penalty`.

## Column specification

The mandatory argument contains the column specification. The package counts
the following direct column tokens and keeps their widths consistent across
all emitted rows. Array separators and modifiers may be placed around them.

| Specification | Meaning |
| --- | --- |
| `l`, `c`, `r` | Natural-width left, centered and right-aligned columns, measured globally across the table. |
| `p{<width>}` | Fixed-width paragraph column, top aligned. |
| `m{<width>}` | Fixed-width paragraph column, vertically centered. |
| `b{<width>}` | Fixed-width paragraph column, bottom aligned. |
| `X` | Paragraph column that absorbs the remaining table width. Multiple `X` columns share the available width. |
| `>{<code>}` | Run `<code>` at the start of every cell in the next column. |
| `<{<code>}` | Run `<code>` at the end of every cell in the previous column. |
| `@{<code>}` | Replace inter-column space with `<code>`; `@{}` removes outer padding. |
| `!{<code>}` | Insert `<code>` between columns without removing normal padding. |
| `|` | Insert a vertical rule. |
| `*{<n>}{<specification>}` | Not supported for column measurement; write repeated columns explicitly. |
| `w{<align>}{<width>}` | Fixed-width single-line column; `<align>` is `l`, `c` or `r`. |
| `W{<align>}{<width>}` | Like `w`, but reports overfull cells. |

`\multicolumn` may be used in an individual row. Keep the column tokens
explicit in the environment specification; custom column-type aliases and
`*{n}{...}` repetitions are not expanded while the package measures columns.

```latex
\begin{multicoltab}{@{}p{2cm}|>{\centering\arraybackslash}X|X@{}}
  Name & First value & Second value \\
  Armor & 2 & 5
\end{multicoltab}
```

### `X` columns

By default, `X` behaves as a top-aligned `p` column. The standard `tabularx`
hook changes that for all following `X` columns:

```latex
\renewcommand{\tabularxcolumn}[1]{m{#1}}
```

`X` columns can also be given relative widths. Their `\hsize` values must add
up to the number of `X` columns, as in this two-column 1:3 split:

```latex
\begin{multicoltab}
  {>{\hsize=.5\hsize}X>{\hsize=1.5\hsize}X}
  Short label & A wider description column.
\end{multicoltab}
```

The usual `array` table parameters remain available: `\tabcolsep`,
`\arraystretch`, `\extrarowheight`, `\arrayrulewidth`, `\doublerulesep`, and
`\extracolsep`. Packages such as `booktabs` and `xcolor` provide their normal
rules and row-colour commands when loaded by the document.

## Heading commands

Every data row uses the normal `cell & cell \\` syntax. The only row command
is `\mchead`, which declares a heading; `\mcheadrepeat` reprints it. Both
commands must end with `\\`.

| Directive | Effect |
| --- | --- |
| `\mchead{<cells>} \\` | Declares and prints a heading; it stays with the following row. |
| `\mcheadrepeat \\` | Prints the last declared heading again, without forcing a break. |

`\mchead` accepts optional `[<before>][<after>]` arguments: material placed
before and after its cells. They are useful for heading rules.

### Heading kept with its first entry

Use `\mchead` for a table heading. It records the cells for later repetition,
prints them now, and prevents a break between the heading and its first data
row. This avoids a heading stranded at the foot of a column or page.

```latex
\mchead[\toprule][\midrule]
  {\textbf{Item} & \textbf{Description}} \\
Armor & Reduces damage received by a character. \\
Shield & Improves a character's defense.
```

### Formatting a normal row

No row wrapper is needed for formatting. Put the usual table command directly
before the row cells. For example, `\rowcolor` colours only the following row.

```latex
Potion & Restores a small number of hit points. \\
\rowcolor{gray!20}
Rope & Useful for climbing and tying equipment. \\
Map & Helps the group avoid getting lost.
```

### Reusing a heading in place

Use `\mcheadrepeat` to print the most recently declared heading again without
starting a new column or page. It is useful before a manually grouped set of
rows; like `\mchead`, it stays with the following row.

```latex
\mchead{\textbf{Item} & \textbf{Description}} \\
Armor & Reduces damage. \\

\mcheadrepeat \\
Torch & Provides light.
```

```latex
\usepackage{booktabs}
\usepackage[table]{xcolor}

\begin{multicoltab}[row-sep=2pt]{@{}p{2.2cm}X@{}}
  \mchead[\toprule][\midrule]{\textbf{Item} & \textbf{Description}} \\
  Potion & Restores a small number of hit points. \\
  \rowcolor{gray!20}
  Rope & Useful for climbing and tying equipment. \\
  Map & Helps the group avoid getting lost.
\end{multicoltab}
```

## Repeating a heading

`multicols` decides an automatic column break only after it has received the
rows. For that reason, an automatic repeated heading at every arbitrary break
is not reliable. Use an explicit break when a repeated heading is required.

Inside `multicols`, `\multicoltabbreak \\` forces the next column and repeats
the heading declared with `\mchead`:

```latex
\begin{multicols}{2}
\begin{multicoltab}{@{}p{1.8cm}X@{}}
  \mchead{\textbf{Item} & \textbf{Description}} \\
  Armor & Reduces damage. \\

  \multicoltabbreak \\
  Torch & Provides light.
\end{multicoltab}
\end{multicols}
```

Outside `multicols`, `\multicoltabpagebreak \\` forces the next page and
repeats the heading. Do not use `\multicoltabpagebreak` inside `multicols`;
use `\multicoltabbreak` there instead.

Both break directives require an earlier `\mchead`. They are complete rows,
so write them alone on a source line.

## Columns and limitations

The environment has no two-column assumption. It works inside every
`\begin{multicols}{n}` supported by `multicol`, for any integer `n` of at
least two.

- A row is the smallest unbreakable unit. A row taller than the available
  space moves as a whole.
- Natural `l`, `c` and `r` columns are measured across the complete table and
  keep the same width in every emitted row. Fixed-width columns (`p{...}`,
  `m{...}`, `b{...}`) and `X` columns remain supported as usual.
- `\multirow` across rows is not supported.
- Floats, captions and footnotes retain the normal restrictions of
  `multicols`.
- The body is collected before its rows are emitted. Avoid verbatim material
  such as `\verb` in table cells; use a verbatim-safe command from another
  package when needed.

## Examples and license

`multicoltab-simple-example.tex` demonstrates normal rows.
`multicoltab-options-example.tex` demonstrates normal formatted rows and options.
`multicoltab-repeated-head-example.tex` demonstrates repeated headings.
`multicoltab-columns-example.tex` demonstrates three and four columns.

The package is released under LPPL 1.3c or later; see `LICENSE`.
