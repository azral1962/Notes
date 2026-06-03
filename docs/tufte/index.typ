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


#let blockquote(body) = [
  #set text( size: 0.8em )
  #align(right, block(inset: (right: 5em, top: 0.2em, bottom: 0.2em))[#body])
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(245),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
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
  subrefnumbering: "1a",
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
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

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
// #show figure: it => {
//   let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
//   if kind_match == none {
//     return it
//   }
// }
// #show figure.where(kind: kind.matches(regex(""))): none
// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  set par(first-line-indent: 0em)

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
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: luma(245), icon: none, icon_color: black) = {
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
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt,
          width: 100%,
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}
#show figure: set text(size: 8pt)
#import "@preview/drafting:0.2.2": *

#let margincite(key, mode, prefix, suffix, noteNum, hash) = context {
  if query(bibliography).len()>0 {
    let supplement = suffix.split(",").filter(value => not value.contains("dy.")).join(",")
    let dy = if suffix.contains("dy.") {
      eval(suffix.split("dy.").at(1, default: "").split(",").at(0, default: "").trim())
    } else {-2em}
    if supplement!=none and supplement.len()>0 {cite(key, form: "normal", supplement: supplement)}
    else {cite(key, form: "normal")}

    set text(size: 8pt)

    [#margin-note(dy:dy, dx: .25in)[
        #if supplement!=none and supplement.len()>0  {cite(key, form:"full", supplement: supplement)} else {cite(key, form:"full")}]
    ]


  }
}

#let wideblock(content, ..kwargs) = block(..kwargs, width:100%+3.5in-.75in, content)


// Fonts used in front matter, sidenotes, bibliography, and captions
#let sans-fonts = (
    "TeX Gyre Heros",
    // "Noto Sans"
  )

