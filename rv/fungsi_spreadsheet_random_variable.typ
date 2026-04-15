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
  title: [Fungsi Spreadsheet untuk Random Variable Diskrit, Kontinu, dan Bivariat],
  authors: (
    ( name: [Armein Z. R. Langi],
      affiliation: [],
      email: [] ),
    ),
  lang: "id",
  toc_title: [Daftar Isi],
  toc_depth: 3,
  doc,
)

= Pendahuluan
<pendahuluan>
Dokumen ini merangkum fungsi-fungsi spreadsheet yang berguna untuk mempelajari #strong[random variable diskrit], #strong[random variable kontinu], dan #strong[random variable bivariat]. Contoh-contoh ditulis dalam format yang umum dipakai di #strong[Microsoft Excel] dan sebagian besar juga dapat digunakan di #strong[Google Sheets].

Tujuan dokumen ini adalah membantu pembaca:

+ mengenali fungsi-fungsi penting untuk simulasi dan analisis probabilistik,
+ memahami cara memakai rumus-rumus spreadsheet secara langsung,
+ menghubungkan konsep peluang, ekspektasi, variansi, kovariansi, dan korelasi dengan praktik komputasi sederhana.

= Random Variable Diskrit
<random-variable-diskrit>
Random variable diskrit adalah peubah acak yang nilainya dapat dihitung satu per satu, misalnya banyaknya pelanggan datang, jumlah keberhasilan, atau hasil lemparan dadu.

== Membuat Nilai Acak Diskrit
<membuat-nilai-acak-diskrit>
=== Fungsi #NormalTok("RANDBETWEEN");
<fungsi-randbetween>
Fungsi ini menghasilkan bilangan bulat acak antara batas bawah dan batas atas.

#Skylighting(([#NormalTok("=RANDBETWEEN(1,6)");],));
Contoh ini dapat dipakai untuk mensimulasikan satu kali lemparan dadu.

