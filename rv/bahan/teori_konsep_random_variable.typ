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
  title: [Konsep dan Teori],
  subtitle: [Random Variable],
  authors: (
    ( name: [Armein Z. R. Langi],
      affiliation: [],
      email: [] ),
    ),
  date: [2024-01-07],
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= Pendahuluan
<pendahuluan>
Dalam banyak persoalan nyata, kita berhadapan dengan #strong[ketidakpastian]. Hasil suatu pengamatan, eksperimen, atau proses tidak selalu dapat diketahui secara pasti sebelum kejadian itu berlangsung. Untuk memodelkan ketidakpastian ini, statistika dan teori probabilitas menggunakan konsep #strong[random variable] atau #strong[variabel acak].

Secara intuitif, variabel acak adalah suatu aturan yang mengubah hasil percobaan acak menjadi sebuah nilai numerik. Dengan demikian, kejadian yang semula bersifat kualitatif atau berbentuk hasil eksperimen dapat dianalisis secara matematis. Konsep ini sangat penting karena menjadi dasar bagi distribusi probabilitas, ekspektasi, variansi, inferensi statistik, simulasi, machine learning, dan banyak bidang rekayasa lainnya.

Dokumen ini membahas tiga konsep utama:

+ #strong[Random variable diskrit]
+ #strong[Random variable kontinu]
+ #strong[Random variable bivariate]

Setiap bagian menjelaskan definisi, sifat, fungsi distribusi, ukuran-ukuran penting, serta contoh interpretasi.

= Random Variable
<random-variable>
== Definisi
<definisi>
Misalkan suatu percobaan acak memiliki ruang sampel $S$. Sebuah #strong[random variable] adalah fungsi

$ X : S arrow.r bb(R) $

yang memetakan setiap hasil pada ruang sampel ke suatu bilangan real.

Artinya, jika hasil eksperimen adalah suatu elemen $omega in S$, maka variabel acak $X$ memberikan nilai numerik $X \( omega \)$.

== Contoh intuitif
<contoh-intuitif>
- Pada pelemparan dadu, hasil eksperimen adalah salah satu dari ${ 1 \, 2 \, 3 \, 4 \, 5 \, 6 }$. Kita dapat mendefinisikan random variable $X$ sebagai nilai mata dadu yang muncul.
- Pada pengukuran tinggi badan mahasiswa, random variable $X$ adalah tinggi badan setiap mahasiswa yang terpilih secara acak.
- Pada pengamatan jumlah pelanggan yang datang per jam, random variable $X$ menyatakan jumlah pelanggan yang datang dalam satu interval waktu.

== Notasi penting
<notasi-penting>
Biasanya digunakan notasi:

- Huruf kapital seperti $X$, $Y$, $Z$ untuk random variable
- Huruf kecil seperti $x$, $y$, $z$ untuk nilai tertentu yang mungkin diambil oleh random variable

Contoh:

- $P \( X = 3 \)$ berarti peluang bahwa random variable $X$ bernilai 3
- $P \( X lt.eq 5 \)$ berarti peluang bahwa $X$ tidak lebih dari 5

= Random Variable Diskrit
<random-variable-diskrit>
== Definisi
<definisi-1>
Random variable #strong[diskrit] adalah variabel acak yang hanya dapat mengambil nilai-nilai yang dapat dihitung satu per satu.

Nilai-nilai ini bisa:

- berhingga, misalnya ${ 0 \, 1 \, 2 \, 3 }$
- tak berhingga tetapi terhitung, misalnya ${ 0 \, 1 \, 2 \, 3 \, dots.h }$

== Contoh random variable diskrit
<contoh-random-variable-diskrit>
- Jumlah anak dalam keluarga
- Banyaknya pelanggan yang datang dalam satu jam
- Jumlah barang rusak dalam satu batch produksi
- Banyaknya keberhasilan dari $n$ percobaan
- Hasil lemparan dadu

