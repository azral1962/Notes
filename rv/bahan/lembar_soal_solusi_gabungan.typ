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
  title: [Lembar Soal dan Solusi Gabungan],
  subtitle: [Ringkasan soal-jawab dari thread Probabilitas dan Statistika],
  lang: "id",
  toc_title: [Daftar Isi],
  toc_depth: 3,
  doc,
)

= Keterangan
<keterangan>
Dokumen ini menggabungkan seluruh soal dan jawaban yang muncul pada thread ini ke dalam satu berkas Quarto. \
Topologi jaringan digambar ulang dalam format vektor (#NormalTok(".svg");) agar tetap tajam saat dirender.

#quote(block: true)[
Catatan: untuk soal terakhir (UTS 2022), topologi digambar ulang berdasarkan interpretasi visual dari gambar sumber. \
Solusi numerik mengikuti hasil diskusi pada thread.
]

#horizontalrule

= Soal 1 --- Jaringan 8 Link antara A dan B
<soal-1-jaringan-8-link-antara-a-dan-b>
== Topologi hasil ekstraksi dan gambar ulang
<topologi-hasil-ekstraksi-dan-gambar-ulang>
#box(image("figures/topology_soal1.svg", alt: "Topologi 8 link antara A dan B", width: 80%))

== Pernyataan soal
<pernyataan-soal>
Probabilitas sebuah link bekerja dengan baik adalah $0.6$.

+ Jika sistem diamati pada waktu acak, berapa kemungkinan:
  - tepat dua link bekerja dengan baik?
  - link $g$ dan tepat satu link lagi bekerja dengan baik?
+ Jika secara bersamaan tepat enam link tidak bekerja dengan baik, berapa kemungkinan $A$ dapat berkomunikasi dengan $B$?

== Solusi
<solusi>
Misalkan $X$ = banyaknya link yang bekerja baik. Karena ada 8 link independen dan tiap link ON dengan peluang $0.6$, maka:

$ X tilde.op upright(B i n o m i a l) \( 8 \, 0.6 \) $

=== \(a)(i) Tepat dua link bekerja baik
<ai-tepat-dua-link-bekerja-baik>
$ P \( X = 2 \) = binom(8, 2) \( 0.6 \)^2 \( 0.4 \)^6 $

$ = 28 \( 0.36 \) \( 0.004096 \) = 0.04128768 $

#strong[Jawaban:]

$ #box(stroke: black, inset: 3pt, [$ P \( upright("tepat 2 link baik") \) approx 0.0413 $]) $

=== \(a)(ii) Link $g$ ON dan tepat satu link lain ON
<aii-link-g-on-dan-tepat-satu-link-lain-on>
Ada dua cara menuliskannya, dan keduanya ekuivalen:

$ P \( g upright(" ON dan tepat 1 link lain ON") \) = binom(7, 1) \( 0.6 \)^2 \( 0.4 \)^6 $

atau

$ P \( g upright(" ON") \) dot.op P \( upright("tepat 1 dari 7 link lain ON") \) = 0.6 dot.op binom(7, 1) \( 0.6 \)^1 \( 0.4 \)^6 $

Keduanya memberi hasil yang sama:

$ 7 \( 0.6 \)^2 \( 0.4 \)^6 = 0.01032192 $

#strong[Jawaban:]

$ #box(stroke: black, inset: 3pt, [$ P \( g upright(" ON dan tepat 1 link lain ON") \) approx 0.01032 $]) $

=== \(b) Diketahui tepat 6 link OFF
<b-diketahui-tepat-6-link-off>
Berarti tepat 2 link ON. Semua pasangan 2-link-ON dianggap sama mungkin.

Total pasangan link ON:

$ binom(8, 2) = 28 $

Dari topologi, agar $A$ dapat berkomunikasi dengan $B$ ketika hanya ada 2 link ON, pasangan ON yang efektif adalah dua jalur dua-link langsung: - ${ b \, g }$ - ${ c \, h }$

Jadi banyak pasangan yang menguntungkan ada 2.