== Distribusi Bernoulli
<distribusi-bernoulli>
Distribusi Bernoulli memiliki dua hasil: sukses (#NormalTok("1");) atau gagal (#NormalTok("0");).

=== Simulasi Bernoulli dengan #NormalTok("IF"); dan #NormalTok("RAND");
<simulasi-bernoulli-dengan-if-dan-rand>
Misalkan peluang sukses adalah #NormalTok("0.3");.

#Skylighting(([#NormalTok("=IF(RAND()<0.3,1,0)");],));
Rumus ini menghasilkan:

- #NormalTok("1"); dengan peluang 0,3
- #NormalTok("0"); dengan peluang 0,7

== Distribusi Binomial
<distribusi-binomial>
Distribusi binomial memodelkan banyaknya sukses dari #NormalTok("n"); percobaan independen.

=== Fungsi #NormalTok("BINOM.DIST");
<fungsi-binom.dist>
Bentuk umum:

#Skylighting(([#NormalTok("=BINOM.DIST(x,n,p,kumulatif)");],));
Keterangan:

- #NormalTok("x");: jumlah sukses
- #NormalTok("n");: jumlah percobaan
- #NormalTok("p");: peluang sukses tiap percobaan
- #NormalTok("FALSE");: peluang tepat
- #NormalTok("TRUE");: peluang kumulatif

=== Contoh peluang tepat
<contoh-peluang-tepat>
Peluang tepat 3 sukses dari 10 percobaan, dengan peluang sukses 0,4:

#Skylighting(([#NormalTok("=BINOM.DIST(3,10,0.4,FALSE)");],));
=== Contoh peluang kumulatif
<contoh-peluang-kumulatif>
Peluang paling banyak 3 sukses:

#Skylighting(([#NormalTok("=BINOM.DIST(3,10,0.4,TRUE)");],));
== Distribusi Poisson
<distribusi-poisson>
Distribusi Poisson sering dipakai untuk memodelkan banyak kejadian dalam suatu interval waktu atau ruang.

=== Fungsi #NormalTok("POISSON.DIST");
<fungsi-poisson.dist>
#Skylighting(([#NormalTok("=POISSON.DIST(x,lambda,kumulatif)");],));
=== Contoh peluang tepat
<contoh-peluang-tepat-1>
Peluang tepat 4 kejadian saat rata-rata kejadian #NormalTok("2.5");:

#Skylighting(([#NormalTok("=POISSON.DIST(4,2.5,FALSE)");],));
=== Contoh peluang kumulatif
<contoh-peluang-kumulatif-1>
Peluang paling banyak 4 kejadian:

#Skylighting(([#NormalTok("=POISSON.DIST(4,2.5,TRUE)");],));
== Distribusi Geometrik
<distribusi-geometrik>
Distribusi geometrik memodelkan kapan sukses pertama terjadi.

=== Fungsi #NormalTok("GEOM.DIST");
<fungsi-geom.dist>
#Skylighting(([#NormalTok("=GEOM.DIST(x,p,kumulatif)");],));
Contoh peluang sukses pertama terjadi pada percobaan ke-4 dengan peluang sukses 0,2:

#Skylighting(([#NormalTok("=GEOM.DIST(4,0.2,FALSE)");],));
== Ekspektasi Random Variable Diskrit
<ekspektasi-random-variable-diskrit>
Jika nilai-nilai acak berada pada rentang #NormalTok("A2:A6"); dan peluangnya pada #NormalTok("B2:B6");, maka nilai harapan dapat dihitung dengan #NormalTok("SUMPRODUCT");.

=== Fungsi #NormalTok("SUMPRODUCT");
<fungsi-sumproduct>
#Skylighting(([#NormalTok("=SUMPRODUCT(A2:A6,B2:B6)");],));
Contoh tabel:

#table(
  columns: 2,
  align: (right,right,),
  table.header([Nilai (x)], [Peluang (P(X=x))],),
  table.hline(),
  [0], [0.1],
  [1], [0.2],
  [2], [0.4],
  [3], [0.2],
  [4], [0.1],
)
Rumus ekspektasi:

#Skylighting(([#NormalTok("=SUMPRODUCT(A2:A6,B2:B6)");],));
== Variansi Random Variable Diskrit
<variansi-random-variable-diskrit>
Gunakan rumus:

$ V a r \( X \) = E \[ X^2 \] - \( E \[ X \] \)^2 $

Jika nilai (x) di #NormalTok("A2:A6"); dan peluang di #NormalTok("B2:B6");, salah satu cara adalah langsung memakai:

#Skylighting(([#NormalTok("=SUMPRODUCT((A2:A6^2),B2:B6)-(SUMPRODUCT(A2:A6,B2:B6))^2");],));
Dalam praktik spreadsheet, sering lebih aman memakai #strong[kolom bantu].

Misalkan di #NormalTok("C2"); tulis:

#Skylighting(([#NormalTok("=A2^2");],));
lalu salin ke bawah, dan hitung variansi dengan:

#Skylighting(([#NormalTok("=SUMPRODUCT(C2:C6,B2:B6)-(SUMPRODUCT(A2:A6,B2:B6))^2");],));
= Random Variable Kontinu
<random-variable-kontinu>
Random variable kontinu mengambil nilai pada suatu interval, misalnya tinggi badan, berat badan, waktu tunggu, dan temperatur.

== Membuat Nilai Acak Uniform
<membuat-nilai-acak-uniform>
=== Fungsi #NormalTok("RAND");
<fungsi-rand>
Fungsi ini menghasilkan angka acak antara 0 dan 1.

#Skylighting(([#NormalTok("=RAND()");],));
=== Uniform pada interval tertentu
<uniform-pada-interval-tertentu>
Untuk menghasilkan data acak uniform pada interval (\[a,b\]):

#Skylighting(([#NormalTok("=a + (b-a)*RAND()");],));
Contoh interval 10 sampai 20:

