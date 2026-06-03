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
  title: [Daftar Fungsi Python untuk Random Variable Diskrit, Kontinu, dan Bivariat],
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
Dokumen ini merangkum fungsi-fungsi Python yang berguna untuk mempelajari #strong[random variable diskrit], #strong[random variable kontinu], dan #strong[random variable bivariat]. Contoh-contoh difokuskan pada pustaka yang paling umum digunakan dalam analisis data dan probabilitas:

- #NormalTok("random");
- #NormalTok("numpy");
- #NormalTok("scipy.stats");
- #NormalTok("pandas");
- #NormalTok("matplotlib");

Dokumen ini cocok digunakan sebagai catatan kuliah, bahan praktikum, maupun dasar untuk eksperimen komputasional dalam topik probabilitas dan statistika.

= Pustaka yang Digunakan
<pustaka-yang-digunakan>
#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],));
= Random Variable Diskrit
<random-variable-diskrit>
== Pengertian
<pengertian>
Random variable diskrit mengambil nilai-nilai yang dapat dihitung satu per satu, misalnya hasil lemparan dadu, jumlah keberhasilan, atau banyaknya pelanggan yang datang dalam satu interval waktu.

== Fungsi Dasar dari #NormalTok("random");
<fungsi-dasar-dari-random>
=== #NormalTok("random.random()");
<random.random>
Menghasilkan bilangan acak uniform pada interval $\[ 0 \, 1 \)$.

#Skylighting(([#NormalTok("random.random()");],));
=== #NormalTok("random.randint(a, b)");
<random.randinta-b>
Menghasilkan bilangan bulat acak dari $a$ sampai $b$.

#Skylighting(([#NormalTok("random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("6");#NormalTok(")");],));
Contoh simulasi 10 kali lempar dadu:

#Skylighting(([#NormalTok("[d ");#OperatorTok(":=");#NormalTok(" random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("6");#NormalTok(") ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("10");#NormalTok(")]");],));
=== #NormalTok("random.choice(seq)");
<random.choiceseq>
Memilih satu elemen secara acak dari sebuah daftar.

#Skylighting(([#NormalTok("random.choice([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("])");],));
=== #NormalTok("random.choices(population, weights, k)");
<random.choicespopulation-weights-k>
Mengambil sampel acak dengan bobot tertentu.

#Skylighting(([#NormalTok("random.choices([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], weights");#OperatorTok("=");#NormalTok("[");#FloatTok("0.7");#NormalTok(", ");#FloatTok("0.3");#NormalTok("], k");#OperatorTok("=");#DecValTok("20");#NormalTok(")");],));
Ini dapat dipakai untuk mensimulasikan variabel Bernoulli dengan peluang sukses 0.3.

== Fungsi Diskrit pada #NormalTok("numpy.random");
<fungsi-diskrit-pada-numpy.random>
=== Bernoulli / Binomial
<bernoulli-binomial>
=== #NormalTok("np.random.binomial(n, p, size)");
<np.random.binomialn-p-size>
Menghasilkan sampel dari distribusi binomial.

#Skylighting(([#NormalTok("np.random.binomial(n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(", size");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],));
Untuk Bernoulli, gunakan #NormalTok("n=1");.

#Skylighting(([#NormalTok("np.random.binomial(n");#OperatorTok("=");#DecValTok("1");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", size");#OperatorTok("=");#DecValTok("20");#NormalTok(")");],));
=== Poisson
<poisson>
=== #NormalTok("np.random.poisson(lam, size)");
<np.random.poissonlam-size>
#Skylighting(([#NormalTok("np.random.poisson(lam");#OperatorTok("=");#FloatTok("2.5");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
=== Geometrik
<geometrik>
=== #NormalTok("np.random.geometric(p, size)");
<np.random.geometricp-size>
#Skylighting(([#NormalTok("np.random.geometric(p");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
== Fungsi Distribusi Diskrit pada #NormalTok("scipy.stats");
<fungsi-distribusi-diskrit-pada-scipy.stats>
=== Binomial: #NormalTok("stats.binom");
<binomial-stats.binom>
#Skylighting(([#NormalTok("stats.binom.pmf(");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],));
Probabilitas kumulatif:

#Skylighting(([#NormalTok("stats.binom.cdf(");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],));
=== Poisson: #NormalTok("stats.poisson");
<poisson-stats.poisson>
#Skylighting(([#NormalTok("stats.poisson.pmf(");#DecValTok("4");#NormalTok(", mu");#OperatorTok("=");#FloatTok("2.5");#NormalTok(")");],));
#Skylighting(([#NormalTok("stats.poisson.cdf(");#DecValTok("4");#NormalTok(", mu");#OperatorTok("=");#FloatTok("2.5");#NormalTok(")");],));
=== Geometrik: #NormalTok("stats.geom");
<geometrik-stats.geom>
#Skylighting(([#NormalTok("stats.geom.pmf(");#DecValTok("4");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.2");#NormalTok(")");],));
== Statistik Ringkas untuk Data Diskrit
<statistik-ringkas-untuk-data-diskrit>
#Skylighting(([#NormalTok("sampel_dadu ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(", size");#OperatorTok("=");#DecValTok("100");#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean:\"");#NormalTok(", np.mean(sampel_dadu))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variansi:\"");#NormalTok(", np.var(sampel_dadu, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Simpangan baku:\"");#NormalTok(", np.std(sampel_dadu, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],));
== Tabel Frekuensi dengan #NormalTok("pandas");
<tabel-frekuensi-dengan-pandas>
#Skylighting(([#NormalTok("df_dadu ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"dadu\"");#NormalTok(": sampel_dadu})");],
[#NormalTok("df_dadu[");#StringTok("\"dadu\"");#NormalTok("].value_counts().sort_index()");],));
Tabel peluang empiris:

#Skylighting(([#NormalTok("df_dadu[");#StringTok("\"dadu\"");#NormalTok("].value_counts(normalize");#OperatorTok("=");#VariableTok("True");#NormalTok(").sort_index()");],));
== Visualisasi Diskrit
<visualisasi-diskrit>
#Skylighting(([#NormalTok("frekuensi ");#OperatorTok("=");#NormalTok(" df_dadu[");#StringTok("\"dadu\"");#NormalTok("].value_counts().sort_index()");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar(frekuensi.index, frekuensi.values)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai dadu\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Frekuensi\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Frekuensi Hasil Lemparan Dadu\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
= Random Variable Kontinu
<random-variable-kontinu>
== Pengertian
<pengertian-1>
Random variable kontinu dapat mengambil nilai pada suatu interval kontinu, misalnya tinggi badan, berat badan, lama pelayanan, atau waktu tunggu.

== Fungsi Dasar dari #NormalTok("numpy.random");
<fungsi-dasar-dari-numpy.random>
=== Uniform
<uniform>
=== #NormalTok("np.random.uniform(low, high, size)");
<np.random.uniformlow-high-size>
#Skylighting(([#NormalTok("np.random.uniform(low");#OperatorTok("=");#DecValTok("10");#NormalTok(", high");#OperatorTok("=");#DecValTok("20");#NormalTok(", size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],));
=== Normal
<normal>
=== #NormalTok("np.random.normal(loc, scale, size)");
<np.random.normalloc-scale-size>
#Skylighting(([#NormalTok("np.random.normal(loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
=== Eksponensial
<eksponensial>
=== #NormalTok("np.random.exponential(scale, size)");
<np.random.exponentialscale-size>
Perhatikan bahwa pada NumPy, parameter yang digunakan adalah #NormalTok("scale = 1/lambda");.

#Skylighting(([#NormalTok("np.random.exponential(scale");#OperatorTok("=");#FloatTok("2.0");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
=== Gamma
<gamma>
=== #NormalTok("np.random.gamma(shape, scale, size)");
<np.random.gammashape-scale-size>
#Skylighting(([#NormalTok("np.random.gamma(shape");#OperatorTok("=");#FloatTok("2.0");#NormalTok(", scale");#OperatorTok("=");#FloatTok("3.0");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
== Fungsi Distribusi Kontinu pada #NormalTok("scipy.stats");
<fungsi-distribusi-kontinu-pada-scipy.stats>
=== Normal: #NormalTok("stats.norm");
<normal-stats.norm>
Fungsi densitas probabilitas:

#Skylighting(([#NormalTok("stats.norm.pdf(");#DecValTok("175");#NormalTok(", loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],));
Fungsi distribusi kumulatif:

#Skylighting(([#NormalTok("stats.norm.cdf(");#DecValTok("175");#NormalTok(", loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],));
Kuantil atau inverse CDF:

#Skylighting(([#NormalTok("stats.norm.ppf(");#FloatTok("0.95");#NormalTok(", loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],));
=== Eksponensial: #NormalTok("stats.expon");
<eksponensial-stats.expon>
#Skylighting(([#NormalTok("stats.expon.pdf(");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#FloatTok("2.0");#NormalTok(")");],));
#Skylighting(([#NormalTok("stats.expon.cdf(");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#FloatTok("2.0");#NormalTok(")");],));
=== Uniform: #NormalTok("stats.uniform");
<uniform-stats.uniform>
#Skylighting(([#NormalTok("stats.uniform.pdf(");#DecValTok("7");#NormalTok(", loc");#OperatorTok("=");#DecValTok("5");#NormalTok(", scale");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
#Skylighting(([#NormalTok("stats.uniform.cdf(");#DecValTok("7");#NormalTok(", loc");#OperatorTok("=");#DecValTok("5");#NormalTok(", scale");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
== Statistik Ringkas untuk Data Kontinu
<statistik-ringkas-untuk-data-kontinu>
#Skylighting(([#NormalTok("tinggi ");#OperatorTok("=");#NormalTok(" np.random.normal(loc");#OperatorTok("=");#DecValTok("170");#NormalTok(", scale");#OperatorTok("=");#DecValTok("8");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean:\"");#NormalTok(", np.mean(tinggi))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variansi:\"");#NormalTok(", np.var(tinggi, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Simpangan baku:\"");#NormalTok(", np.std(tinggi, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Minimum:\"");#NormalTok(", np.");#BuiltInTok("min");#NormalTok("(tinggi))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Maksimum:\"");#NormalTok(", np.");#BuiltInTok("max");#NormalTok("(tinggi))");],));
== Ringkasan dengan #NormalTok("pandas");
<ringkasan-dengan-pandas>
#Skylighting(([#NormalTok("df_tinggi ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"tinggi\"");#NormalTok(": tinggi})");],
[#NormalTok("df_tinggi.describe()");],));
== Visualisasi Kontinu
<visualisasi-kontinu>
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(tinggi, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Tinggi\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Frekuensi\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram Data Tinggi\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
=== Membandingkan Histogram dengan Kurva Normal
<membandingkan-histogram-dengan-kurva-normal>
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#BuiltInTok("min");#NormalTok("(tinggi), ");#BuiltInTok("max");#NormalTok("(tinggi), ");#DecValTok("300");#NormalTok(")");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" stats.norm.pdf(x, loc");#OperatorTok("=");#NormalTok("np.mean(tinggi), scale");#OperatorTok("=");#NormalTok("np.std(tinggi, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(tinggi, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.7");#NormalTok(")");],
[#NormalTok("plt.plot(x, y)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Tinggi\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram dan Kurva Normal\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
= Random Variable Bivariat
<random-variable-bivariat>
== Pengertian
<pengertian-2>
Random variable bivariat melibatkan dua variabel acak yang diamati bersama, misalnya tinggi dan berat, permintaan dan biaya, atau storage dan compute dalam komputasi awan.

== Membuat Data Bivariat dengan Korelasi
<membuat-data-bivariat-dengan-korelasi>
=== #NormalTok("np.random.multivariate_normal(mean, cov, size)");
<np.random.multivariate_normalmean-cov-size>
Contoh dua variabel dengan korelasi positif.

#Skylighting(([#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("170");#NormalTok(", ");#DecValTok("65");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("8");#OperatorTok("**");#DecValTok("2");#NormalTok(", ");#FloatTok("0.7");#OperatorTok("*");#DecValTok("8");#OperatorTok("*");#DecValTok("10");#NormalTok("],");],
[#NormalTok("       [");#FloatTok("0.7");#OperatorTok("*");#DecValTok("8");#OperatorTok("*");#DecValTok("10");#NormalTok(", ");#DecValTok("10");#OperatorTok("**");#DecValTok("2");#NormalTok("]]");],
[],
[#NormalTok("bivariat ");#OperatorTok("=");#NormalTok(" np.random.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" bivariat[:, ");#DecValTok("0");#NormalTok("]");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" bivariat[:, ");#DecValTok("1");#NormalTok("]");],
[],
[#BuiltInTok("print");#NormalTok("(x[:");#DecValTok("5");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(y[:");#DecValTok("5");#NormalTok("])");],));
== Menyusun Data Bivariat dalam #NormalTok("pandas");
<menyusun-data-bivariat-dalam-pandas>
#Skylighting(([#NormalTok("df_biv ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");],
[#NormalTok("    ");#StringTok("\"tinggi\"");#NormalTok(": x,");],
[#NormalTok("    ");#StringTok("\"berat\"");#NormalTok(": y");],
[#NormalTok("})");],
[],
[#NormalTok("df_biv.head()");],));
== Statistik Bivariat
<statistik-bivariat>
=== Mean masing-masing variabel
<mean-masing-masing-variabel>
#Skylighting(([#NormalTok("df_biv.mean()");],));
=== Variansi dan kovariansi
<variansi-dan-kovariansi>
#Skylighting(([#NormalTok("df_biv.cov()");],));
=== Korelasi
<korelasi>
#Skylighting(([#NormalTok("df_biv.corr()");],));
Dengan NumPy:

#Skylighting(([#NormalTok("np.cov(x, y)");],));
#Skylighting(([#NormalTok("np.corrcoef(x, y)");],));
== Scatter Plot
<scatter-plot>
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.scatter(x, y, alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Tinggi\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Berat\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scatter Plot Tinggi vs Berat\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
== Regresi Linear Sederhana
<regresi-linear-sederhana>
=== #NormalTok("stats.linregress(x, y)");
<stats.linregressx-y>
#Skylighting(([#NormalTok("hasil_regresi ");#OperatorTok("=");#NormalTok(" stats.linregress(x, y)");],
[#NormalTok("hasil_regresi");],));
Mengambil slope dan intercept:

#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Slope:\"");#NormalTok(", hasil_regresi.slope)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Intercept:\"");#NormalTok(", hasil_regresi.intercept)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"R-value:\"");#NormalTok(", hasil_regresi.rvalue)");],));
Visualisasi garis regresi:

#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.scatter(x, y, alpha");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],
[#NormalTok("plt.plot(x, hasil_regresi.intercept ");#OperatorTok("+");#NormalTok(" hasil_regresi.slope ");#OperatorTok("*");#NormalTok(" x)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Tinggi\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Berat\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scatter Plot dan Garis Regresi\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
= Joint Distribution Empiris dengan #NormalTok("pandas");
<joint-distribution-empiris-dengan-pandas>
== Untuk Variabel Diskrit Bivariat
<untuk-variabel-diskrit-bivariat>
Misalnya kita punya dua dadu.

#Skylighting(([#NormalTok("dadu1 ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("dadu2 ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[],
[#NormalTok("df_dua_dadu ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"dadu1\"");#NormalTok(": dadu1, ");#StringTok("\"dadu2\"");#NormalTok(": dadu2})");],));
=== Tabel frekuensi gabungan
<tabel-frekuensi-gabungan>
#Skylighting(([#NormalTok("pd.crosstab(df_dua_dadu[");#StringTok("\"dadu1\"");#NormalTok("], df_dua_dadu[");#StringTok("\"dadu2\"");#NormalTok("])");],));
=== Tabel peluang gabungan
<tabel-peluang-gabungan>
#Skylighting(([#NormalTok("pd.crosstab(df_dua_dadu[");#StringTok("\"dadu1\"");#NormalTok("], df_dua_dadu[");#StringTok("\"dadu2\"");#NormalTok("], normalize");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
=== Peluang marginal
<peluang-marginal>
#Skylighting(([#NormalTok("pd.crosstab(df_dua_dadu[");#StringTok("\"dadu1\"");#NormalTok("], columns");#OperatorTok("=");#StringTok("\"prob\"");#NormalTok(", normalize");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
#Skylighting(([#NormalTok("pd.crosstab(columns");#OperatorTok("=");#NormalTok("df_dua_dadu[");#StringTok("\"dadu2\"");#NormalTok("], index");#OperatorTok("=");#StringTok("\"prob\"");#NormalTok(", normalize");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
= Contoh Simulasi Terpadu
<contoh-simulasi-terpadu>
== Kasus Diskrit: Jumlah keberhasilan
<kasus-diskrit-jumlah-keberhasilan>
#Skylighting(([#NormalTok("keberhasilan ");#OperatorTok("=");#NormalTok(" np.random.binomial(n");#OperatorTok("=");#DecValTok("20");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata empiris:\"");#NormalTok(", np.mean(keberhasilan))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata teoritis:\"");#NormalTok(", ");#DecValTok("20");#NormalTok(" ");#OperatorTok("*");#NormalTok(" ");#FloatTok("0.3");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variansi empiris:\"");#NormalTok(", np.var(keberhasilan, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variansi teoritis:\"");#NormalTok(", ");#DecValTok("20");#NormalTok(" ");#OperatorTok("*");#NormalTok(" ");#FloatTok("0.3");#NormalTok(" ");#OperatorTok("*");#NormalTok(" ");#FloatTok("0.7");#NormalTok(")");],));
== Kasus Kontinu: Waktu tunggu eksponensial
<kasus-kontinu-waktu-tunggu-eksponensial>
#Skylighting(([#NormalTok("waktu_tunggu ");#OperatorTok("=");#NormalTok(" np.random.exponential(scale");#OperatorTok("=");#DecValTok("5");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata empiris:\"");#NormalTok(", np.mean(waktu_tunggu))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata teoritis:\"");#NormalTok(", ");#DecValTok("5");#NormalTok(")");],));
== Kasus Bivariat: Tinggi dan berat
<kasus-bivariat-tinggi-dan-berat>
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Kovariansi:");#CharTok("\\n");#StringTok("\"");#NormalTok(", df_biv.cov())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Korelasi:");#CharTok("\\n");#StringTok("\"");#NormalTok(", df_biv.corr())");],));
= Ringkasan Fungsi Penting
<ringkasan-fungsi-penting>
== Diskrit
<diskrit>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Fungsi], [Kegunaan], [Contoh],),
  table.hline(),
  [#NormalTok("random.randint(a,b)");], [Bilangan bulat acak], [#NormalTok("random.randint(1,6)");],
  [#NormalTok("random.choice(seq)");], [Memilih satu elemen acak], [#NormalTok("random.choice([0,1])");],
  [#NormalTok("np.random.binomial(n,p,size)");], [Sampel binomial/Bernoulli], [#NormalTok("np.random.binomial(1,0.3,10)");],
  [#NormalTok("np.random.poisson(lam,size)");], [Sampel Poisson], [#NormalTok("np.random.poisson(2.5,10)");],
  [#NormalTok("np.random.geometric(p,size)");], [Sampel geometrik], [#NormalTok("np.random.geometric(0.2,10)");],
  [#NormalTok("stats.binom.pmf(...)");], [Probabilitas titik binomial], [#NormalTok("stats.binom.pmf(3,10,0.4)");],
  [#NormalTok("stats.poisson.pmf(...)");], [Probabilitas titik Poisson], [#NormalTok("stats.poisson.pmf(4,2.5)");],
)
== Kontinu
<kontinu>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Fungsi], [Kegunaan], [Contoh],),
  table.hline(),
  [#NormalTok("np.random.uniform(low,high,size)");], [Sampel uniform], [#NormalTok("np.random.uniform(0,1,10)");],
  [#NormalTok("np.random.normal(loc,scale,size)");], [Sampel normal], [#NormalTok("np.random.normal(170,8,10)");],
  [#NormalTok("np.random.exponential(scale,size)");], [Sampel eksponensial], [#NormalTok("np.random.exponential(2,10)");],
  [#NormalTok("stats.norm.pdf(...)");], [Densitas normal], [#NormalTok("stats.norm.pdf(175,170,8)");],
  [#NormalTok("stats.norm.cdf(...)");], [CDF normal], [#NormalTok("stats.norm.cdf(175,170,8)");],
  [#NormalTok("stats.norm.ppf(...)");], [Kuantil normal], [#NormalTok("stats.norm.ppf(0.95,170,8)");],
)
== Bivariat
<bivariat>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Fungsi], [Kegunaan], [Contoh],),
  table.hline(),
  [#NormalTok("np.random.multivariate_normal(...)");], [Sampel normal bivariat], [#NormalTok("np.random.multivariate_normal(mean,cov,1000)");],
  [#NormalTok("df.cov()");], [Matriks kovariansi], [#NormalTok("df_biv.cov()");],
  [#NormalTok("df.corr()");], [Matriks korelasi], [#NormalTok("df_biv.corr()");],
  [#NormalTok("np.cov(x,y)");], [Kovariansi], [#NormalTok("np.cov(x,y)");],
  [#NormalTok("np.corrcoef(x,y)");], [Korelasi], [#NormalTok("np.corrcoef(x,y)");],
  [#NormalTok("stats.linregress(x,y)");], [Regresi linear sederhana], [#NormalTok("stats.linregress(x,y)");],
  [#NormalTok("pd.crosstab(...)");], [Joint distribution empiris diskrit], [#NormalTok("pd.crosstab(df[\"x\"], df[\"y\"])");],
)
= Latihan Mahasiswa
<latihan-mahasiswa>
== Latihan 1: Diskrit
<latihan-1-diskrit>
Simulasikan 500 kali lemparan dadu. Hitung:

+ Rata-rata empiris.
+ Variansi empiris.
+ Frekuensi masing-masing angka 1 sampai 6.
+ Buat diagram batang frekuensinya.

== Latihan 2: Kontinu
<latihan-2-kontinu>
Bangkitkan 1000 sampel dari distribusi normal dengan mean 70 dan simpangan baku 12. Hitung:

+ Mean empiris.
+ Variansi empiris.
+ Histogram data.
+ Bandingkan histogram dengan kurva normal teoritis.

== Latihan 3: Bivariat
<latihan-3-bivariat>
Bangkitkan 2000 sampel bivariat normal dengan korelasi 0.6. Lalu:

+ Hitung mean masing-masing variabel.
+ Hitung kovariansi dan korelasi.
+ Buat scatter plot.
+ Estimasikan garis regresi linear.

== Latihan 4: Joint Distribution Diskrit
<latihan-4-joint-distribution-diskrit>
Simulasikan dua dadu yang dilempar bersama-sama sebanyak 1000 kali. Gunakan #NormalTok("pd.crosstab()"); untuk:

+ Membuat tabel frekuensi gabungan.
+ Membuat tabel peluang gabungan.
+ Menghitung peluang marginal.
+ Mengidentifikasi pasangan hasil yang paling sering muncul.

= Penutup
<penutup>
Python menyediakan ekosistem yang sangat kaya untuk mempelajari random variable dalam bentuk diskrit, kontinu, maupun bivariat. #NormalTok("numpy"); sangat kuat untuk simulasi, #NormalTok("scipy.stats"); sangat berguna untuk distribusi teoritis, #NormalTok("pandas"); membantu tabulasi dan analisis data, sedangkan #NormalTok("matplotlib"); memudahkan visualisasi.

Dokumen ini dapat dikembangkan lebih lanjut menjadi notebook praktikum, modul pembelajaran, atau bahan tugas mahasiswa.
