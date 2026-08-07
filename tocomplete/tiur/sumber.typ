// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(
    top,
    float: true,
    scope: "parent",
    clearance: 4mm,
    block(below: 1em, width: 100%)[

      #if title != none {
        align(center, block(inset: 2em)[
          #set par(leading: heading-line-height) if heading-line-height != none
          #set text(font: heading-family) if heading-family != none
          #set text(weight: heading-weight)
          #set text(style: heading-style) if heading-style != "normal"
          #set text(fill: heading-color) if heading-color != black

          #text(size: title-size)[#title #if thanks != none {
            footnote(thanks, numbering: "*")
            counter(footnote).update(n => n - 1)
          }]
          #(if subtitle != none {
            parbreak()
            text(size: subtitle-size)[#subtitle]
          })
        ])
      }

      #if authors != none and authors != () {
        let count = authors.len()
        let ncols = calc.min(count, 3)
        grid(
          columns: (1fr,) * ncols,
          row-gutter: 1.5em,
          ..authors.map(author =>
              align(center)[
                #author.name \
                #author.affiliation \
                #author.email
              ]
          )
        )
      }

      #if date != none {
        align(center)[#block(inset: 1em)[
          #date
        ]]
      }

      #if abstract != none {
        block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
        ]
      }
    ]
  )

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/theorion:0.4.1": make-frame