#Skylighting(([#NormalTok("=10 + (20-10)*RAND()");],));
== Distribusi Normal
<distribusi-normal>
Distribusi normal sangat penting dalam statistika karena banyak fenomena alam dan sosial mendekatinya.

=== Fungsi #NormalTok("NORM.DIST");
<fungsi-norm.dist>
#Skylighting(([#NormalTok("=NORM.DIST(x,mean,std_dev,kumulatif)");],));
=== Contoh densitas
<contoh-densitas>
Nilai densitas pada #NormalTok("x = 70");, mean #NormalTok("65");, standar deviasi #NormalTok("8");:

#Skylighting(([#NormalTok("=NORM.DIST(70,65,8,FALSE)");],));
=== Contoh peluang kumulatif
<contoh-peluang-kumulatif-2>
Peluang (X ):

#Skylighting(([#NormalTok("=NORM.DIST(70,65,8,TRUE)");],));
== Membuat Sampel Acak Normal
<membuat-sampel-acak-normal>
=== Fungsi #NormalTok("NORM.INV");
<fungsi-norm.inv>
Salah satu cara menghasilkan data normal acak adalah dengan mengubah uniform acak menjadi normal menggunakan inverse CDF.

#Skylighting(([#NormalTok("=NORM.INV(RAND(),65,8)");],));
Rumus ini menghasilkan satu sampel acak dari distribusi normal dengan mean #NormalTok("65"); dan simpangan baku #NormalTok("8");.

== Distribusi Eksponensial
<distribusi-eksponensial>
Distribusi eksponensial sering digunakan untuk memodelkan waktu antar-kejadian.

=== Fungsi #NormalTok("EXPON.DIST");
<fungsi-expon.dist>
#Skylighting(([#NormalTok("=EXPON.DIST(x,lambda,kumulatif)");],));
=== Contoh densitas
<contoh-densitas-1>
Nilai densitas pada #NormalTok("x = 2"); dengan laju #NormalTok("0.5");:

#Skylighting(([#NormalTok("=EXPON.DIST(2,0.5,FALSE)");],));
=== Contoh peluang kumulatif
<contoh-peluang-kumulatif-3>
Peluang (X ):

#Skylighting(([#NormalTok("=EXPON.DIST(2,0.5,TRUE)");],));
== Membuat Sampel Acak Eksponensial
<membuat-sampel-acak-eksponensial>
Dengan transformasi invers, distribusi eksponensial dapat disimulasikan melalui:

#Skylighting(([#NormalTok("=-LN(1-RAND())/0.5");],));
Rumus ini menghasilkan sampel acak eksponensial dengan parameter laju #NormalTok("0.5");.

== Rata-rata dan Variabilitas Data Kontinu
<rata-rata-dan-variabilitas-data-kontinu>
Misalkan data berada pada rentang #NormalTok("A2:A101");.

=== Mean
<mean>
#Skylighting(([#NormalTok("=AVERAGE(A2:A101)");],));
=== Variansi sampel
<variansi-sampel>
#Skylighting(([#NormalTok("=VAR.S(A2:A101)");],));
=== Variansi populasi
<variansi-populasi>
#Skylighting(([#NormalTok("=VAR.P(A2:A101)");],));
=== Simpangan baku sampel
<simpangan-baku-sampel>
#Skylighting(([#NormalTok("=STDEV.S(A2:A101)");],));
=== Simpangan baku populasi
<simpangan-baku-populasi>
#Skylighting(([#NormalTok("=STDEV.P(A2:A101)");],));
= Random Variable Bivariat
<random-variable-bivariat>
Random variable bivariat melibatkan dua peubah acak yang diamati bersama-sama, misalnya tinggi dan berat, nilai UTS dan UAS, atau permintaan dan biaya.

Misalkan:

- data (X) berada di kolom #NormalTok("A");
- data (Y) berada di kolom #NormalTok("B");

== Mean Masing-masing Variabel
<mean-masing-masing-variabel>
Untuk (X):

