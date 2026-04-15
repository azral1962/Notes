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
  title: [Daftar Fungsi Python untuk Random Variable],
  subtitle: [Random Variable],
  authors: (
    ( name: [Armein Z. R. Langi],
      affiliation: [],
      email: [] ),
    ),
  date: [2024-01-07],
  lang: "id",
  toc_title: [Daftar Isi],
  toc_depth: 3,
  doc,
)

= Pendahuluan
<pendahuluan>
Dokumen ini merangkum fungsi-fungsi Python yang umum digunakan untuk bekerja dengan #strong[random variable diskrit, kontinu, dan bivariate], beserta contoh penggunaannya. Fokus utama adalah pada pustaka:

- #NormalTok("random"); untuk simulasi sederhana,
- #NormalTok("numpy"); untuk komputasi numerik dan pembangkitan sampel,
- #NormalTok("scipy.stats"); untuk distribusi probabilitas,
- #NormalTok("matplotlib"); untuk visualisasi.

== Pustaka yang digunakan
<pustaka-yang-digunakan>
#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],));
= Random Variable Diskrit
<random-variable-diskrit>
Random variable diskrit memiliki nilai yang dapat dihitung satu per satu, misalnya jumlah sukses, hasil lemparan dadu, atau jumlah kedatangan kejadian.

== Bilangan acak diskrit sederhana
<bilangan-acak-diskrit-sederhana>
=== #NormalTok("random.randint(a, b)");
<random.randinta-b>
Menghasilkan bilangan bulat acak dari #NormalTok("a"); sampai #NormalTok("b");, inklusif.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("6");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(x)");],));
Contoh penggunaan: simulasi satu lemparan dadu.

=== #NormalTok("random.choice(seq)");
<random.choiceseq>
Memilih satu elemen acak dari suatu daftar.