$ P \( A arrow.l.r B divides upright("tepat 6 OFF") \) = 2 / 28 = 1 / 14 $

#strong[Jawaban:]

$ #box(stroke: black, inset: 3pt, [$ 1 / 14 approx 0.0714 $]) $

== Ringkasan jawaban Soal 1
<ringkasan-jawaban-soal-1>
$ #box(stroke: black, inset: 3pt, [$ \( a \) \( i \) = 0.0413 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ \( a \) \( i i \) = 0.01032 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ \( b \) = 1 / 14 approx 0.0714 $]) $

#horizontalrule

= Soal 2 --- Jaringan 3 Client dan 1 Server
<soal-2-jaringan-3-client-dan-1-server>
== Topologi hasil ekstraksi dan gambar ulang
<topologi-hasil-ekstraksi-dan-gambar-ulang-1>
#box(image("figures/topology_soal2.svg", alt: "Topologi router untuk 3 client dan 1 server", width: 88%))

== Pernyataan soal
<pernyataan-soal-1>
Setiap simbol #NormalTok("||"); melambangkan sebuah router yang menghubungkan koneksi antara 3 client dan 1 server. \
Satu-satunya hal yang memutus rute adalah router yang OFF. \
Status router hanya ada dua: ${ O N \, O F F }$. \
Semua router independen dan:

$ P \( O N \) = 0.8 $

Dengan label router $A \, B \, C \, D \, E \, F \, G \, H \, I$, tentukan:

+ $P \( upright("Client 1 terhubung dengan Client 2") \)$
+ $P \( upright("Client 1, Client 2, dan Client 3 terhubung satu sama lain") \)$
+ $P \( upright("Client 1 terhubung dengan Client 3 dan keduanya terhubung dengan server") \)$
+ Diketahui tepat 4 router OFF, sisanya ON. Berapa $P \( upright("Client 1 terhubung dengan server") \)$?
+ Diketahui tepat 3 router OFF, sisanya ON. Berapa $P \( upright("Client 1 terhubung dengan server") \)$?

== Solusi
<solusi-1>
=== \(a) Client 1 terhubung dengan Client 2
<a-client-1-terhubung-dengan-client-2>
Agar Client 1 terhubung dengan Client 2, cukup:

- $A$ ON
- $B$ ON

Maka:

$ P = 0.8^2 = 0.64 $

$ #box(stroke: black, inset: 3pt, [$ 0.64 $]) $

=== \(b) Client 1, Client 2, dan Client 3 saling terhubung
<b-client-1-client-2-dan-client-3-saling-terhubung>
Agar ketiganya saling terhubung:

- $A$ ON
- $B$ ON
- $C$ ON
- $D$ ON

Maka:

$ P = 0.8^4 = 0.4096 $

$ #box(stroke: black, inset: 3pt, [$ 0.4096 $]) $

=== \(c) Client 1 terhubung dengan Client 3 dan keduanya terhubung dengan server
<c-client-1-terhubung-dengan-client-3-dan-keduanya-terhubung-dengan-server>
Syaratnya:

- $A \, C \, D \, I$ ON
- minimal satu dari $E \, F \, G \, H$ ON

Maka:

$ P = 0.8^4 (1 - 0.2^4) $

$ = 0.4096 \( 0.9984 \) = 0.40894464 $

$ #box(stroke: black, inset: 3pt, [$ 0.40894464 $]) $

=== \(d) Tepat 4 router OFF
<d-tepat-4-router-off>
Berarti tepat 5 router ON. \
Kita hitung secara kombinatorial bersyarat.

Total konfigurasi 5 router ON:

$ binom(9, 5) = 126 $

Agar Client 1 terhubung ke server, router yang wajib ON:

- $A \, C \, I$
- minimal satu dari ${ E \, F \, G \, H }$

Karena $A \, C \, I$ wajib ON, kita memilih 2 router tambahan dari ${ B \, D \, E \, F \, G \, H }$, tetapi tidak boleh hanya ${ B \, D }$.

$ binom(6, 2) = 15 $

Konfigurasi gagal hanya 1, yaitu ${ B \, D }$. \
Jadi konfigurasi menguntungkan:

$ 15 - 1 = 14 $

Maka:

$ P = 14 / 126 = 1 / 9 $

$ #box(stroke: black, inset: 3pt, [$ 1 / 9 approx 0.1111 $]) $

=== \(e) Tepat 3 router OFF
<e-tepat-3-router-off>
Berarti tepat 6 router ON.

Total konfigurasi:

$ binom(9, 6) = 84 $

Tetap perlu $A \, C \, I$ ON dan minimal satu dari ${ E \, F \, G \, H }$ ON. \
Sekarang kita memilih 3 router tambahan dari ${ B \, D \, E \, F \, G \, H }$.

$ binom(6, 3) = 20 $

Tidak mungkin semua 3 dipilih hanya dari ${ B \, D }$, jadi semua 20 pilihan valid.

$ P = 20 / 84 = 5 / 21 $

$ #box(stroke: black, inset: 3pt, [$ 5 / 21 approx 0.2381 $]) $

== Ringkasan jawaban Soal 2
<ringkasan-jawaban-soal-2>
$ #box(stroke: black, inset: 3pt, [$ a = 0.64 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ b = 0.4096 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ c = 0.40894464 $]) $

$ #box(stroke: black, inset: 3pt, [$ d = 1 / 9 approx 0.1111 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ e = 5 / 21 approx 0.2381 $]) $

#horizontalrule

= Soal 3 --- UTS 2022 Soal 5 Sistem Komunikasi
<soal-3-uts-2022-soal-5-sistem-komunikasi>
== Topologi hasil ekstraksi dan gambar ulang
<topologi-hasil-ekstraksi-dan-gambar-ulang-2>
#box(image("figures/topology_soal3.svg", alt: "Topologi link komunikasi UTS 2022", width: 82%))

== Pernyataan soal
<pernyataan-soal-2>
Setiap elemen #NormalTok("||"); melambangkan sebuah link komunikasi. \
Failure antar-link saling independen. \
Peluang sebuah link bekerja baik adalah:

$ p = 0.9 delta_3 = 0.9 + 0.01 delta_3 $

Dengan 3 digit terakhir NIM mahasiswa = #strong[1, 2, 3], maka:

$ delta_1 = 1 \, quad delta_2 = 2 \, quad delta_3 = 3 $

sehingga:

$ p = 0.9 + 0.01 \( 3 \) = 0.93 $

Soal:

+ Diketahui tepat 7 link tidak bekerja (4 link ON), probabilitas $D$ dapat berkomunikasi dengan $J$.
+ Diketahui tepat 8 link tidak bekerja (3 link ON), probabilitas $D$ dapat berkomunikasi dengan $J$.
+ Diketahui link $i \, v \, v i i \, i x \, x$ pasti tidak bekerja, probabilitas $I$ dapat berkomunikasi dengan $J$.
+ Diketahui link $i i \, i v \, v i \, v i i i \, x \, x i$ pasti tidak bekerja, probabilitas $B$ dapat berkomunikasi dengan $G$.

== Solusi dan jawaban akhir
<solusi-dan-jawaban-akhir>
=== \(a) Tepat 7 link OFF
<a-tepat-7-link-off>
Dengan pendekatan kombinatorial pada 11 link, diperoleh:

- total konfigurasi 4-link-ON:

$ binom(11, 4) = 330 $

- konfigurasi yang membuat $D$ terhubung ke $J$: 31

Maka:

$ P \( D arrow.l.r J divides upright("tepat 4 ON") \) = 31 / 330 = 0.093939 dots.h $

Dibulatkan 3 angka di belakang desimal:

$ #box(stroke: black, inset: 3pt, [$ 0.094 $]) $

=== \(b) Tepat 8 link OFF
<b-tepat-8-link-off>
- total konfigurasi 3-link-ON:

$ binom(11, 3) = 165 $

- konfigurasi yang membuat $D$ terhubung ke $J$: 3

Maka:

$ P \( D arrow.l.r J divides upright("tepat 3 ON") \) = 3 / 165 = 1 / 55 = 0.0181818 dots.h $