// Simple theorem render: bold title with period, italic body
#let simple-theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  emph(body)
  parbreak()
}
#let (theorem-counter, theorem-box, theorem, show-theorem) = make-frame(
  "theorem",
  text(weight: "bold")[Theorem],
  inherited-levels: theorem-inherited-levels,
  numbering: theorem-numbering,
  render: simple-theorem-render,
)
#show: show-theorem
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [A Sample Article Using #NormalTok("quarto-ieee"); for IEEE Journal and Transactions],
  authors: (
    ( name: [First Author],
      affiliation: [First Institution, Second Institution],
      email: [usernname\@ieee.org] ),
    ( name: [Second Author],
      affiliation: [Anonymous University],
      email: [] ),
    ),
  date: [2026-06-07],
  abstract: [This document describes the most common article elements and how to use the #NormalTok("quarto-ieee"); class with Pandoc/Quarto-Markdown to produce files that are suitable for submission to IEEE journals. \
#NormalTok("quarto-ieee"); can produce conference, journal, and technical note (correspondence) papers with a suitable choice of class options. It intends to generate PDF and HTML outputs that closely mimick what IEEE would generate.

],
  abstract-title: "Abstract",
  keywords: ("IEEE","IEEEtran","journal","Quarto","Pandoc","template",),
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= Introduction
<sec-intro>
This file is intended to serve as a "sample article file" for IEEE journal papers produced with (Pandoc/Quarto)-Markdown using #NormalTok("IEEEtran.cls"); version 1.8b and later for the PDF output. It is based on #NormalTok("bare_jrnl_new_sample4.tex"); provided by IEEE Publication Technology, Staff and available from #link("https://template-selector.ieee.org/"). The most common elements are covered in the simplified and updated instructions in #NormalTok("New_IEEEtran_how-to.pdf");. For less common elements you can refer back to the original #NormalTok("IEEEtran_HOWTO.pdf");. It is assumed that the reader has a basic working knowledge of {{< latex >}} #cite(<mittelbach2023latex>, form: "prose") and of (Pandoc/Quarto)-Markdown @MacFarlane_Pandoc@Allaire_Quarto_2022 markup.

= The Design, Intent, and Limitations of this Templates
<the-design-intent-and-limitations-of-this-templates>
The #NormalTok("quarto-ieee"); template is intended to #strong[approximate the final look and page length of the articles/papers] either in PDF output or HTML output. #strong[They are NOT intended to be the final produced work that is displayed in print or on IEEEXplore#super[®]]. They will help to give the authors an approximation of the number of pages and layout that will be in the final version.

== Unsuported feature and limitations
<unsuported-feature-and-limitations>
Although most of the {{< latex >}} and #NormalTok("IEEEtran.cls"); commands and environment are supported, there are some limitations when trying to export to a format other than PDF (e.g.~HTML output). For PDF output, the reader can use the {{< latex >}} command directly. However, this may break other output formats. \
It can be can reported the following limitations of the #NormalTok("quarto-ieee"); template: - Several authors with same affiliation produce weird output. In such case, it is recommended to use #NormalTok("note"); and #NormalTok("tex-author-no-affiliation: true");. - For #NormalTok("PDF"); output - #NormalTok("quarto-ieee"); use a hack to handle the #NormalTok("longtable"); issue with 2-column {{< latex >}} documents#footnote[\["#emph[#link("https://github.com/jgm/pandoc/issues/1023%3E")[longtable not compatible with 2-column LaTeX documents]]",]. But, in some cases, a page overflow may occur (see also #ref(<sec-tables>, supplement: [Section])). - For #NormalTok("HTML"); output - The default Quarto toc is used, so the table of contents (toc) display is not the same as on #link("https://ieeexplore.ieee.org/")[IEEEXplore®]. - Footnote are put at the end of document, while on #link("https://ieeexplore.ieee.org/")[IEEEXplore®] there are placed in the accordion. - Figures are not placed in the accordion. - #link("https://ieeexplore.ieee.org/")[IEEEXplore®] specifics (e.g.~citation metrics, etc.) - The #NormalTok("HTML"); output is a Quarto citeable article #cite(<quarto-citation>, form: "prose"), so a citation appendix is automatically added to the article end.

== Contributing
<contributing>
If you want to improve the #NormalTok("quarto-ieee"); template or need some specific features do not hesitate to submit Pull Request#footnote[Go to the PR page: #link("https://github.com/dfolio/quarto-ieee/pulls")] (it is considered good practice to open an issue for discussion before working on a pull request for a new feature).

= Some random text
<some-random-text>
For some of the remainder of this sample we will use dummy text to fill out paragraphs rather than use live text that may violate a copyright. \
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis cursus nisl eget tempor porta. Proin dapibus dictum quam a commodo. Mauris congue scelerisque eros a porta. Proin blandit nulla sapien, et pretium justo dictum non. Vivamus ultricies, elit eu posuere placerat, sapien est condimentum nisl, at tincidunt tortor dolor ac ligula. Suspendisse pulvinar libero quis eros finibus sodales. Vivamus mattis est eget imperdiet luctus. Morbi eget posuere metus. Nam egestas elit lectus, eu tincidunt odio viverra sed. Sed sit amet metus rutrum, ultricies elit in, finibus felis. Integer lobortis dui ante, eget placerat lorem laoreet eu.

Nullam mi ligula, luctus a orci ut, tincidunt varius augue. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Donec sed sem risus. Nam eleifend ultrices elit, vitae posuere tellus interdum et. Nam id nisl at elit malesuada malesuada. Suspendisse viverra ipsum libero, vel pharetra sem maximus sed. Nunc vel est fringilla, rutrum diam eu, egestas quam. Vivamus lobortis blandit velit, commodo finibus mauris. Quisque vel lacus ipsum. Pellentesque quis nulla ipsum.

Aenean in hendrerit quam. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aliquam tincidunt vehicula dignissim. In quis aliquet lectus, ac vestibulum elit. Quisque a magna viverra quam viverra faucibus. Nulla ornare tortor at mollis viverra. Curabitur vel porta dui. Etiam ipsum elit, egestas eget lacus nec, laoreet iaculis lacus. In iaculis risus ac tincidunt viverra. Maecenas tempor iaculis odio quis aliquet. \
Maecenas ac posuere turpis. Fusce est dui, dapibus sed odio eget, eleifend facilisis felis. Nam gravida varius enim, ornare tincidunt urna ullamcorper ut. Donec sit amet eros ac lacus placerat rutrum ut non dolor. Nulla tincidunt nunc massa, sed euismod dui feugiat vitae. Integer tempus risus rutrum tellus interdum, eu aliquet sapien rutrum. Nunc feugiat varius lacus sed laoreet. Integer euismod tellus nisi, id scelerisque sem sagittis eu. Suspendisse at orci vel neque varius tempor nec vitae odio. Integer elementum elementum fermentum. Morbi in turpis cursus, lacinia arcu et, semper orci.

= Front matter
<front-matter>
Most Quarto's authors and affiliations schemes #cite(<quarto-funding>, form: "prose") are supported in the YAML front matter to render authors as requested by IEEE journals in PDF and HTML outputs. When provided to an author, the #NormalTok("note"); entry is rendered as a #NormalTok("\\thanks{}"); in #NormalTok("PDF"); output (ignored in #NormalTok("HTML"); output). Additionally, the reader may add to an author a #NormalTok("photo: path/to/photograph.png"); with a #NormalTok("bio"); metadata entries to generate a #NormalTok("IEEEbiography");, while a sole #NormalTok("bio"); generates a #NormalTok("IEEEbiographynophoto"); (these features is used both in #NormalTok("PDF"); and #NormalTok("HTML"); outputs). \
The #NormalTok("funding"); entry is also used in both PDF and HTML outputs #cite(<quarto-funding>, form: "prose"). At version v1.1.1, only the #NormalTok("funding.statement"); is used. Similarly, #NormalTok("citation"); entry is supported to make the HTML output a "#emph[citeable article]"~#cite(<quarto-citation>, form: "prose").

= Some Common Elements
<some-common-elements>
== Sections and Subsections
<sections-and-subsections>
As stated in the #NormalTok("IEEEtran"); template enumeration of section headings is desirable, but not required. When numbered, it should be consistent throughout the article, that is, all headings and all levels of section headings in the article should be enumerated. Primary headings are designated with Roman numerals, secondary with capital letters, tertiary with Arabic numbers; and quaternary with lowercase letters. References and Acknowledgment headings are unlike all other section headings in text. They are never enumerated. They are simply primary headings without labels, regardless of whether the other headings in the article are enumerated.

The following #ref(<sec-Markdown>, supplement: [Section]) shows some basic usage and capabilities of #NormalTok("quarto-ieee");.

== Markdown basics
<sec-Markdown>
The reader can easily find many documentations on how to write using the (Pandoc/Quarto) Markdown syntax. The #NormalTok("quarto-ieee"); template relies mainly on the Markdown markup supported by Quarto #cite(<quarto-markdown>, form: "prose"), which is build based on Pandoc @MacFarlane_Pandoc@Allaire_Quarto_2022. Below are some basic examples of usage of the Markdown markup (to save space, it is better to consult the original Quarto document #NormalTok("template.qmd");).

=== Display equations
<display-equations>
To write equations use #NormalTok("$"); delimiters for inline formula or #NormalTok("$$"); for block one. To number the equations, it is recommended to use classic equation environments provided by {{< latex >}} and to use #NormalTok("\\eqref{}"); (or #NormalTok("\\ref{}");) for cross-referencing. For example:

The above equation is cross-referenced as , , and .

For now, avoid using the Quarto cross-references that use of #NormalTok("$$ $$"); with #NormalTok("#eq-"); label. It works properly only for PDF output, but there are some issues with HTML#footnote[See the issue here #link("https://github.com/quarto-dev/quarto-cli/issues/2275")] output.

#block[
#emph[Remark]. #NormalTok("quarto-ieee"); template also supports the #link("https://ctan.org/pkg/mhchem")[#NormalTok("mhchem");] (for chemical equation) and #link("https://ctan.org/pkg/physics")[#NormalTok("physics");] (for flexible macros for typesetting equations) {{< latex >}} packages and #link("https://docs.mathjax.org/en/latest/input/tex/extensions/index.html")[Mathjax extensions].

]
=== Theorems, Proofs and Remarks
<theorems-proofs-and-remarks>
To include a reference-able theorem, create a div with a #NormalTok("#thm-"); label. A theorem name is specified via the first heading in the block. For example:

#theorem(title: "Line")[
The equation of any straight line, called a linear equation, can be written as:

$ y = m x + b $

] <thm-line>
The theorem is cross-referenced as #ref(<thm-line>, supplement: [Theorem]).

There are a number of theorem variations supported by #link("https://quarto.org/docs/authoring/cross-references.html#theorems-and-proofs")[Quarto], each with their own label prefix:

- #NormalTok("#thm-"); for Theorem;
- #NormalTok("#lem-"); for Lemma;
- #NormalTok("#cor-"); for Corollary
- #NormalTok("#prp-"); for Proposition;
- #NormalTok("#cnj-"); for Conjecture;
- #NormalTok("#def-"); for Definition;
- #NormalTok("#exm-"); for Example;
- #NormalTok("#exr-"); for Exercise.

The #NormalTok("proof");, #NormalTok("remark"); and #NormalTok("solution"); environments generally receive similar typesetting as theorems. However they are not numbered (and therefore cannot be cross-referenced). To create these environments just use them as the class name of a div such as:

#block[
#emph[Solution] (The solution). An example of solution environment.

]
=== Figures
<figures>
An image with nonempty alt text will be rendered as a figure with a caption with Pandoc and Quarto. Quarto includes a different features to simplify the use of figures and subfigures. Here, it is recommended to use div block with #NormalTok("#fig-"); label to embed your Figures.

#figure([
#box(image("fig1.png", width: 30.0%))
], caption: figure.caption(
position: bottom, 
[
An example of figure.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-1>


#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
An example with sub-figure.
]
, 
label: 
<fig-2>
, 
position: 
bottom
, 
supplement: 
"Figure"
, 
subcapnumbering: 
"(a)"
, 
[
#grid(columns: 2, gutter: 2em,
  [
#block[
#figure([
#box(image("fig1.png"))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-2a>


]
],
  [
#block[
#figure([
#box(image("fig1.png"))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-2b>


]
],
)
]
)
The figures is cross-referenced as #ref(<fig-2>, supplement: [Figure]) and even the sub-figures as #ref(<fig-2b>, supplement: [Figure]).