#Skylighting(([#NormalTok("warna ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"merah\"");#NormalTok(", ");#StringTok("\"hijau\"");#NormalTok(", ");#StringTok("\"biru\"");#NormalTok("]");],
[#NormalTok("pilih ");#OperatorTok("=");#NormalTok(" random.choice(warna)");],
[#BuiltInTok("print");#NormalTok("(pilih)");],));
=== #NormalTok("numpy.random.randint(low, high, size)");
<numpy.random.randintlow-high-size>
Menghasilkan array bilangan bulat acak. Perhatikan bahwa #NormalTok("high"); tidak termasuk.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#NormalTok("sampel_dadu ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_dadu)");],));
== Bernoulli
<bernoulli>
Random variable Bernoulli bernilai 1 untuk sukses dan 0 untuk gagal.

=== Simulasi dengan #NormalTok("random.random()");
<simulasi-dengan-random.random>
#Skylighting(([#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" random.random() ");#OperatorTok("<");#NormalTok(" p ");#ControlFlowTok("else");#NormalTok(" ");#DecValTok("0");],
[#BuiltInTok("print");#NormalTok("(x)");],));
=== #NormalTok("numpy.random.binomial(n, p, size)"); untuk Bernoulli
<numpy.random.binomialn-p-size-untuk-bernoulli>
Karena Bernoulli adalah Binomial dengan #NormalTok("n=1");:

#Skylighting(([#NormalTok("sampel_bernoulli ");#OperatorTok("=");#NormalTok(" np.random.binomial(");#DecValTok("1");#NormalTok(", ");#FloatTok("0.3");#NormalTok(", size");#OperatorTok("=");#DecValTok("20");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_bernoulli)");],));
== Binomial
<binomial>
=== #NormalTok("numpy.random.binomial(n, p, size)");
<numpy.random.binomialn-p-size>
Menghasilkan sampel dari distribusi Binomial.

#Skylighting(([#NormalTok("sampel_binomial ");#OperatorTok("=");#NormalTok(" np.random.binomial(n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_binomial[:");#DecValTok("10");#NormalTok("])");],));
=== #NormalTok("scipy.stats.binom.pmf(k, n, p)");
<scipy.stats.binom.pmfk-n-p>
Menghitung peluang tepat #NormalTok("k"); sukses.

#Skylighting(([#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],
[#NormalTok("peluang ");#OperatorTok("=");#NormalTok(" stats.binom.pmf(k");#OperatorTok("=");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(peluang)");],));
=== #NormalTok("scipy.stats.binom.cdf(k, n, p)");
<scipy.stats.binom.cdfk-n-p>
Menghitung peluang kumulatif $P \( X lt.eq k \)$.

#Skylighting(([#NormalTok("peluang_kumulatif ");#OperatorTok("=");#NormalTok(" stats.binom.cdf(k");#OperatorTok("=");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(peluang_kumulatif)");],));
== Poisson
<poisson>
=== #NormalTok("numpy.random.poisson(lam, size)");
<numpy.random.poissonlam-size>
Menghasilkan sampel Poisson.

#Skylighting(([#NormalTok("sampel_poisson ");#OperatorTok("=");#NormalTok(" np.random.poisson(lam");#OperatorTok("=");#FloatTok("2.5");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_poisson[:");#DecValTok("10");#NormalTok("])");],));
=== #NormalTok("scipy.stats.poisson.pmf(k, mu)");
<scipy.stats.poisson.pmfk-mu>
Menghitung peluang tepat #NormalTok("k"); kejadian.

#Skylighting(([#NormalTok("peluang ");#OperatorTok("=");#NormalTok(" stats.poisson.pmf(k");#OperatorTok("=");#DecValTok("4");#NormalTok(", mu");#OperatorTok("=");#FloatTok("2.5");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(peluang)");],));
=== #NormalTok("scipy.stats.poisson.cdf(k, mu)");
<scipy.stats.poisson.cdfk-mu>
Menghitung peluang kumulatif.

#Skylighting(([#NormalTok("peluang_kumulatif ");#OperatorTok("=");#NormalTok(" stats.poisson.cdf(k");#OperatorTok("=");#DecValTok("4");#NormalTok(", mu");#OperatorTok("=");#FloatTok("2.5");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(peluang_kumulatif)");],));
== Geometrik
<geometrik>
=== #NormalTok("numpy.random.geometric(p, size)");
<numpy.random.geometricp-size>
Menghasilkan sampel dari distribusi Geometrik.

#Skylighting(([#NormalTok("sampel_geom ");#OperatorTok("=");#NormalTok(" np.random.geometric(p");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", size");#OperatorTok("=");#DecValTok("20");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_geom)");],));
=== #NormalTok("scipy.stats.geom.pmf(k, p)");
<scipy.stats.geom.pmfk-p>
Menghitung peluang sukses pertama terjadi pada percobaan ke-#NormalTok("k");.

#Skylighting(([#NormalTok("peluang ");#OperatorTok("=");#NormalTok(" stats.geom.pmf(k");#OperatorTok("=");#DecValTok("4");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.2");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(peluang)");],));
== Nilai harapan dan variansi diskrit
<nilai-harapan-dan-variansi-diskrit>
Jika tersedia array data diskrit:

#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("])");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" np.array([");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.4");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.1");#NormalTok("])");],));
=== Mean dengan #NormalTok("numpy.sum()");
<mean-dengan-numpy.sum>
#Skylighting(([#NormalTok("ekspektasi ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(x ");#OperatorTok("*");#NormalTok(" p)");],
[#BuiltInTok("print");#NormalTok("(ekspektasi)");],));
=== Variansi dengan rumus $E \[ X^2 \] - \( E \[ X \] \)^2$
<variansi-dengan-rumus-ex2---ex2>
#Skylighting(([#NormalTok("variansi ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((x");#OperatorTok("**");#DecValTok("2");#NormalTok(") ");#OperatorTok("*");#NormalTok(" p) ");#OperatorTok("-");#NormalTok(" ekspektasi");#OperatorTok("**");#DecValTok("2");],
[#BuiltInTok("print");#NormalTok("(variansi)");],));
= Random Variable Kontinu
<random-variable-kontinu>
Random variable kontinu dapat mengambil nilai pada suatu interval kontinu, misalnya tinggi badan, berat badan, atau waktu tunggu.

== Uniform kontinu
<uniform-kontinu>
=== #NormalTok("random.random()");
<random.random>
Menghasilkan bilangan acak uniform pada interval $\[ 0 \, 1 \)$.

#Skylighting(([#NormalTok("u ");#OperatorTok("=");#NormalTok(" random.random()");],
[#BuiltInTok("print");#NormalTok("(u)");],));
=== #NormalTok("random.uniform(a, b)");
<random.uniforma-b>
Menghasilkan bilangan acak uniform pada interval $\[ a \, b \]$.

#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" random.uniform(");#DecValTok("10");#NormalTok(", ");#DecValTok("20");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(x)");],));
=== #NormalTok("numpy.random.uniform(low, high, size)");
<numpy.random.uniformlow-high-size>
#Skylighting(([#NormalTok("sampel_uniform ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#DecValTok("10");#NormalTok(", ");#DecValTok("20");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_uniform[:");#DecValTok("10");#NormalTok("])");],));
== Normal
<normal>
=== #NormalTok("numpy.random.normal(loc, scale, size)");
<numpy.random.normalloc-scale-size>
Menghasilkan sampel dari distribusi Normal.

#Skylighting(([#NormalTok("sampel_normal ");#OperatorTok("=");#NormalTok(" np.random.normal(loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_normal[:");#DecValTok("10");#NormalTok("])");],));
=== #NormalTok("scipy.stats.norm.pdf(x, loc, scale)");
<scipy.stats.norm.pdfx-loc-scale>
Menghitung nilai fungsi densitas peluang (PDF).

#Skylighting(([#NormalTok("pdf_175 ");#OperatorTok("=");#NormalTok(" stats.norm.pdf(");#DecValTok("175");#NormalTok(", loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(pdf_175)");],));
=== #NormalTok("scipy.stats.norm.cdf(x, loc, scale)");
<scipy.stats.norm.cdfx-loc-scale>
Menghitung peluang kumulatif $P \( X lt.eq x \)$.

#Skylighting(([#NormalTok("cdf_175 ");#OperatorTok("=");#NormalTok(" stats.norm.cdf(");#DecValTok("175");#NormalTok(", loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(cdf_175)");],));
=== #NormalTok("scipy.stats.norm.ppf(q, loc, scale)");
<scipy.stats.norm.ppfq-loc-scale>
Menghitung kuantil atau inverse CDF.

#Skylighting(([#NormalTok("x95 ");#OperatorTok("=");#NormalTok(" stats.norm.ppf(");#FloatTok("0.95");#NormalTok(", loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(x95)");],));
== Eksponensial
<eksponensial>
=== #NormalTok("numpy.random.exponential(scale, size)");
<numpy.random.exponentialscale-size>
Untuk laju $lambda$, parameter #NormalTok("scale = 1/\\lambda");.

#Skylighting(([#NormalTok("sampel_exp ");#OperatorTok("=");#NormalTok(" np.random.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#FloatTok("0.5");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(sampel_exp[:");#DecValTok("10");#NormalTok("])");],));
=== #NormalTok("scipy.stats.expon.pdf(x, scale)");
<scipy.stats.expon.pdfx-scale>
#Skylighting(([#NormalTok("pdf_2 ");#OperatorTok("=");#NormalTok(" stats.expon.pdf(");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#FloatTok("0.5");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(pdf_2)");],));
=== #NormalTok("scipy.stats.expon.cdf(x, scale)");
<scipy.stats.expon.cdfx-scale>
#Skylighting(([#NormalTok("cdf_2 ");#OperatorTok("=");#NormalTok(" stats.expon.cdf(");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#FloatTok("0.5");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(cdf_2)");],));
== Statistik sampel kontinu
<statistik-sampel-kontinu>
Jika data tersimpan dalam array #NormalTok("x");:

#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("170");#NormalTok(", ");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],));
=== Mean dengan #NormalTok("numpy.mean()");
<mean-dengan-numpy.mean>
#Skylighting(([#NormalTok("mean_x ");#OperatorTok("=");#NormalTok(" np.mean(x)");],
[#BuiltInTok("print");#NormalTok("(mean_x)");],));
=== Variansi dengan #NormalTok("numpy.var()");
<variansi-dengan-numpy.var>
#Skylighting(([#NormalTok("var_pop ");#OperatorTok("=");#NormalTok(" np.var(x)          ");#CommentTok("# variansi populasi");],
[#NormalTok("var_sampel ");#OperatorTok("=");#NormalTok(" np.var(x, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(")  ");#CommentTok("# variansi sampel");],
[#BuiltInTok("print");#NormalTok("(var_pop, var_sampel)");],));
=== Simpangan baku dengan #NormalTok("numpy.std()");
<simpangan-baku-dengan-numpy.std>
#Skylighting(([#NormalTok("std_pop ");#OperatorTok("=");#NormalTok(" np.std(x)");],
[#NormalTok("std_sampel ");#OperatorTok("=");#NormalTok(" np.std(x, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(std_pop, std_sampel)");],));
= Random Variable Bivariate
<random-variable-bivariate>
Bivariate berarti ada dua random variable yang diamati bersama, misalnya tinggi dan berat, atau storage dan compute cost.

== Membuat sampel bivariate independen
<membuat-sampel-bivariate-independen>
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("170");#NormalTok(", ");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("65");#NormalTok(", ");#DecValTok("10");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],));
== Membuat sampel bivariate berkorelasi
<membuat-sampel-bivariate-berkorelasi>
=== #NormalTok("numpy.random.multivariate_normal(mean, cov, size)");
<numpy.random.multivariate_normalmean-cov-size>
Fungsi ini sangat penting untuk simulasi bivariate normal.

#Skylighting(([#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("50");#NormalTok(", ");#DecValTok("100");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("25");#NormalTok(", ");#DecValTok("14");#NormalTok("],");],
[#NormalTok("       [");#DecValTok("14");#NormalTok(", ");#DecValTok("36");#NormalTok("]]");],
[],
[#NormalTok("sampel ");#OperatorTok("=");#NormalTok(" np.random.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" sampel[:, ");#DecValTok("0");#NormalTok("]");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" sampel[:, ");#DecValTok("1");#NormalTok("]");],));
== Kovariansi
<kovariansi>
=== #NormalTok("numpy.cov(m, rowvar=False)");
<numpy.covm-rowvarfalse>
#Skylighting(([#NormalTok("data ");#OperatorTok("=");#NormalTok(" np.column_stack((x, y))");],
[#NormalTok("matriks_cov ");#OperatorTok("=");#NormalTok(" np.cov(data, rowvar");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(matriks_cov)");],));
Atau langsung:

#Skylighting(([#NormalTok("matriks_cov ");#OperatorTok("=");#NormalTok(" np.cov(x, y)");],
[#BuiltInTok("print");#NormalTok("(matriks_cov)");],));
== Korelasi
<korelasi>
=== #NormalTok("numpy.corrcoef(x, y)");
<numpy.corrcoefx-y>
#Skylighting(([#NormalTok("matriks_corr ");#OperatorTok("=");#NormalTok(" np.corrcoef(x, y)");],
[#BuiltInTok("print");#NormalTok("(matriks_corr)");],));
Koefisien korelasi Pearson terdapat pada elemen di luar diagonal.

=== #NormalTok("scipy.stats.pearsonr(x, y)");
<scipy.stats.pearsonrx-y>
Menghasilkan koefisien korelasi sekaligus p-value.

#Skylighting(([#NormalTok("r, p_value ");#OperatorTok("=");#NormalTok(" stats.pearsonr(x, y)");],
[#BuiltInTok("print");#NormalTok("(r, p_value)");],));
== Regresi linear sederhana
<regresi-linear-sederhana>
=== #NormalTok("scipy.stats.linregress(x, y)");
<scipy.stats.linregressx-y>
#Skylighting(([#NormalTok("hasil ");#OperatorTok("=");#NormalTok(" stats.linregress(x, y)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"slope =\"");#NormalTok(", hasil.slope)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"intercept =\"");#NormalTok(", hasil.intercept)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"rvalue =\"");#NormalTok(", hasil.rvalue)");],));
== Joint distribution empiris untuk data diskrit bivariate
<joint-distribution-empiris-untuk-data-diskrit-bivariate>
Jika #NormalTok("x"); dan #NormalTok("y"); adalah data diskrit:

#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("4");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],));
=== Menghitung frekuensi gabungan dengan #NormalTok("pandas.crosstab()");
<menghitung-frekuensi-gabungan-dengan-pandas.crosstab>
#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("tabel ");#OperatorTok("=");#NormalTok(" pd.crosstab(x, y)");],
[#BuiltInTok("print");#NormalTok("(tabel)");],));
=== Mengubah menjadi peluang gabungan empiris
<mengubah-menjadi-peluang-gabungan-empiris>
#Skylighting(([#NormalTok("joint_prob ");#OperatorTok("=");#NormalTok(" pd.crosstab(x, y, normalize");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(joint_prob)");],));
== Mean, variansi, dan kovariansi bivariate
<mean-variansi-dan-kovariansi-bivariate>
#Skylighting(([#NormalTok("mean_x ");#OperatorTok("=");#NormalTok(" np.mean(x)");],
[#NormalTok("mean_y ");#OperatorTok("=");#NormalTok(" np.mean(y)");],
[#NormalTok("var_x ");#OperatorTok("=");#NormalTok(" np.var(x, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("var_y ");#OperatorTok("=");#NormalTok(" np.var(y, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("cov_xy ");#OperatorTok("=");#NormalTok(" np.cov(x, y, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(")[");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("]");],
[],
[#BuiltInTok("print");#NormalTok("(mean_x, mean_y, var_x, var_y, cov_xy)");],));
= Visualisasi
<visualisasi>
Visualisasi sangat penting untuk memahami random variable.

== Histogram untuk random variable tunggal
<histogram-untuk-random-variable-tunggal>
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("170");#NormalTok(", ");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("plt.hist(x, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("'black'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Frekuensi\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram Sampel Normal\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
== Scatter plot untuk random variable bivariate
<scatter-plot-untuk-random-variable-bivariate>
#Skylighting(([#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("50");#NormalTok(", ");#DecValTok("100");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("25");#NormalTok(", ");#DecValTok("14");#NormalTok("], [");#DecValTok("14");#NormalTok(", ");#DecValTok("36");#NormalTok("]]");],
[#NormalTok("sampel ");#OperatorTok("=");#NormalTok(" np.random.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("500");#NormalTok(")");],
[],
[#NormalTok("plt.scatter(sampel[:, ");#DecValTok("0");#NormalTok("], sampel[:, ");#DecValTok("1");#NormalTok("], alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"X\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Y\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scatter Plot Data Bivariate\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
== Overlay histogram dan PDF teoritis
<overlay-histogram-dan-pdf-teoritis>
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("170");#NormalTok(", ");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("plt.hist(x, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("'black'");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.7");#NormalTok(")");],
[],
[#NormalTok("xx ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("140");#NormalTok(", ");#DecValTok("200");#NormalTok(", ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.norm.pdf(xx, loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#NormalTok("plt.plot(xx, pdf)");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram dan PDF Normal\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
= Ringkasan Fungsi Penting
<ringkasan-fungsi-penting>
== Random variable diskrit
<random-variable-diskrit-1>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kebutuhan], [Fungsi Python], [Contoh],),
  table.hline(),
  [Bilangan bulat acak], [#NormalTok("random.randint(a,b)");], [#NormalTok("random.randint(1,6)");],
  [Sampel integer banyak], [#NormalTok("np.random.randint(low, high, size)");], [#NormalTok("np.random.randint(1,7,100)");],
  [Bernoulli], [#NormalTok("np.random.binomial(1,p,size)");], [#NormalTok("np.random.binomial(1,0.3,20)");],
  [Binomial sampel], [#NormalTok("np.random.binomial(n,p,size)");], [#NormalTok("np.random.binomial(10,0.4,1000)");],
  [Binomial PMF], [#NormalTok("stats.binom.pmf(k,n,p)");], [#NormalTok("stats.binom.pmf(3,10,0.4)");],
  [Poisson sampel], [#NormalTok("np.random.poisson(lam,size)");], [#NormalTok("np.random.poisson(2.5,1000)");],
  [Poisson PMF], [#NormalTok("stats.poisson.pmf(k,mu)");], [#NormalTok("stats.poisson.pmf(4,2.5)");],
  [Geometrik sampel], [#NormalTok("np.random.geometric(p,size)");], [#NormalTok("np.random.geometric(0.2,20)");],
  [Mean diskrit], [#NormalTok("np.sum(x*p)");], [#NormalTok("np.sum(x*p)");],
  [Variansi diskrit], [#NormalTok("np.sum((x**2)*p)-E**2");], [sesuai rumus],
)
== Random variable kontinu
<random-variable-kontinu-1>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kebutuhan], [Fungsi Python], [Contoh],),
  table.hline(),
  [Uniform \[0,1)], [#NormalTok("random.random()");], [#NormalTok("random.random()");],
  [Uniform \[a,b\]], [#NormalTok("random.uniform(a,b)");], [#NormalTok("random.uniform(10,20)");],
  [Uniform banyak], [#NormalTok("np.random.uniform(a,b,size)");], [#NormalTok("np.random.uniform(10,20,1000)");],
  [Normal sampel], [#NormalTok("np.random.normal(loc,scale,size)");], [#NormalTok("np.random.normal(170,8,1000)");],
  [Normal PDF], [#NormalTok("stats.norm.pdf(x,loc,scale)");], [#NormalTok("stats.norm.pdf(175,170,8)");],
  [Normal CDF], [#NormalTok("stats.norm.cdf(x,loc,scale)");], [#NormalTok("stats.norm.cdf(175,170,8)");],
  [Normal inverse CDF], [#NormalTok("stats.norm.ppf(q,loc,scale)");], [#NormalTok("stats.norm.ppf(0.95,170,8)");],
  [Eksponensial sampel], [#NormalTok("np.random.exponential(scale,size)");], [#NormalTok("np.random.exponential(2,1000)");],
  [Mean sampel], [#NormalTok("np.mean(x)");], [#NormalTok("np.mean(x)");],
  [Variansi sampel], [#NormalTok("np.var(x,ddof=1)");], [#NormalTok("np.var(x,ddof=1)");],
  [Simpangan baku], [#NormalTok("np.std(x,ddof=1)");], [#NormalTok("np.std(x,ddof=1)");],
)
== Random variable bivariate
<random-variable-bivariate-1>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kebutuhan], [Fungsi Python], [Contoh],),
  table.hline(),
  [Bivariate normal], [#NormalTok("np.random.multivariate_normal(mean,cov,size)");], [lihat contoh],
  [Kovariansi], [#NormalTok("np.cov(x,y)");], [#NormalTok("np.cov(x,y)");],
  [Korelasi], [#NormalTok("np.corrcoef(x,y)");], [#NormalTok("np.corrcoef(x,y)");],
  [Korelasi Pearson], [#NormalTok("stats.pearsonr(x,y)");], [#NormalTok("stats.pearsonr(x,y)");],
  [Regresi linear], [#NormalTok("stats.linregress(x,y)");], [#NormalTok("stats.linregress(x,y)");],
  [Tabel joint empiris], [#NormalTok("pd.crosstab(x,y)");], [#NormalTok("pd.crosstab(x,y)");],
)
= Contoh Mini Proyek
<contoh-mini-proyek>
== Simulasi dadu diskrit
<simulasi-dadu-diskrit>
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", np.mean(x))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variansi =\"");#NormalTok(", np.var(x, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],));
== Simulasi tinggi badan kontinu
<simulasi-tinggi-badan-kontinu>
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("170");#NormalTok(", ");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", np.mean(x))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Std =\"");#NormalTok(", np.std(x, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],));
== Simulasi dua variabel berkorelasi
<simulasi-dua-variabel-berkorelasi>
#Skylighting(([#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("100");#NormalTok(", ");#DecValTok("200");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("100");#NormalTok(", ");#DecValTok("60");#NormalTok("], [");#DecValTok("60");#NormalTok(", ");#DecValTok("80");#NormalTok("]]");],
[#NormalTok("data ");#OperatorTok("=");#NormalTok(" np.random.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" data[:, ");#DecValTok("0");#NormalTok("]");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" data[:, ");#DecValTok("1");#NormalTok("]");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Covariance matrix:\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(np.cov(x, y))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Correlation matrix:\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(np.corrcoef(x, y))");],));
= Penutup
<penutup>
Dalam Python, kombinasi #NormalTok("numpy");, #NormalTok("scipy.stats");, #NormalTok("random");, dan #NormalTok("matplotlib"); sudah sangat memadai untuk:

- mensimulasikan random variable,
- menghitung PMF, PDF, dan CDF,
- mencari mean, variansi, kovariansi, dan korelasi,
- membuat visualisasi histogram dan scatter plot,
- mempelajari hubungan antar variabel acak secara empiris maupun teoritis.

Dokumen ini dapat dijadikan referensi awal untuk pembelajaran probabilitas, statistika, simulasi Monte Carlo, dan analisis data berbasis Python.