#Skylighting(([#NormalTok("=AVERAGE(A2:A101)");],));
Untuk (Y):

#Skylighting(([#NormalTok("=AVERAGE(B2:B101)");],));
== Variansi Masing-masing Variabel
<variansi-masing-masing-variabel>
Untuk (X):

#Skylighting(([#NormalTok("=VAR.S(A2:A101)");],));
Untuk (Y):

#Skylighting(([#NormalTok("=VAR.S(B2:B101)");],));
== Kovariansi
<kovariansi>
Kovariansi mengukur kecenderungan dua variabel berubah bersama.

=== Fungsi #NormalTok("COVARIANCE.S"); dan #NormalTok("COVARIANCE.P");
<fungsi-covariance.s-dan-covariance.p>
Untuk sampel:

#Skylighting(([#NormalTok("=COVARIANCE.S(A2:A101,B2:B101)");],));
Untuk populasi:

#Skylighting(([#NormalTok("=COVARIANCE.P(A2:A101,B2:B101)");],));
Interpretasi umum:

- bernilai positif: jika #NormalTok("X"); naik, #NormalTok("Y"); cenderung naik,
- bernilai negatif: jika #NormalTok("X"); naik, #NormalTok("Y"); cenderung turun,
- mendekati nol: hubungan linear lemah.

== Korelasi
<korelasi>
Korelasi menormalkan kovariansi sehingga nilainya berada pada interval (\[-1,1\]).

=== Fungsi #NormalTok("CORREL");
<fungsi-correl>
#Skylighting(([#NormalTok("=CORREL(A2:A101,B2:B101)");],));
Interpretasi umum:

- mendekati #NormalTok("1");: hubungan linear positif kuat,
- mendekati #NormalTok("-1");: hubungan linear negatif kuat,
- mendekati #NormalTok("0");: hubungan linear lemah.

== Regresi Linear Sederhana
<regresi-linear-sederhana>
Jika ingin memodelkan hubungan linear (Y) terhadap (X), spreadsheet menyediakan fungsi berikut.

=== Kemiringan garis regresi: #NormalTok("SLOPE");
<kemiringan-garis-regresi-slope>
#Skylighting(([#NormalTok("=SLOPE(B2:B101,A2:A101)");],));
=== Intersep garis regresi: #NormalTok("INTERCEPT");
<intersep-garis-regresi-intercept>
#Skylighting(([#NormalTok("=INTERCEPT(B2:B101,A2:A101)");],));
=== Prediksi nilai #NormalTok("Y");
<prediksi-nilai-y>
Jika nilai #NormalTok("X"); tertentu berada di sel #NormalTok("A2");, maka prediksi (Y) adalah:

#Skylighting(([#NormalTok("=INTERCEPT(B2:B101,A2:A101) + SLOPE(B2:B101,A2:A101)*A2");],));
== Joint Distribution Diskrit Bivariat
<joint-distribution-diskrit-bivariat>
Jika dua variabel diskrit diamati bersama, peluang gabungannya dapat dihitung dengan #NormalTok("COUNTIFS");.

Misalkan:

- data #NormalTok("X"); pada #NormalTok("A2:A101");
- data #NormalTok("Y"); pada #NormalTok("B2:B101");

=== Peluang bersama
<peluang-bersama>
Contoh menghitung (P(X=1, Y=2)):

#Skylighting(([#NormalTok("=COUNTIFS(A2:A101,1,B2:B101,2)/COUNT(A2:A101)");],));
=== Peluang marginal
<peluang-marginal>
Contoh menghitung (P(X=1)):

#Skylighting(([#NormalTok("=COUNTIF(A2:A101,1)/COUNT(A2:A101)");],));
=== Peluang kondisional
<peluang-kondisional>
Contoh menghitung (P(Y=2 X=1)):