Dibulatkan 3 angka di belakang desimal:

$ #box(stroke: black, inset: 3pt, [$ 0.018 $]) $

=== \(c) Link $i \, v \, v i i \, i x \, x$ pasti OFF
<c-link-ivviiixx-pasti-off>
Dari hasil diskusi thread, peluang $I$ terhubung ke $J$ ditulis:

$ P = p + \( 1 - p \) thin p thin \( p + p^3 - p^4 \) $

Dengan $p = 0.93$:

$ P = 0.93 + 0.07 dot.op 0.93 dot.op \( 0.93 + 0.93^3 - 0.93^4 \) = 0.994208454849 $

Dibulatkan 4 angka di belakang desimal:

$ #box(stroke: black, inset: 3pt, [$ 0.9942 $]) $

=== \(d) Link $i i \, i v \, v i \, v i i i \, x \, x i$ pasti OFF
<d-link-iiivviviiixxi-pasti-off>
Dari hasil diskusi thread, peluang $B$ terhubung ke $G$ adalah:

$ P = \( 1 - p \) \( 2 p^2 - p^4 \) + p \( 2 p - p^2 \)^2 $

Dengan $p = 0.93$:

$ P = \( 0.07 \) \( 2 dot.op 0.93^2 - 0.93^4 \) + 0.93 \( 2 dot.op 0.93 - 0.93^2 \)^2 = 0.9896306886 $

Dibulatkan 4 angka di belakang desimal:

$ #box(stroke: black, inset: 3pt, [$ 0.9896 $]) $

== Ringkasan jawaban Soal 3
<ringkasan-jawaban-soal-3>
$ #box(stroke: black, inset: 3pt, [$ a = 0.094 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ b = 0.018 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ c = 0.9942 $]) #h(2em) #box(stroke: black, inset: 3pt, [$ d = 0.9896 $]) $

#horizontalrule

= Ringkasan seluruh hasil
<ringkasan-seluruh-hasil>
== Soal 1
<soal-1>
- $P \( upright("tepat 2 link baik") \) = #box(stroke: black, inset: 3pt, [$ 0.0413 $])$
- $P \( g upright(" ON dan tepat 1 link lain ON") \) = #box(stroke: black, inset: 3pt, [$ 0.01032 $])$
- $P \( A arrow.l.r B divides upright("tepat 6 OFF") \) = #box(stroke: black, inset: 3pt, [$ 1 / 14 approx 0.0714 $])$

== Soal 2
<soal-2>
- $P \( upright("Client 1 terhubung Client 2") \) = #box(stroke: black, inset: 3pt, [$ 0.64 $])$
- $P \( upright("Client 1,2,3 saling terhubung") \) = #box(stroke: black, inset: 3pt, [$ 0.4096 $])$
- $P \( upright("Client 1 dan Client 3 terhubung ke server") \) = #box(stroke: black, inset: 3pt, [$ 0.40894464 $])$
- $P \( upright("Client 1 ke server") divides 4 upright(" OFF") \) = #box(stroke: black, inset: 3pt, [$ 1 / 9 approx 0.1111 $])$
- $P \( upright("Client 1 ke server") divides 3 upright(" OFF") \) = #box(stroke: black, inset: 3pt, [$ 5 / 21 approx 0.2381 $])$

== Soal 3
<soal-3>
- $#box(stroke: black, inset: 3pt, [$ 0.094 $])$
- $#box(stroke: black, inset: 3pt, [$ 0.018 $])$
- $#box(stroke: black, inset: 3pt, [$ 0.9942 $])$
- $#box(stroke: black, inset: 3pt, [$ 0.9896 $])$

#horizontalrule

= Berkas pendukung
<berkas-pendukung>
- #NormalTok("figures/topology_soal1.svg");
- #NormalTok("figures/topology_soal2.svg");
- #NormalTok("figures/topology_soal3.svg");

Dokumen ini siap dipakai sebagai bahan kuliah, arsip pembahasan, atau dasar untuk dirender menjadi HTML/PDF melalui Quarto.
