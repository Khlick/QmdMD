![Quarto](https://img.shields.io/badge/Quarto-≥1.5.53-blue)
---

# QmdMD

I created this extension to implement Quarto for authoring posts utilizing R and Python for my static website [khrisgriffis.com](https://khrisgriffis.com), which is built upon [Jekyll](https://jekyllrb.com) and some of my own customizations ([Khlick/khlick.github.io](https://github.com/Khlick/khlick.github.io)). I needed a way to generate a [Kramdown](https://kramdown.gettalong.org)-compatible markdown file from the QMD files, so I wrote this extension to handle placing custom YAML metadata into the head of the output `.md`, and to parse links, images, etc., for Kramdown compliance, since my site generator uses Kramdown. Further, code blocks are stripped of any extra attributes and classes that typically show up as an extra `{lang .class attr="val"}` so we can limit the code block to its language only, e.g., `~~~ python`.

## Installation

```bash
quarto add Khlick/QmdMD
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Features

### Custom YAML front-matter
Custom YAML front-matter may be inserted into the rendered markdown (`.md`) by utilizing the `meta:` YAML field in the `.qmd` file:

```yaml
meta:
  tags:
    - featured
    - neuroscience
  options:
    - someOption
```
Which will render at the base level of the output file's YAML front-matter:
```yaml
tags:
- featured
- neuroscience
options:
- someOption
```
The `.qmd` header is expected to have fields `author`, `title`, and `date`, where `date` is optional as the extension will automatically populate it with the rendered date (formatted as `%Y-%m-%d %H:%M:%S %z`). Further, the extension appends a new metadata field, `generated-on`, which has the date of rendering (formmatted as `%Y-%m-%d` ).

### Kramdown-Compliant Markdown

A major feature of the extension is the parsing of Quarto's Github Flavored Markdown ([`gfm`](https://quarto.org/docs/output-formats/gfm.html)) to be compliant with my Kramdown markdown processor. 


## Usage

You can either place the format in the QMD file's YAML header:

```yaml
---
# document metadata
format: qmdmd-gfm
---
```

Or by using the Quarto `--to, -t` option for `render`:

```bash
quarto render document.qmd --to qmdMD-gfm
```

## Example

For a complete example, please refer to the [template.qmd](./template.qmd) and its rendered output [template.md](./template.md).

---

## Requirements

Only [Quarto](https://quarto.org/) 1.5.5x or greater is required for the extension. However, to render the [`template.qmd`](./template.qmd), you'll also need R and Python available to your quarto installation (see [`quarto check`](https://quarto.org/docs/troubleshooting/#check-the-version-of-quarto-and-its-dependencies)).

At the time of writing, here's my installation:
```bash
Quarto 1.6.1
[>] Checking versions of quarto binary dependencies...
      Pandoc version 3.2.0: OK
      Dart Sass version 1.70.0: OK
      Deno version 1.41.0: OK
      Typst version 0.11.0: OK
[>] Checking versions of quarto dependencies......OK
[>] Checking Quarto installation......OK
      Version: 1.6.1
      Path: ~\AppData\Local\Programs\Quarto\bin
      CodePage: 1252

[>] Checking tools....................OK
      TinyTeX: (not installed)
      Chromium: (not installed)

[>] Checking LaTeX....................OK
      Tex:  (not detected)

[>] Checking basic markdown render....OK

[>] Checking Python 3 installation....OK
      Version: 3.12.1
      Path: ./qmdMD/.python312/Scripts/python.exe
      Jupyter: 5.7.2
      Kernels: python3

[>] Checking Jupyter engine render....OK

[>] Checking R installation...........OK
      Version: 4.2.2
      Path: ~/R/R-42~1.2
      LibPaths:
        - ~/R/win-library/4.2
        - ~/R/R-4.2.2/library
      knitr: 1.45
      rmarkdown: 2.27

[>] Checking Knitr engine render......OK
```

The `template.qmd` requires the following R and Python libraries

### R Packages

- `knitr`
- `reticulate`
- `ggplot2`
- `rmarkdown`

### Python Packages

- `numpy`
- `matplotlib`
- `pandas`
- `jupyter`