== Probability Mass Function (PMF)
<probability-mass-function-pmf>
Untuk random variable diskrit, distribusi peluang dinyatakan dengan #strong[probability mass function]:

$ p_X \( x \) = P \( X = x \) $

PMF harus memenuhi dua syarat:

$ p_X \( x \) gt.eq 0 $

dan

$ sum_x p_X \( x \) = 1 $

== Contoh PMF
<contoh-pmf>
Misalkan $X$ adalah hasil lemparan dadu fair. Maka:

$ P \( X = x \) = 1 / 6 \, quad x = 1 \, 2 \, 3 \, 4 \, 5 \, 6 $

Dan untuk nilai lain, peluangnya nol.

== Cumulative Distribution Function (CDF)
<cumulative-distribution-function-cdf>
Fungsi distribusi kumulatif didefinisikan sebagai:

$ F_X \( x \) = P \( X lt.eq x \) $

Untuk random variable diskrit, CDF berbentuk fungsi bertingkat karena nilainya bertambah hanya pada titik-titik tertentu.

Sebagai contoh, untuk dadu fair:

$ F_X \( 3 \) = P \( X lt.eq 3 \) = P \( X = 1 \) + P \( X = 2 \) + P \( X = 3 \) = 3 / 6 = 0.5 $

== Nilai harapan
<nilai-harapan>
Nilai harapan atau #strong[ekspektasi] random variable diskrit didefinisikan sebagai:

$ E \[ X \] = sum_x x thin P \( X = x \) $

Ekspektasi menggambarkan nilai rata-rata jangka panjang jika eksperimen diulang berkali-kali.

=== Contoh
<contoh>
Untuk dadu fair:

$ E \[ X \] = sum_(x = 1)^6 x dot.op 1 / 6 = frac(1 + 2 + 3 + 4 + 5 + 6, 6) = 3.5 $

== Variansi
<variansi>
Variansi mengukur tingkat penyebaran random variable terhadap nilai harapannya:

$ "Var" \( X \) = E \[ \( X - E \[ X \] \)^2 \] $

Rumus praktis:

$ "Var" \( X \) = E \[ X^2 \] - \( E \[ X \] \)^2 $

Semakin besar variansi, semakin besar ketidakpastian atau penyebaran nilai-nilai random variable.

== Distribusi diskrit yang umum
<distribusi-diskrit-yang-umum>
=== Distribusi Bernoulli
<distribusi-bernoulli>
Digunakan untuk eksperimen dengan dua kemungkinan hasil, misalnya sukses atau gagal.

Jika $X tilde.op upright("Bernoulli") \( p \)$, maka:

$ P \( X = 1 \) = p \, #h(2em) P \( X = 0 \) = 1 - p $

Ekspektasi dan variansi:

$ E \[ X \] = p \, #h(2em) "Var" \( X \) = p \( 1 - p \) $

=== Distribusi Binomial
<distribusi-binomial>
Menyatakan banyaknya sukses dalam $n$ percobaan Bernoulli independen.

Jika $X tilde.op upright("Binomial") \( n \, p \)$, maka:

$ P \( X = x \) = binom(n, x) p^x \( 1 - p \)^(n - x) \, quad x = 0 \, 1 \, dots.h \, n $

Ekspektasi dan variansi:

$ E \[ X \] = n p \, #h(2em) "Var" \( X \) = n p \( 1 - p \) $

=== Distribusi Poisson
<distribusi-poisson>
Digunakan untuk memodelkan banyaknya kejadian dalam interval tertentu.

Jika $X tilde.op upright("Poisson") \( lambda \)$, maka:

$ P \( X = x \) = frac(e^(- lambda) lambda^x, x !) \, quad x = 0 \, 1 \, 2 \, dots.h $

Ekspektasi dan variansi:

$ E \[ X \] = lambda \, #h(2em) "Var" \( X \) = lambda $