// Fonts used for headings and body copy
#let serif-fonts = (

  "ETBembo",
  "Heuristica",
  "Merriweather",
  // "Harding Text Web",
  // "Linux Libertine",
)

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#let article(
  title: [Paper Title],
  shorttitle: none,
  subtitle: none,
  authors: none,
  product: none,
  date: none,
  lang: "en",
  region: "US",
  version: none,
  draft: false,
  distribution: none,
  abstract: none,
  abstracttitle: none,
  publisher: none,
  documenttype: none,
  toc: none,
  toc_title: none,
  bib: none,
  first-page-footer: none,
  doc
) = {
  // Document metadata
  // set document(title: title, author: authors.map(author => author.name))


  // Page setup
  let lr(l, r, ..kwargs) = wideblock( ..kwargs,
    grid(columns: (1fr, 4fr), align(left, text(size: 8pt, fill: gray, l)), align(right, text( size: 8pt, fill: gray, r)))
  )
  set page(
    paper: "us-letter",
    margin: (left: .75in, right: 3.5in, top: 1in, bottom: 1in),


    header: context {

      if counter(page).get().first() > 1 {
        set text(font: serif-fonts, tracking: 1.5pt)
        lr([],
        [#if shorttitle !=none {upper(shorttitle) } else {upper(title)}
        #text(size: 12pt, [#h(1em)#counter(page).display()])])
      }
    },
    footer: context {
      if counter(page).get().first() < 2 {
        if first-page-footer !=none {first-page-footer}
      }
    },

  )

  set-page-properties()
  set-margin-note-defaults(
    stroke: none,
    side: right,
    page-width: 8.5in-3.5in-.5in-1em,
    margin-right: 3.5in-.75in)

  // Just a suttle lightness to decrease the harsh contrast
  set text(fill:luma(30),
          lang: lang,
           region: region,
           historical-ligatures: true,
          )

  set par(leading: .75em, justify: true, linebreaks: "optimized", first-line-indent: 1em, spacing: 0.65em)

  // Frontmatter

let authorblock() = [
      #set text(size:12pt, style:"italic")
      #set par(first-line-indent: 0em)
      #for (author) in authors [
          #author.name
          #linebreak()
          #if author.email != none [#text(size: 7pt, font: "SF Mono", author.email)]
          #linebreak()

        ]
      #if date != none {
            let (year, month, day) = date.split("-")
            let day = datetime(year: int(year), month: int(month), day: int(day))
            [#day.display("[month repr:long] [day], [year]")]

      }


  ]

  //title block
  wideblock({
    set par(first-line-indent: 0pt)
    v(-.5cm)
    text(font: sans-fonts, tracking: 1.5pt, fill:gray.lighten(60%), upper(documenttype))
    v(.5cm)
    text(font: serif-fonts,  size:22pt, hyphenate: false, weight:"regular", title)
    linebreak()
    text(font: serif-fonts, size: 16pt,  stretch: 80%, weight: "regular", hyphenate: true, subtitle)
    linebreak()
    if version != none {text(font:sans-fonts, size: 8pt, style: "normal", fill:gray)[#version]} else []

    if authors != none {authorblock()}

    if abstract != none {
    block(inset: 1.5em)[#text(font: serif-fonts, size: 10pt)[#abstract]]
    } else {v(3em)}

  })



let tocblock() = {

  set par(first-line-indent: 0pt)
  [#text(size:12pt,weight: "black", [#toc_title])
  #set text(size:.75em, weight: "regular", style: "italic", number-type: "old-style")
  #outline(
    title: none,
    depth: 1,
    indent: 1em,
  )]
}

//TOC
if toc !=none [#margin-note(dx:0em, dy:-1em)[#tocblock()]]





  // Headings
  set heading(numbering: none)
  show heading.where(level:1): it => {
    v(2em,weak:true)
    text(size:14pt, weight: "black",it)
    v(1em,weak: true)
  }

  show heading.where(level:2): it => {
    v(1.3em, weak: true)
    text(size: 13pt, weight: "regular",style: "italic",it)
    v(1em,weak: true)
  }

  show heading.where(level:3): it => {
    v(1em,weak:true)
    text(size:11pt,style:"italic",weight:"thin",it)
    v(0.65em,weak:true)
  }

  show heading: it => {
    if it.level <= 3 {it} else {}
  }


  // Tables and figures
  show figure: set figure.caption(separator: [.#h(0.5em)])
  show figure.caption: set align(left)
  show figure.caption: set text(font: sans-fonts)

  show figure.where(kind: table): set figure.caption(position: top)
  show figure.where(kind: table): set figure(numbering: "I")

  show figure.where(kind: image): set figure(supplement: [Figure], numbering: "1")

  show figure.where(kind: raw): set figure.caption(position: top)
  show figure.where(kind: raw): set figure(supplement: [Code], numbering: "1")
  show raw: set text(font: "SF Mono", size: 8pt, ligatures: false)


  // Equations
  set math.equation(numbering: "(1)")
  show math.equation: set block(spacing: 0.65em)

  show link: underline

  // Lists
  set enum(
    indent: 1em,
    body-indent: 1em,
  )
  show enum: set par(justify: false)
  set list(
    indent: 1em,
    body-indent: 1em,
  )
  show list: set par(justify: false)


  // Body text
  set text(
    font: serif-fonts,
    style: "normal",
    weight: "regular",
    hyphenate: true,
    size: 10pt
  )


  show cite.where(form:"prose"): none

  set text(size: 12pt)
  v(-.5in)
  doc

  show bibliography: set text(font:sans-fonts)
  show bibliography: set par(justify:false)
  set bibliography(title:none)
  if bib != none {
    heading(level:1,[References])
    bib
  }


}
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
  title: [Petunjuk Analisis Joint Distribution di Spreadsheet],
    subtitle: [Berat, Tinggi, Bulan Lahir, Kovarians, Korelasi, dan Scatter Plot],
  
  authors: (
                    ( name: [Armein Z. R. Langi],
            affiliation: [],
            location: [],
            role: [],
            email: [azr.langi\@gmail.com] ),
              
  ),
         
  date: "2026-04-15",

  lang: "id",
  abstract: [This #strong[Tufte Inspired] manuscript format for Quarto honors Edward Tufte's distinctive style. It simplifies creating handout-like documents and websites by emulating the aesthetics of Tufte's books. This document serves two purposes: It showcases the format and acts as an evolving authoring guide.

],
  abstracttitle: "Abstrak",
  toc: true,
  version: [v.1.0],
publisher: "Publisher",
documenttype: [Handout],
  toc_title: [Daftar Isi],
// //   toc_depth: 3,
  // cols: 1,
  doc,
)

= Pendahuluan
<pendahuluan>
Dokumen ini menjelaskan cara melakukan analisis sederhana langsung di #strong[spreadsheet] seperti #strong[Microsoft Excel] atau #strong[Google Sheets], untuk data mahasiswa yang memuat:

- nama mahasiswa,
- bulan lahir (#emph[month of birth] / #NormalTok("mob");),
- berat badan,
- tinggi badan.

Analisis yang akan dibahas meliputi:

+ #strong[joint distribution] untuk pasangan:
  - berat vs tinggi,
  - bulan lahir vs berat,
+ #strong[kovarians],
+ #strong[korelasi],
+ #strong[scatter plot].

= Struktur Data
<struktur-data>
Misalkan data tersusun seperti berikut:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Kolom], [Isi Data],),
  table.hline(),
  [A], [Nama mahasiswa],
  [B], [Bulan lahir (#NormalTok("mob");)],
  [C], [Berat badan],
  [D], [Tinggi badan],
)
Contoh data berada pada baris #strong[2 sampai 101].

== Contoh Tabel Data
<contoh-tabel-data>
#table(
  columns: 4,
  align: (auto,auto,right,right,),
  table.header([Nama], [MOB], [Berat], [Tinggi],),
  table.hline(),
  [Andi], [Jan], [56], [165],
  [Budi], [Mar], [68], [172],
  [Citra], [Jan], [49], [158],
  [Dewi], [Jul], [61], [160],
  [Eko], [Sep], [73], [175],
)
= Konsep Dasar
<konsep-dasar>
== Apa itu joint distribution?
<apa-itu-joint-distribution>
#strong[Joint distribution] adalah distribusi gabungan dua variabel. \
Dalam konteks spreadsheet, bentuk praktisnya biasanya berupa #strong[tabel frekuensi silang].

Contoh:

- berapa banyak mahasiswa dengan berat #strong[50--59 kg] dan tinggi #strong[160--169 cm],
- berapa banyak mahasiswa lahir di bulan #strong[Januari] dan memiliki berat #strong[60--69 kg].

== Mengapa perlu bin?
<mengapa-perlu-bin>
Untuk variabel numerik seperti #strong[berat] dan #strong[tinggi], data sering dikelompokkan ke dalam #strong[interval] atau #strong[bin] agar mudah dibuat tabel distribusinya.

Contoh bin:

- berat: 40--49, 50--59, 60--69, 70--79
- tinggi: 150--159, 160--169, 170--179

= Joint Distribution Berat vs Tinggi
<joint-distribution-berat-vs-tinggi>
Karena #strong[berat] dan #strong[tinggi] adalah variabel numerik, kita buat dulu kolom kategori.

== Langkah 1: membuat kategori berat
<langkah-1-membuat-kategori-berat>
Tambahkan kolom baru, misalnya di #strong[E], dengan judul #strong[Kategori Berat].

Pada sel #NormalTok("E2"); tulis:

#Skylighting(([#NormalTok("=FLOOR(C2,10)&\"-\"&FLOOR(C2,10)+9");],));
Lalu salin ke bawah.

Contoh hasil:

- 56 menjadi #NormalTok("50-59");
- 68 menjadi #NormalTok("60-69");

== Langkah 2: membuat kategori tinggi
<langkah-2-membuat-kategori-tinggi>
Tambahkan kolom baru, misalnya di #strong[F], dengan judul #strong[Kategori Tinggi].

Pada sel #NormalTok("F2"); tulis:

#Skylighting(([#NormalTok("=FLOOR(D2,10)&\"-\"&FLOOR(D2,10)+9");],));
Lalu salin ke bawah.

Contoh hasil:

- 165 menjadi #NormalTok("160-169");
- 172 menjadi #NormalTok("170-179");

== Langkah 3: membuat tabel distribusi gabungan
<langkah-3-membuat-tabel-distribusi-gabungan>
Misalkan:

- daftar kategori berat diletakkan di #NormalTok("H2:H5");,
- daftar kategori tinggi diletakkan di #NormalTok("I1:L1");.

Contoh susunan:

#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([], [I], [J], [K], [L],),
  table.hline(),
  [1], [150-159], [160-169], [170-179], [180-189],
  [2], [40-49], [], [], [],
  [3], [50-59], [], [], [],
  [4], [60-69], [], [], [],
  [5], [70-79], [], [], [],
)
Di sel #NormalTok("I2");, masukkan:

#Skylighting(([#NormalTok("=COUNTIFS($E$2:$E$101,$H2,$F$2:$F$101,I$1)");],));
Salin ke kanan dan ke bawah.

Hasil tabel ini adalah #strong[joint frequency distribution] antara berat dan tinggi.

== Langkah 4: mengubah frekuensi menjadi probabilitas
<langkah-4-mengubah-frekuensi-menjadi-probabilitas>
Jika ingin menjadi #strong[joint probability distribution], bagi setiap frekuensi dengan jumlah data.

Misalnya di sel lain:

#Skylighting(([#NormalTok("=I2/COUNTA($A$2:$A$101)");],));
Salin ke seluruh tabel.

= Joint Distribution Bulan Lahir vs Berat
<joint-distribution-bulan-lahir-vs-berat>
Karena #strong[bulan lahir] sudah merupakan variabel kategorikal, kita hanya perlu membuat kategori untuk #strong[berat].

Gunakan kolom #strong[Kategori Berat] yang sudah dibuat di kolom #NormalTok("E");.

Misalkan:

- daftar bulan diletakkan di #NormalTok("N2:N13");,
- daftar kategori berat diletakkan di #NormalTok("O1:R1");.

Di sel #NormalTok("O2");, masukkan:

#Skylighting(([#NormalTok("=COUNTIFS($B$2:$B$101,$N2,$E$2:$E$101,O$1)");],));
Salin ke kanan dan ke bawah.

Ini menghasilkan #strong[joint frequency distribution] antara bulan lahir dan kategori berat.

== Catatan
<catatan>
Untuk pasangan #strong[bulan lahir vs berat], joint distribution lebih bermakna daripada menghitung kovarians langsung, karena bulan lahir adalah variabel kategorikal.

= Menggunakan Pivot Table
<menggunakan-pivot-table>
Untuk banyak pengguna, cara termudah membuat joint distribution adalah dengan #strong[Pivot Table].

== Berat vs Tinggi
<berat-vs-tinggi>
+ Pilih seluruh data.
+ Klik #strong[Insert] -\> #strong[Pivot Table].
+ Masukkan #strong[Kategori Berat] ke #strong[Rows].
+ Masukkan #strong[Kategori Tinggi] ke #strong[Columns].
+ Masukkan #strong[Nama] atau #strong[Berat] ke #strong[Values], lalu ubah menjadi #strong[Count].

== Bulan Lahir vs Berat
<bulan-lahir-vs-berat>
+ Buat Pivot Table baru.
+ Masukkan #strong[MOB] ke #strong[Rows].
+ Masukkan #strong[Kategori Berat] ke #strong[Columns].
+ Masukkan #strong[Nama] ke #strong[Values], lalu ubah menjadi #strong[Count].

= Kovarians
<kovarians>
Kovarians mengukur bagaimana dua variabel numerik berubah bersama.

Untuk menghitung kovarians antara #strong[berat] dan #strong[tinggi]:

== Kovarians sampel
<kovarians-sampel>
#Skylighting(([#NormalTok("=COVARIANCE.S(C2:C101,D2:D101)");],));
== Kovarians populasi
<kovarians-populasi>
#Skylighting(([#NormalTok("=COVARIANCE.P(C2:C101,D2:D101)");],));
== Interpretasi singkat
<interpretasi-singkat>
- Nilai #strong[positif]: jika berat naik, tinggi cenderung naik.
- Nilai #strong[negatif]: jika berat naik, tinggi cenderung turun.
- Nilai dekat #strong[nol]: hubungan linear bersama lemah.

= Korelasi
<korelasi>
Korelasi mengukur kekuatan hubungan linear dua variabel numerik.

Gunakan:

#Skylighting(([#NormalTok("=CORREL(C2:C101,D2:D101)");],));
== Interpretasi umum
<interpretasi-umum>
- mendekati #NormalTok("+1");: hubungan positif kuat,
- mendekati #NormalTok("0");: hubungan linear lemah,
- mendekati #NormalTok("-1");: hubungan negatif kuat.

== Catatan penting
<catatan-penting>
Korelasi #strong[lebih mudah diinterpretasikan] daripada kovarians karena nilainya selalu berada antara #NormalTok("-1"); dan #NormalTok("+1");.

= Scatter Plot
<scatter-plot>
== Scatter plot untuk berat vs tinggi
<scatter-plot-untuk-berat-vs-tinggi>
Ini adalah grafik yang paling sesuai.

Langkah umum:

+ blok kolom #strong[Berat] dan #strong[Tinggi],
+ pilih #strong[Insert] -\> #strong[Chart],
+ pilih jenis #strong[Scatter Plot],
+ atur:
  - sumbu-X = berat,
  - sumbu-Y = tinggi.

== Interpretasi scatter plot
<interpretasi-scatter-plot>
Dari scatter plot, Anda dapat melihat:

- apakah titik-titik membentuk pola naik,
- apakah ada #emph[outlier],
- apakah hubungan tampak linear atau tidak.

= Bulan Lahir vs Berat: Visualisasi yang Lebih Cocok
<bulan-lahir-vs-berat-visualisasi-yang-lebih-cocok>
Karena bulan lahir adalah kategori, scatter plot kurang ideal.

Visualisasi yang lebih cocok:

- #strong[diagram batang] rata-rata berat per bulan,
- #strong[box plot] berat per bulan,
- #strong[pivot chart] dari tabel distribusi.

== Menghitung rata-rata berat per bulan
<menghitung-rata-rata-berat-per-bulan>
Misalkan daftar bulan ada di #NormalTok("N2:N13");. \
Di sel #NormalTok("O2"); gunakan:

#Skylighting(([#NormalTok("=AVERAGEIF($B$2:$B$101,N2,$C$2:$C$101)");],));
Untuk menghitung banyaknya mahasiswa per bulan:

#Skylighting(([#NormalTok("=COUNTIF($B$2:$B$101,N2)");],));
= Ringkasan Rumus Penting
<ringkasan-rumus-penting>
== Kategori berat
<kategori-berat>
#Skylighting(([#NormalTok("=FLOOR(C2,10)&\"-\"&FLOOR(C2,10)+9");],));
== Kategori tinggi
<kategori-tinggi>
#Skylighting(([#NormalTok("=FLOOR(D2,10)&\"-\"&FLOOR(D2,10)+9");],));
== Joint frequency distribution
<joint-frequency-distribution>
#Skylighting(([#NormalTok("=COUNTIFS(range_kategori_1,label_baris,range_kategori_2,label_kolom)");],));
== Kovarians sampel
<kovarians-sampel-1>
#Skylighting(([#NormalTok("=COVARIANCE.S(C2:C101,D2:D101)");],));
== Korelasi
<korelasi-1>
#Skylighting(([#NormalTok("=CORREL(C2:C101,D2:D101)");],));
== Rata-rata berat per bulan
<rata-rata-berat-per-bulan>
#Skylighting(([#NormalTok("=AVERAGEIF($B$2:$B$101,N2,$C$2:$C$101)");],));
= Saran Interpretasi untuk Mahasiswa
<saran-interpretasi-untuk-mahasiswa>
Saat mahasiswa selesai membuat tabel dan grafik, mereka dapat diminta menjawab pertanyaan seperti:

+ Apakah berat dan tinggi menunjukkan kecenderungan hubungan positif?
+ Di interval berat dan tinggi mana paling banyak mahasiswa berada?
+ Apakah bulan lahir tertentu tampak dominan pada kelompok berat tertentu?
+ Apakah ada data yang tampak menyimpang dari pola umum?

= Latihan Singkat
<latihan-singkat>
== Latihan 1
<latihan-1>
Gunakan data mahasiswa Anda untuk membuat:

- kategori berat,
- kategori tinggi,
- tabel joint distribution berat vs tinggi.

== Latihan 2
<latihan-2>
Hitung:

- kovarians berat dan tinggi,
- korelasi berat dan tinggi.

Lalu jelaskan apakah hubungan keduanya lemah, sedang, atau kuat.

== Latihan 3
<latihan-3>
Buat scatter plot berat vs tinggi dan tulis interpretasi singkat dalam 3--5 kalimat.

== Latihan 4
<latihan-4>
Buat tabel distribusi gabungan antara bulan lahir dan kategori berat, lalu amati apakah ada pola tertentu.

= Penutup
<penutup>
Dengan bantuan fungsi spreadsheet sederhana seperti #NormalTok("COUNTIFS");, #NormalTok("COVARIANCE.S");, #NormalTok("CORREL");, dan fitur #strong[Pivot Table] serta #strong[Scatter Plot], analisis hubungan dua variabel dapat dilakukan langsung tanpa software statistik tambahan.

Untuk data #strong[numerik vs numerik] seperti berat dan tinggi, analisis yang paling sesuai adalah:

- joint distribution,
- kovarians,
- korelasi,
- scatter plot.

Untuk data #strong[kategorikal vs numerik] seperti bulan lahir dan berat, analisis yang lebih sesuai adalah:

- tabel distribusi gabungan,
- rata-rata per kategori,
- diagram batang atau box plot.

#set bibliography(style: "springer-humanities-author-date")

#bibliography(("references.bib"))