#Skylighting(([#NormalTok("=COUNTIFS(A2:A101,1,B2:B101,2)/COUNTIF(A2:A101,1)");],));
== Expected Value pada Joint Distribution
<expected-value-pada-joint-distribution>
Misalkan tabel peluang gabungan disusun sebagai berikut:

- nilai #NormalTok("X"); di #NormalTok("B1:E1");
- nilai #NormalTok("Y"); di #NormalTok("A2:A5");
- probabilitas gabungan di #NormalTok("B2:E5");

Dalam praktik, perhitungan ekspektasi gabungan sering memerlukan tabel bantu.

=== Menghitung (E\[X\])
<menghitung-ex>
Secara konseptual, kita jumlahkan semua nilai #NormalTok("X"); dikalikan probabilitas marginalnya. Jika struktur tabel sudah sesuai, #NormalTok("SUMPRODUCT"); dapat digunakan.

=== Menghitung (E\[XY\])
<menghitung-exy>
Buat matriks hasil kali #NormalTok("x*y");, lalu kalikan dengan matriks probabilitas bersama:

#Skylighting(([#NormalTok("=SUMPRODUCT(matriks_XY, matriks_probabilitas)");],));
= Fungsi Penting Lain yang Sering Dipakai
<fungsi-penting-lain-yang-sering-dipakai>
== Frekuensi dan Histogram
<frekuensi-dan-histogram>
=== Fungsi #NormalTok("FREQUENCY");
<fungsi-frequency>
#Skylighting(([#NormalTok("=FREQUENCY(A2:A101,D2:D6)");],));
Fungsi ini berguna untuk membuat distribusi frekuensi empiris atau histogram.

== Persentil dan Kuartil
<persentil-dan-kuartil>
=== Persentil
<persentil>
#Skylighting(([#NormalTok("=PERCENTILE.INC(A2:A101,0.25)");],));
=== Median
<median>
#Skylighting(([#NormalTok("=MEDIAN(A2:A101)");],));
=== Kuartil
<kuartil>
#Skylighting(([#NormalTok("=QUARTILE.INC(A2:A101,3)");],));
== Nilai Minimum dan Maksimum
<nilai-minimum-dan-maksimum>
#Skylighting(([#NormalTok("=MIN(A2:A101)");],));
#Skylighting(([#NormalTok("=MAX(A2:A101)");],));
== Menghitung Peluang Empiris
<menghitung-peluang-empiris>
Jika nilai tertentu ditulis di #NormalTok("D2");, maka jumlah kemunculannya dapat dihitung dengan:

#Skylighting(([#NormalTok("=COUNTIF(A2:A101,D2)");],));
Peluang empirisnya:

#Skylighting(([#NormalTok("=COUNTIF(A2:A101,D2)/COUNT(A2:A101)");],));
= Contoh Penggunaan Ringkas
<contoh-penggunaan-ringkas>
== Contoh 1: Lempar Dadu 100 Kali
<contoh-1-lempar-dadu-100-kali>
Pada sel #NormalTok("A2");, tulis:

#Skylighting(([#NormalTok("=RANDBETWEEN(1,6)");],));
Salin hingga #NormalTok("A101");.

=== Rata-rata hasil lemparan
<rata-rata-hasil-lemparan>
#Skylighting(([#NormalTok("=AVERAGE(A2:A101)");],));
=== Variansi hasil lemparan
<variansi-hasil-lemparan>
#Skylighting(([#NormalTok("=VAR.S(A2:A101)");],));
=== Peluang empiris muncul angka 4
<peluang-empiris-muncul-angka-4>
#Skylighting(([#NormalTok("=COUNTIF(A2:A101,4)/COUNT(A2:A101)");],));
== Contoh 2: Tinggi Badan Berdistribusi Normal
<contoh-2-tinggi-badan-berdistribusi-normal>
Pada sel #NormalTok("A2");, tulis:

#Skylighting(([#NormalTok("=NORM.INV(RAND(),170,8)");],));
Salin ke bawah.