= Random Variable Kontinu
<random-variable-kontinu>
== Definisi
<definisi-2>
Random variable #strong[kontinu] adalah variabel acak yang dapat mengambil nilai pada suatu interval bilangan real.

Berbeda dari random variable diskrit, random variable kontinu tidak dihitung satu per satu, melainkan dinyatakan melalui suatu fungsi kerapatan.

== Contoh random variable kontinu
<contoh-random-variable-kontinu>
- Tinggi badan
- Berat badan
- Waktu tunggu
- Suhu ruangan
- Tegangan listrik yang diukur secara kontinu

== Probability Density Function (PDF)
<probability-density-function-pdf>
Untuk random variable kontinu, distribusi dinyatakan dengan #strong[probability density function]:

$ f_X \( x \) $

PDF harus memenuhi:

$ f_X \( x \) gt.eq 0 $

dan

$ integral_(- oo)^oo f_X \( x \) thin d x = 1 $

Peluang bahwa $X$ berada pada interval $\[ a \, b \]$ diberikan oleh:

$ P \( a lt.eq X lt.eq b \) = integral_a^b f_X \( x \) thin d x $

== Sifat penting
<sifat-penting>
Untuk random variable kontinu,

$ P \( X = x \) = 0 $

untuk setiap satu nilai tunggal $x$. Ini bukan berarti nilai tersebut mustahil, melainkan karena peluang pada satu titik tunggal dalam konteks kontinu bernilai nol. Peluang hanya bermakna pada interval.

== Cumulative Distribution Function (CDF)
<cumulative-distribution-function-cdf-1>
Sama seperti pada kasus diskrit, fungsi distribusi kumulatif adalah:

$ F_X \( x \) = P \( X lt.eq x \) $

Untuk variabel kontinu:

$ F_X \( x \) = integral_(- oo)^x f_X \( t \) thin d t $

Dan jika terdiferensialkan,

$ f_X \( x \) = frac(d, d x) F_X \( x \) $

== Nilai harapan
<nilai-harapan-1>
Untuk random variable kontinu:

$ E \[ X \] = integral_(- oo)^oo x f_X \( x \) thin d x $

== Variansi
<variansi-1>
$ "Var" \( X \) = E \[ \( X - E \[ X \] \)^2 \] $

atau

$ "Var" \( X \) = E \[ X^2 \] - \( E \[ X \] \)^2 $

Dengan

$ E \[ X^2 \] = integral_(- oo)^oo x^2 f_X \( x \) thin d x $

== Distribusi kontinu yang umum
<distribusi-kontinu-yang-umum>
=== Distribusi Uniform
<distribusi-uniform>
Jika $X$ terdistribusi uniform pada interval $\[ a \, b \]$, maka:

$ f_X \( x \) = frac(1, b - a) \, quad a lt.eq x lt.eq b $

Ekspektasi dan variansi:

$ E \[ X \] = frac(a + b, 2) $

$ "Var" \( X \) = frac(\( b - a \)^2, 12) $

=== Distribusi Eksponensial
<distribusi-eksponensial>
Distribusi ini sering digunakan untuk memodelkan waktu antar kejadian.

Jika $X tilde.op upright("Exponential") \( lambda \)$, maka:

$ f_X \( x \) = lambda e^(- lambda x) \, quad x gt.eq 0 $

Ekspektasi dan variansi:

$ E \[ X \] = 1 / lambda \, #h(2em) "Var" \( X \) = 1 / lambda^2 $

=== Distribusi Normal
<distribusi-normal>
Distribusi normal sangat penting dalam statistika dan sains.

Jika $X tilde.op N \( mu \, sigma^2 \)$, maka PDF-nya adalah:

$ f_X \( x \) = frac(1, sigma sqrt(2 pi)) exp (- frac(\( x - mu \)^2, 2 sigma^2)) $

Parameter:

- $mu$: mean
- $sigma^2$: variansi

Distribusi normal berbentuk lonceng, simetris terhadap mean.