=== Tables
<sec-tables>
Similarly, many kind of tables may be used with Pandoc and Quarto. The latter also includes different features to simplify the table output. To make tables cross-referenceable use a label with a #NormalTok("#tbl-"); prefix. \
However, it is recommended to avoid using the commonly used single Markdown table known as a 'pipe table'. In fact, Pandoc Markdown uses the {{< latex >}} #NormalTok("longtable"); package, which does not support the two-column mode, which is required for most #NormalTok("IEEEtran"); journals. #NormalTok("quarto-ieee"); uses a hack to temporarily switch to one-column mode. However, this hack may break the page layout. To overcome this issue, a basic way is to use code cells (as for #ref(<tbl-other>, supplement: [Table])). Quarto is a multi-language and it uses #NormalTok("Knitr"); to execute #NormalTok("R"); code and can execute Python code blocks within Markdown.

#quarto_super(
kind: 
"quarto-float-tbl"
, 
caption: 
[
Main Caption
]
, 
label: 
<tbl-panel>
, 
position: 
top
, 
supplement: 
"Table"
, 
subcapnumbering: 
"(a)"
, 
[
#grid(columns: 2, gutter: 2em,
  [
#block[
#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Col1], [Col2], [Col3],),
  table.hline(),
  [A], [B], [C],
  [E], [F], [G],
  [A], [G], [G],
)
], caption: figure.caption(
position: top, 
[
First Table
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-first>


]
],
  [
#block[
#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Col1], [Col2], [Col3],),
  table.hline(),
  [A], [B], [C],
  [E], [F], [G],
  [A], [G], [G],
)
], caption: figure.caption(
position: top, 
[
Second Table
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-second>


]
],
)
]
)
The Tables are cross-referenced as #ref(<tbl-panel>, supplement: [Table]) for details, especially #ref(<tbl-second>, supplement: [Table]). There is also #ref(<tbl-other>, supplement: [Table]).

#Skylighting(([#FunctionTok("options");#NormalTok("(");#AttributeTok("knitr.table.format =");#NormalTok(" ");#ControlFlowTok("function");#NormalTok("() {");#ControlFlowTok("if");#NormalTok(" (knitr");#SpecialCharTok("::");#FunctionTok("is_latex_output");#NormalTok("()) ");#StringTok("'latex'");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#StringTok("'pandoc'");#NormalTok("})");],
[#NormalTok("dt ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("Col1=");#FunctionTok("c");#NormalTok("(");#StringTok("'A'");#NormalTok(",");#StringTok("'B'");#NormalTok(",");#StringTok("'C'");#NormalTok("),");],
[#NormalTok("                 ");#AttributeTok("Col2=");#FunctionTok("c");#NormalTok("(");#StringTok("'D'");#NormalTok(",");#StringTok("'E'");#NormalTok(",");#StringTok("'F'");#NormalTok("),");],
[#NormalTok("                 ");#AttributeTok("Col3=");#FunctionTok("c");#NormalTok("(");#StringTok("'G'");#NormalTok(",");#StringTok("'H'");#NormalTok(",");#StringTok("'I'");#NormalTok("))");],
[],
[#NormalTok("knitr");#SpecialCharTok("::");#FunctionTok("kable");#NormalTok("(");#FunctionTok("head");#NormalTok("(dt), ");#AttributeTok("booktabs =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#figure([
#table(
  columns: 3,
  align: (left,left,left,),
  table.header([Col1], [Col2], [Col3],),
  table.hline(),
  [A], [D], [G],
  [B], [E], [H],
  [C], [F], [I],
)
], caption: figure.caption(
position: top, 
[
A table
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-other>


== Bibliography
<bibliography>
IEEE journal should normally use IEEEtran#footnote[IEEEtran BibTeX style support page is: #link("http://www.michaelshell.org/tex/ieeetran/bibtex/")] {{< bibtex >}} style. Nevertheless, Pandoc and Quarto do support {{< bibtex >}} with natbib or biblatex. However, neither is officially recommended for normal IEEE use. For this reason, #NormalTok("quarto-ieee"); uses #NormalTok("citeproc"); with the #NormalTok("ieee"); CSL style sheet.

= Conclusions
<conclusions>
The conclusion goes here.

#heading(level: 1, numbering: none)[Acknowledgment]
<acknowledgment>
This should be a simple paragraph before the References to thank those individuals and institutions who have supported your work on this article.

Use #NormalTok("[]{.appendix options=\"An Appendix\"}"); markup if you have a single appendix. #NormalTok("IEEEtran"); state that to do not use #NormalTok("\\section{}"); anymore after #NormalTok("\\appendix");.

#bibliography(("bibliography.bib"))