=== Mean sampel
<mean-sampel>
#Skylighting(([#NormalTok("=AVERAGE(A2:A101)");],));
=== Simpangan baku sampel
<simpangan-baku-sampel-1>
#Skylighting(([#NormalTok("=STDEV.S(A2:A101)");],));
=== Peluang teoritis tinggi ()
<peluang-teoritis-tinggi>
#Skylighting(([#NormalTok("=NORM.DIST(175,170,8,TRUE)");],));
== Contoh 3: Tinggi dan Berat sebagai Data Bivariat
<contoh-3-tinggi-dan-berat-sebagai-data-bivariat>
Misalkan:

- tinggi di #NormalTok("A2:A101");
- berat di #NormalTok("B2:B101");

=== Kovariansi
<kovariansi-1>
#Skylighting(([#NormalTok("=COVARIANCE.S(A2:A101,B2:B101)");],));
=== Korelasi
<korelasi-1>
#Skylighting(([#NormalTok("=CORREL(A2:A101,B2:B101)");],));
=== Slope regresi berat terhadap tinggi
<slope-regresi-berat-terhadap-tinggi>
#Skylighting(([#NormalTok("=SLOPE(B2:B101,A2:A101)");],));
= Tabel Ringkasan Fungsi Utama
<tabel-ringkasan-fungsi-utama>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Topik], [Fungsi Spreadsheet], [Kegunaan Utama],),
  table.hline(),
  [Acak diskrit], [#NormalTok("RANDBETWEEN");, #NormalTok("RAND");, #NormalTok("IF");], [Simulasi nilai acak sederhana],
  [Bernoulli/Binomial], [#NormalTok("BINOM.DIST");], [Peluang banyak sukses],
  [Poisson], [#NormalTok("POISSON.DIST");], [Peluang jumlah kejadian],
  [Geometrik], [#NormalTok("GEOM.DIST");], [Peluang sukses pertama],
  [Normal], [#NormalTok("NORM.DIST");, #NormalTok("NORM.INV");], [Distribusi normal dan simulasi],
  [Eksponensial], [#NormalTok("EXPON.DIST");], [Distribusi waktu tunggu],
  [Mean], [#NormalTok("AVERAGE");], [Nilai rata-rata],
  [Variansi], [#NormalTok("VAR.S");, #NormalTok("VAR.P");], [Ukuran penyebaran],
  [Simpangan baku], [#NormalTok("STDEV.S");, #NormalTok("STDEV.P");], [Akar dari variansi],
  [Kovariansi], [#NormalTok("COVARIANCE.S");, #NormalTok("COVARIANCE.P");], [Hubungan perubahan bersama],
  [Korelasi], [#NormalTok("CORREL");], [Kekuatan hubungan linear],
  [Regresi], [#NormalTok("SLOPE");, #NormalTok("INTERCEPT");], [Model linear sederhana],
  [Frekuensi], [#NormalTok("COUNTIF");, #NormalTok("COUNTIFS");, #NormalTok("FREQUENCY");], [Distribusi empiris],
  [Ekspektasi diskrit], [#NormalTok("SUMPRODUCT");], [Nilai harapan],
)
= Penutup
<penutup>
Spreadsheet menyediakan banyak fungsi yang cukup kuat untuk mendukung pembelajaran probabilitas dan statistika tanpa harus langsung memakai bahasa pemrograman. Dengan fungsi-fungsi seperti #NormalTok("RANDBETWEEN");, #NormalTok("NORM.INV");, #NormalTok("SUMPRODUCT");, #NormalTok("COVARIANCE.S");, dan #NormalTok("CORREL");, pembaca dapat melakukan simulasi, menghitung ukuran-ukuran statistik, serta mempelajari hubungan antar-variabel secara langsung.

Dokumen ini dapat dijadikan sebagai:

- catatan ringkas saat belajar,
- bahan ajar di kelas,
- panduan praktikum spreadsheet,
- dasar untuk membuat tugas eksplorasi random variable.