= Perbandingan Variabel Acak Diskrit dan Kontinu
<perbandingan-variabel-acak-diskrit-dan-kontinu>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Aspek], [Diskrit], [Kontinu],),
  table.hline(),
  [Nilai yang mungkin], [Dapat dihitung satu per satu], [Berada pada interval kontinu],
  [Fungsi distribusi utama], [PMF], [PDF],
  [Peluang pada satu nilai], [Bisa positif], [Selalu 0],
  [Operasi utama], [Penjumlahan], [Integral],
  [Contoh], [Jumlah pelanggan], [Waktu tunggu],
)
= Random Variable Bivariate
<random-variable-bivariate>
== Definisi
<definisi-3>
Random variable #strong[bivariate] melibatkan dua random variable yang diamati bersama-sama, biasanya ditulis sebagai pasangan:

$ \( X \, Y \) $

Analisis bivariat penting ketika dua besaran acak saling berkaitan.

== Contoh random variable bivariate
<contoh-random-variable-bivariate>
- Tinggi dan berat badan seseorang
- Nilai UTS dan nilai UAS mahasiswa
- Storage dan compute cost pada cloud computing
- Durasi belajar dan nilai ujian

== Joint distribution
<joint-distribution>
Distribusi bersama menggambarkan peluang atau kerapatan bahwa dua random variable mengambil nilai tertentu secara simultan.

=== Kasus diskrit
<kasus-diskrit>
Untuk random variable diskrit bivariat, digunakan #strong[joint PMF]:

$ p_(X \, Y) \( x \, y \) = P \( X = x \, Y = y \) $

Syaratnya:

$ p_(X \, Y) \( x \, y \) gt.eq 0 $

dan

$ sum_x sum_y p_(X \, Y) \( x \, y \) = 1 $

=== Kasus kontinu
<kasus-kontinu>
Untuk random variable kontinu bivariat, digunakan #strong[joint PDF]:

$ f_(X \, Y) \( x \, y \) $

Syaratnya:

$ f_(X \, Y) \( x \, y \) gt.eq 0 $

dan

$ integral_(- oo)^oo integral_(- oo)^oo f_(X \, Y) \( x \, y \) thin d x thin d y = 1 $

== Marginal distribution
<marginal-distribution>
Dari joint distribution, kita dapat memperoleh distribusi marginal masing-masing variabel.

=== Kasus diskrit
<kasus-diskrit-1>
$ p_X \( x \) = sum_y p_(X \, Y) \( x \, y \) $

$ p_Y \( y \) = sum_x p_(X \, Y) \( x \, y \) $

=== Kasus kontinu
<kasus-kontinu-1>
$ f_X \( x \) = integral_(- oo)^oo f_(X \, Y) \( x \, y \) thin d y $

$ f_Y \( y \) = integral_(- oo)^oo f_(X \, Y) \( x \, y \) thin d x $

== Conditional distribution
<conditional-distribution>
Distribusi kondisional menyatakan distribusi satu variabel dengan syarat variabel lain diketahui.

=== Kasus diskrit
<kasus-diskrit-2>
$ P \( Y = y divides X = x \) = frac(P \( X = x \, Y = y \), P \( X = x \)) $

jika $P \( X = x \) > 0$.

=== Kasus kontinu
<kasus-kontinu-2>
$ f_(Y divides X) \( y divides x \) = frac(f_(X \, Y) \( x \, y \), f_X \( x \)) $

jika $f_X \( x \) > 0$.

== Independensi
<independensi>
Dua random variable $X$ dan $Y$ dikatakan #strong[independen] jika informasi tentang salah satunya tidak mengubah distribusi yang lain.

=== Kasus diskrit
<kasus-diskrit-3>
$ p_(X \, Y) \( x \, y \) = p_X \( x \) p_Y \( y \) $

untuk semua $x$ dan $y$.

=== Kasus kontinu
<kasus-kontinu-3>
$ f_(X \, Y) \( x \, y \) = f_X \( x \) f_Y \( y \) $

untuk semua $x$ dan $y$.

Jika kondisi ini tidak terpenuhi, maka kedua variabel memiliki ketergantungan.

== Nilai harapan bivariat
<nilai-harapan-bivariat>
Ekspektasi masing-masing variabel adalah:

=== Kasus diskrit
<kasus-diskrit-4>
$ E \[ X \] = sum_x sum_y x thin p_(X \, Y) \( x \, y \) $

$ E \[ Y \] = sum_x sum_y y thin p_(X \, Y) \( x \, y \) $

=== Kasus kontinu
<kasus-kontinu-4>
$ E \[ X \] = integral integral x f_(X \, Y) \( x \, y \) thin d x thin d y $

$ E \[ Y \] = integral integral y f_(X \, Y) \( x \, y \) thin d x thin d y $

== Ekspektasi fungsi dua variabel
<ekspektasi-fungsi-dua-variabel>
Sering kali kita membutuhkan nilai harapan dari fungsi dua random variable, misalnya $g \( X \, Y \)$:

=== Kasus diskrit
<kasus-diskrit-5>
$ E \[ g \( X \, Y \) \] = sum_x sum_y g \( x \, y \) p_(X \, Y) \( x \, y \) $

=== Kasus kontinu
<kasus-kontinu-5>
$ E \[ g \( X \, Y \) \] = integral integral g \( x \, y \) f_(X \, Y) \( x \, y \) thin d x thin d y $

== Kovariansi
<kovariansi>
Kovariansi mengukur kecenderungan dua random variable berubah bersama:

$ "Cov" \( X \, Y \) = E \[ \( X - E \[ X \] \) \( Y - E \[ Y \] \) \] $

Rumus lain:

$ "Cov" \( X \, Y \) = E \[ X Y \] - E \[ X \] E \[ Y \] $

Interpretasi umum:

- Kovariansi positif: jika $X$ naik, $Y$ cenderung naik
- Kovariansi negatif: jika $X$ naik, $Y$ cenderung turun
- Kovariansi nol: tidak ada hubungan linear, tetapi belum tentu independen

== Korelasi
<korelasi>
Karena kovariansi dipengaruhi satuan, digunakan ukuran tak berdimensi yaitu korelasi:

$ rho_(X \, Y) = frac("Cov" \( X \, Y \), sigma_X sigma_Y) $

dengan:

- $rho = 1$ menunjukkan hubungan linear positif sempurna
- $rho = - 1$ menunjukkan hubungan linear negatif sempurna
- $rho = 0$ menunjukkan tidak ada hubungan linear

== Distribusi normal bivariat
<distribusi-normal-bivariat>
Salah satu distribusi kontinu bivariat yang sangat penting adalah #strong[distribusi normal bivariat], yang ditentukan oleh:

- mean $mu_X$ dan $mu_Y$
- variansi $sigma_X^2$ dan $sigma_Y^2$
- korelasi $rho$

Distribusi ini banyak digunakan dalam statistika multivariat, simulasi Monte Carlo, pemodelan risiko, dan machine learning.

= Visualisasi Random Variable Bivariat
<visualisasi-random-variable-bivariat>
Beberapa visualisasi yang sering digunakan untuk memahami hubungan dua random variable:

== Scatter plot
<scatter-plot>
Menampilkan titik pasangan $\( x_i \, y_i \)$ untuk melihat pola hubungan.

== Joint frequency table
<joint-frequency-table>
Untuk data diskrit, tabel frekuensi bersama membantu melihat distribusi gabungan.

== Contour plot atau heatmap
<contour-plot-atau-heatmap>
Untuk data kontinu, plot kontur atau heatmap sering digunakan untuk menunjukkan kepadatan bersama.

= Aplikasi Praktis
<aplikasi-praktis>
== Dalam statistika
<dalam-statistika>
Random variable digunakan untuk:

- memodelkan data
- menghitung probabilitas
- melakukan estimasi parameter
- menguji hipotesis

== Dalam rekayasa
<dalam-rekayasa>
Random variable digunakan untuk:

- analisis noise pada sinyal
- reliabilitas sistem
- pemodelan trafik jaringan
- simulasi antrian
- analisis risiko

== Dalam sains data dan AI
<dalam-sains-data-dan-ai>
Random variable digunakan untuk:

- model probabilistik
- Bayesian inference
- generative models
- sampling dan simulasi Monte Carlo
- analisis ketidakpastian prediksi

= Ringkasan
<ringkasan>
== Ringkasan konsep utama
<ringkasan-konsep-utama>
- #strong[Random variable] adalah pemetaan dari hasil percobaan acak ke bilangan real.
- #strong[Random variable diskrit] memiliki nilai yang dapat dihitung satu per satu dan dianalisis dengan PMF.
- #strong[Random variable kontinu] memiliki nilai pada rentang kontinu dan dianalisis dengan PDF.
- #strong[Random variable bivariate] melibatkan dua variabel acak yang diamati bersama, sehingga diperlukan joint distribution, marginal distribution, conditional distribution, kovariansi, dan korelasi.

== Intuisi akhir
<intuisi-akhir>
Jika random variable univariat membantu kita menjawab pertanyaan:

- “Berapa peluang suatu nilai terjadi?”
- “Berapa rata-ratanya?”
- “Seberapa besar penyebarannya?”

maka random variable bivariat membantu kita menjawab pertanyaan yang lebih kaya:

- “Bagaimana dua variabel berubah bersama?”
- “Apakah keduanya saling berkaitan?”
- “Bagaimana distribusi salah satu variabel jika variabel lainnya diketahui?”

Dengan memahami ketiga konsep ini, mahasiswa memiliki fondasi penting untuk mempelajari statistika lanjutan, proses stokastik, machine learning, dan berbagai aplikasi rekayasa berbasis data.

= Latihan Pemahaman
<latihan-pemahaman>
== Soal 1
<soal-1>
Jelaskan perbedaan utama antara random variable diskrit dan kontinu dari sisi:

+ himpunan nilai yang mungkin
+ fungsi distribusi yang digunakan
+ cara menghitung peluang

== Soal 2
<soal-2>
Sebuah random variable diskrit $X$ memiliki PMF berikut:

#table(
  columns: 5,
  align: (auto,right,right,right,right,),
  table.header([$x$], [0], [1], [2], [3],),
  table.hline(),
  [$P \( X = x \)$], [0.1], [0.3], [0.4], [0.2],
)
Hitung:

+ $E \[ X \]$
+ $E \[ X^2 \]$
+ $"Var" \( X \)$

== Soal 3
<soal-3>
Misalkan $X$ adalah random variable kontinu dengan PDF:

$ f_X \( x \) = cases(delim: "{", 2 x \, & 0 lt.eq x lt.eq 1, 0 \, & upright("lainnya")) $

Tentukan:

+ $P \( 0.2 lt.eq X lt.eq 0.8 \)$
+ $F_X \( x \)$ untuk $0 lt.eq x lt.eq 1$
+ $E \[ X \]$

== Soal 4
<soal-4>
Jelaskan arti kovariansi dan korelasi dalam konteks random variable bivariat. Mengapa korelasi lebih mudah diinterpretasikan dibanding kovariansi?

= Penutup
<penutup>
Konsep random variable merupakan salah satu fondasi terpenting dalam probabilitas dan statistika. Dengan membedakan secara jelas random variable diskrit, kontinu, dan bivariate, kita dapat memilih model probabilistik yang tepat, menghitung ukuran-ukuran penting secara benar, dan menafsirkan data dengan lebih mendalam.

Pemahaman yang baik terhadap topik ini akan sangat membantu dalam berbagai mata kuliah lanjutan maupun aplikasi nyata di bidang sains, teknologi, ekonomi, dan rekayasa.
