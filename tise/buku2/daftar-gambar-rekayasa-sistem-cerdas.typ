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
  title: [Daftar Gambar yang Harus Dibuat untuk Buku Rekayasa Sistem Cerdas],
  authors: (
    ( name: [Armein Z. R. Langi],
      affiliation: [],
      email: [] ),
    ),
  sectionnumbering: "1.1.a",
  toc: true,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

Dokumen ini berisi daftar seluruh gambar yang dirujuk di dalam #NormalTok("draft3.qmd");, lengkap dengan nama file, label gambar, section asal, caption, deskripsi, dan prompt produksi yang diperluas. Dokumen ini dapat dipakai sebagai #emph[shot list] untuk pembuatan ilustrasi final.

Jumlah gambar yang teridentifikasi: #strong[38].

= Pedoman visual umum
<pedoman-visual-umum>
- Latar putih polos.
- Garis pena hitam tipis hingga sedang.
- Tanpa warna dan tanpa shading berat.
- Komposisi sederhana, bersih, dan akademik.
- Fokus pada kejelasan konsep, bukan kemeriahan visual.

= Ringkasan nama file
<ringkasan-nama-file>
#table(
  columns: (30.77%, 23.08%, 23.08%, 23.08%),
  align: (right,auto,auto,auto,),
  table.header([No], [Section], [Nama file], [Label gambar],),
  table.hline(),
  [1], [Perceive (Persepsi)], [#NormalTok("figures/1-1-perceive-persepsi.png");], [#NormalTok("fig-1-1-perceive-persepsi");],
  [2], [Understand (Memahami)], [#NormalTok("figures/1-2-understand-memahami.png");], [#NormalTok("fig-1-2-understand-memahami");],
  [3], [Decision (Keputusan)], [#NormalTok("figures/1-3-decision-keputusan.png");], [#NormalTok("fig-1-3-decision-keputusan");],
  [4], [Act (Tindakan)], [#NormalTok("figures/1-4-act-tindakan.png");], [#NormalTok("fig-1-4-act-tindakan");],
  [5], [Learning (Belajar)], [#NormalTok("figures/1-5-learning-belajar.png");], [#NormalTok("fig-1-5-learning-belajar");],
  [6], [Product (Produk)], [#NormalTok("figures/2-1-product-produk.png");], [#NormalTok("fig-2-1-product-produk");],
  [7], [Service (Layanan)], [#NormalTok("figures/2-2-service-layanan.png");], [#NormalTok("fig-2-2-service-layanan");],
  [8], [Knowledge (Pengetahuan)], [#NormalTok("figures/2-3-knowledge-pengetahuan.png");], [#NormalTok("fig-2-3-knowledge-pengetahuan");],
  [9], [Value (Nilai)], [#NormalTok("figures/2-4-value-nilai.png");], [#NormalTok("fig-2-4-value-nilai");],
  [10], [Environment (Lingkungan)], [#NormalTok("figures/2-5-environment-lingkungan.png");], [#NormalTok("fig-2-5-environment-lingkungan");],
  [11], [Energi Produk (Fisik)], [#NormalTok("figures/3-1-energi-produk-fisik.png");], [#NormalTok("fig-3-1-energi-produk-fisik");],
  [12], [Energi Layanan (Atensi)], [#NormalTok("figures/3-2-energi-layanan-atensi.png");], [#NormalTok("fig-3-2-energi-layanan-atensi");],
  [13], [Energi Pengetahuan (Algoritma)], [#NormalTok("figures/3-3-energi-pengetahuan-algoritma.png");], [#NormalTok("fig-3-3-energi-pengetahuan-algoritma");],
  [14], [Energi Nilai (Finansial/Sosial)], [#NormalTok("figures/3-4-energi-nilai-finansial-sosial.png");], [#NormalTok("fig-3-4-energi-nilai-finansial-sosial");],
  [15], [Energi Ruang Lingkungan (Inspirasi)], [#NormalTok("figures/3-5-energi-ruang-lingkungan-inspirasi.png");], [#NormalTok("fig-3-5-energi-ruang-lingkungan-inspirasi");],
  [16], [Konversi Transaksional], [#NormalTok("figures/3-6-konversi-transaksional.png");], [#NormalTok("fig-3-6-konversi-transaksional");],
  [17], [Smart Engine Abstraction (SEA)], [#NormalTok("figures/4-0-smart-engine-abstraction-sea.png");], [#NormalTok("fig-4-0-smart-engine-abstraction-sea");],
  [18], [P: Stakeholder], [#NormalTok("figures/5-1-p-stakeholder.png");], [#NormalTok("fig-5-1-p-stakeholder");],
  [19], [I: Solusi Baru], [#NormalTok("figures/5-2-i-solusi-baru.png");], [#NormalTok("fig-5-2-i-solusi-baru");],
  [20], [Cx: Masalah Spesifik], [#NormalTok("figures/5-3-cx-masalah-spesifik.png");], [#NormalTok("fig-5-3-cx-masalah-spesifik");],
  [21], [P: Testbeds/Dataset], [#NormalTok("figures/6-1-p-testbeds-dataset.png");], [#NormalTok("fig-6-1-p-testbeds-dataset");],
  [22], [I: Arsitektur Sistem Cerdas], [#NormalTok("figures/6-2-i-arsitektur-sistem-cerdas.png");], [#NormalTok("fig-6-2-i-arsitektur-sistem-cerdas");],
  [23], [P: Energi Sumber/Data Mentah], [#NormalTok("figures/7-1-p-energi-sumber-data-mentah.png");], [#NormalTok("fig-7-1-p-energi-sumber-data-mentah");],
  [24], [I: Engine/Modul Teknologi], [#NormalTok("figures/7-2-i-engine-modul-teknologi.png");], [#NormalTok("fig-7-2-i-engine-modul-teknologi");],
  [25], [P: Fenomena/Prinsip Sains], [#NormalTok("figures/8-1-p-fenomena-prinsip-sains.png");], [#NormalTok("fig-8-1-p-fenomena-prinsip-sains");],
  [26], [I: Teori/Model Baru], [#NormalTok("figures/8-2-i-teori-model-baru.png");], [#NormalTok("fig-8-2-i-teori-model-baru");],
  [27], [Representasi Fakta & Aturan], [#NormalTok("figures/9-1-representasi-fakta-aturan.png");], [#NormalTok("fig-9-1-representasi-fakta-aturan");],
  [28], [Mesin Inferensi Logika], [#NormalTok("figures/9-2-mesin-inferensi-logika.png");], [#NormalTok("fig-9-2-mesin-inferensi-logika");],
  [29], [Pemetaan Komponen Ontologi], [#NormalTok("figures/9-3-pemetaan-komponen-ontologi.png");], [#NormalTok("fig-9-3-pemetaan-komponen-ontologi");],
  [30], [Pemrosesan Data], [#NormalTok("figures/10-1-pemrosesan-data.png");], [#NormalTok("fig-10-1-pemrosesan-data");],
  [31], [Antarmuka Pengguna], [#NormalTok("figures/10-2-antarmuka-pengguna.png");], [#NormalTok("fig-10-2-antarmuka-pengguna");],
  [32], [Orkestrasi Simulasi], [#NormalTok("figures/10-3-orkestrasi-simulasi.png");], [#NormalTok("fig-10-3-orkestrasi-simulasi");],
  [33], [PySWIP], [#NormalTok("figures/11-1-pyswip.png");], [#NormalTok("fig-11-1-pyswip");],
  [34], [Janus (SWI-Prolog)], [#NormalTok("figures/11-2-janus-swi-prolog.png");], [#NormalTok("fig-11-2-janus-swi-prolog");],
  [35], [PrologMQI], [#NormalTok("figures/11-3-prologmqi.png");], [#NormalTok("fig-11-3-prologmqi");],
  [36], [Skenario Bandung-Jakarta], [#NormalTok("figures/12-1-skenario-bandung-jakarta.png");], [#NormalTok("fig-12-1-skenario-bandung-jakarta");],
  [37], [Evaluasi Fleet EV vs Bus vs Kereta Cepat], [#NormalTok("figures/12-2-evaluasi-fleet-ev-vs-bus-vs-kereta-cepat.png");], [#NormalTok("fig-12-2-evaluasi-fleet-ev-vs-bus-vs-kereta-cepat");],
  [38], [Metrik: Waktu, Biaya, Emisi CO2], [#NormalTok("figures/12-3-metrik-waktu-biaya-emisi-co2.png");], [#NormalTok("fig-12-3-metrik-waktu-biaya-emisi-co2");],
)
= Gambar 1: Perceive (Persepsi)
<gambar-1-perceive-persepsi>
#figure([
#box(image("slide0.pdf", width: 80.0%))
], caption: figure.caption(
position: bottom, 
[
Gambar usulan untuk 1.1 Perceive (Persepsi): Diagram alur persepsi dari stimulus ke data terstruktur.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-1-1-perceive-persepsi>


  #image("slide0.pdf", page: 2)
#strong[Bab:] Sistem Cerdas & Siklus PUDAL

#strong[Section:] Perceive (Persepsi)

#strong[Nama file:] #NormalTok("figures/1-1-perceive-persepsi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-1-1-perceive-persepsi");

#strong[Baris rujukan di draft3.qmd:] 79

#strong[Caption:] Gambar usulan untuk 1.1 Perceive (Persepsi): Diagram alur persepsi dari stimulus ke data terstruktur.

#strong[Deskripsi singkat:] Gambar berupa diagram alur persepsi dari stimulus ke data terstruktur. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram alur persepsi dari stimulus ke data terstruktur. Konteks bab: 'Sistem Cerdas & Siklus PUDAL'. Konteks section: 'Perceive (Persepsi)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 2: Understand (Memahami)
<gambar-2-understand-memahami>
#strong[Bab:] Sistem Cerdas & Siklus PUDAL

#strong[Section:] Understand (Memahami)

#strong[Nama file:] #NormalTok("figures/1-2-understand-memahami.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-1-2-understand-memahami");

#strong[Baris rujukan di draft3.qmd:] 113

#strong[Caption:] Gambar usulan untuk 1.2 Understand (Memahami): Sketsa transformasi data mentah menjadi model konseptual.

#strong[Deskripsi singkat:] Gambar berupa sketsa transformasi data mentah menjadi model konseptual. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa transformasi data mentah menjadi model konseptual. Konteks bab: 'Sistem Cerdas & Siklus PUDAL'. Konteks section: 'Understand (Memahami)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 3: Decision (Keputusan)
<gambar-3-decision-keputusan>
#strong[Bab:] Sistem Cerdas & Siklus PUDAL

#strong[Section:] Decision (Keputusan)

#strong[Nama file:] #NormalTok("figures/1-3-decision-keputusan.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-1-3-decision-keputusan");

#strong[Baris rujukan di draft3.qmd:] 146

#strong[Caption:] Gambar usulan untuk 1.3 Decision (Keputusan): Diagram pohon keputusan sederhana dalam konteks sistem cerdas.

#strong[Deskripsi singkat:] Gambar berupa diagram pohon keputusan sederhana dalam konteks sistem cerdas. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram pohon keputusan sederhana dalam konteks sistem cerdas. Konteks bab: 'Sistem Cerdas & Siklus PUDAL'. Konteks section: 'Decision (Keputusan)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 4: Act (Tindakan)
<gambar-4-act-tindakan>
#strong[Bab:] Sistem Cerdas & Siklus PUDAL

#strong[Section:] Act (Tindakan)

#strong[Nama file:] #NormalTok("figures/1-4-act-tindakan.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-1-4-act-tindakan");

#strong[Baris rujukan di draft3.qmd:] 179

#strong[Caption:] Gambar usulan untuk 1.4 Act (Tindakan): Sketsa alur aksi dari rencana ke perubahan lingkungan.

#strong[Deskripsi singkat:] Gambar berupa sketsa alur aksi dari rencana ke perubahan lingkungan. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa alur aksi dari rencana ke perubahan lingkungan. Konteks bab: 'Sistem Cerdas & Siklus PUDAL'. Konteks section: 'Act (Tindakan)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 5: Learning (Belajar)
<gambar-5-learning-belajar>
#strong[Bab:] Sistem Cerdas & Siklus PUDAL

#strong[Section:] Learning (Belajar)

#strong[Nama file:] #NormalTok("figures/1-5-learning-belajar.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-1-5-learning-belajar");

#strong[Baris rujukan di draft3.qmd:] 212

#strong[Caption:] Gambar usulan untuk 1.5 Learning (Belajar): Diagram loop pembelajaran tertutup pada PUDAL.

#strong[Deskripsi singkat:] Gambar berupa diagram loop pembelajaran tertutup pada pudal. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram loop pembelajaran tertutup pada PUDAL. Konteks bab: 'Sistem Cerdas & Siklus PUDAL'. Konteks section: 'Learning (Belajar)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 6: Product (Produk)
<gambar-6-product-produk>
#strong[Bab:] Artefak PSKVE

#strong[Section:] Product (Produk)

#strong[Nama file:] #NormalTok("figures/2-1-product-produk.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-2-1-product-produk");

#strong[Baris rujukan di draft3.qmd:] 274

#strong[Caption:] Gambar usulan untuk 2.1 Product (Produk): Sketsa produk cerdas dengan label komponen utama.

#strong[Deskripsi singkat:] Gambar berupa sketsa produk cerdas dengan label komponen utama. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa produk cerdas dengan label komponen utama. Konteks bab: 'Artefak PSKVE'. Konteks section: 'Product (Produk)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 7: Service (Layanan)
<gambar-7-service-layanan>
#strong[Bab:] Artefak PSKVE

#strong[Section:] Service (Layanan)

#strong[Nama file:] #NormalTok("figures/2-2-service-layanan.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-2-2-service-layanan");

#strong[Baris rujukan di draft3.qmd:] 314

#strong[Caption:] Gambar usulan untuk 2.2 Service (Layanan): Diagram interaksi pengguna dengan layanan cerdas.

#strong[Deskripsi singkat:] Gambar berupa diagram interaksi pengguna dengan layanan cerdas. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram interaksi pengguna dengan layanan cerdas. Konteks bab: 'Artefak PSKVE'. Konteks section: 'Service (Layanan)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 8: Knowledge (Pengetahuan)
<gambar-8-knowledge-pengetahuan>
#strong[Bab:] Artefak PSKVE

#strong[Section:] Knowledge (Pengetahuan)

#strong[Nama file:] #NormalTok("figures/2-3-knowledge-pengetahuan.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-2-3-knowledge-pengetahuan");

#strong[Baris rujukan di draft3.qmd:] 356

#strong[Caption:] Gambar usulan untuk 2.3 Knowledge (Pengetahuan): Sketsa lapisan pengetahuan di dalam artefak cerdas.

#strong[Deskripsi singkat:] Gambar berupa sketsa lapisan pengetahuan di dalam artefak cerdas. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa lapisan pengetahuan di dalam artefak cerdas. Konteks bab: 'Artefak PSKVE'. Konteks section: 'Knowledge (Pengetahuan)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 9: Value (Nilai)
<gambar-9-value-nilai>
#strong[Bab:] Artefak PSKVE

#strong[Section:] Value (Nilai)

#strong[Nama file:] #NormalTok("figures/2-4-value-nilai.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-2-4-value-nilai");

#strong[Baris rujukan di draft3.qmd:] 394

#strong[Caption:] Gambar usulan untuk 2.4 Value (Nilai): Diagram panah konversi dari produk-layanan-pengetahuan menuju nilai.

#strong[Deskripsi singkat:] Gambar berupa diagram panah konversi dari produk-layanan-pengetahuan menuju nilai. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram panah konversi dari produk-layanan-pengetahuan menuju nilai. Konteks bab: 'Artefak PSKVE'. Konteks section: 'Value (Nilai)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 10: Environment (Lingkungan)
<gambar-10-environment-lingkungan>
#strong[Bab:] Artefak PSKVE

#strong[Section:] Environment (Lingkungan)

#strong[Nama file:] #NormalTok("figures/2-5-environment-lingkungan.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-2-5-environment-lingkungan");

#strong[Baris rujukan di draft3.qmd:] 431

#strong[Caption:] Gambar usulan untuk 2.5 Environment (Lingkungan): Sketsa artefak di dalam ruang lingkungan dengan jejak dampak.

#strong[Deskripsi singkat:] Gambar berupa sketsa artefak di dalam ruang lingkungan dengan jejak dampak. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa artefak di dalam ruang lingkungan dengan jejak dampak. Konteks bab: 'Artefak PSKVE'. Konteks section: 'Environment (Lingkungan)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 11: Energi Produk (Fisik)
<gambar-11-energi-produk-fisik>
#strong[Bab:] Energi Multi-Dimensi

#strong[Section:] Energi Produk (Fisik)

#strong[Nama file:] #NormalTok("figures/3-1-energi-produk-fisik.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-3-1-energi-produk-fisik");

#strong[Baris rujukan di draft3.qmd:] 490

#strong[Caption:] Gambar usulan untuk 3.1 Energi Produk (Fisik): Diagram alir energi fisik masuk-keluar.

#strong[Deskripsi singkat:] Gambar berupa diagram alir energi fisik masuk-keluar. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram alir energi fisik masuk-keluar. Konteks bab: 'Energi Multi-Dimensi'. Konteks section: 'Energi Produk (Fisik)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 12: Energi Layanan (Atensi)
<gambar-12-energi-layanan-atensi>
#strong[Bab:] Energi Multi-Dimensi

#strong[Section:] Energi Layanan (Atensi)

#strong[Nama file:] #NormalTok("figures/3-2-energi-layanan-atensi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-3-2-energi-layanan-atensi");

#strong[Baris rujukan di draft3.qmd:] 529

#strong[Caption:] Gambar usulan untuk 3.2 Energi Layanan (Atensi): Sketsa jam-atensi-interaksi pada layanan digital/fisik.

#strong[Deskripsi singkat:] Gambar berupa sketsa jam-atensi-interaksi pada layanan digital/fisik. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa jam-atensi-interaksi pada layanan digital/fisik. Konteks bab: 'Energi Multi-Dimensi'. Konteks section: 'Energi Layanan (Atensi)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 13: Energi Pengetahuan (Algoritma)
<gambar-13-energi-pengetahuan-algoritma>
#strong[Bab:] Energi Multi-Dimensi

#strong[Section:] Energi Pengetahuan (Algoritma)

#strong[Nama file:] #NormalTok("figures/3-3-energi-pengetahuan-algoritma.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-3-3-energi-pengetahuan-algoritma");

#strong[Baris rujukan di draft3.qmd:] 569

#strong[Caption:] Gambar usulan untuk 3.3 Energi Pengetahuan (Algoritma): Diagram alur data ke algoritma ke keputusan.

#strong[Deskripsi singkat:] Gambar berupa diagram alur data ke algoritma ke keputusan. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram alur data ke algoritma ke keputusan. Konteks bab: 'Energi Multi-Dimensi'. Konteks section: 'Energi Pengetahuan (Algoritma)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 14: Energi Nilai (Finansial/Sosial)
<gambar-14-energi-nilai-finansialsosial>
#strong[Bab:] Energi Multi-Dimensi

#strong[Section:] Energi Nilai (Finansial/Sosial)

#strong[Nama file:] #NormalTok("figures/3-4-energi-nilai-finansial-sosial.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-3-4-energi-nilai-finansial-sosial");

#strong[Baris rujukan di draft3.qmd:] 619

#strong[Caption:] Gambar usulan untuk 3.4 Energi Nilai (Finansial/Sosial): Sketsa pertukaran nilai antar pemangku kepentingan.

#strong[Deskripsi singkat:] Gambar berupa sketsa pertukaran nilai antar pemangku kepentingan. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa pertukaran nilai antar pemangku kepentingan. Konteks bab: 'Energi Multi-Dimensi'. Konteks section: 'Energi Nilai (Finansial/Sosial)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 15: Energi Ruang Lingkungan (Inspirasi)
<gambar-15-energi-ruang-lingkungan-inspirasi>
#strong[Bab:] Energi Multi-Dimensi

#strong[Section:] Energi Ruang Lingkungan (Inspirasi)

#strong[Nama file:] #NormalTok("figures/3-5-energi-ruang-lingkungan-inspirasi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-3-5-energi-ruang-lingkungan-inspirasi");

#strong[Baris rujukan di draft3.qmd:] 657

#strong[Caption:] Gambar usulan untuk 3.5 Energi Ruang Lingkungan (Inspirasi): Sketsa ruang kerja/layanan yang menginspirasi.

#strong[Deskripsi singkat:] Gambar berupa sketsa ruang kerja/layanan yang menginspirasi. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa ruang kerja/layanan yang menginspirasi. Konteks bab: 'Energi Multi-Dimensi'. Konteks section: 'Energi Ruang Lingkungan (Inspirasi)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 16: Konversi Transaksional
<gambar-16-konversi-transaksional>
#strong[Bab:] Energi Multi-Dimensi

#strong[Section:] Konversi Transaksional

#strong[Nama file:] #NormalTok("figures/3-6-konversi-transaksional.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-3-6-konversi-transaksional");

#strong[Baris rujukan di draft3.qmd:] 695

#strong[Caption:] Gambar usulan untuk 3.6 Konversi Transaksional: Diagram jaringan konversi antar dimensi energi.

#strong[Deskripsi singkat:] Gambar berupa diagram jaringan konversi antar dimensi energi. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram jaringan konversi antar dimensi energi. Konteks bab: 'Energi Multi-Dimensi'. Konteks section: 'Konversi Transaksional'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 17: Smart Engine Abstraction (SEA)
<gambar-17-smart-engine-abstraction-sea>
#strong[Bab:] Smart Engine Abstraction (SEA)

#strong[Section:] Smart Engine Abstraction (SEA)

#strong[Nama file:] #NormalTok("figures/4-0-smart-engine-abstraction-sea.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-4-0-smart-engine-abstraction-sea");

#strong[Baris rujukan di draft3.qmd:] 730

#strong[Caption:] Gambar usulan untuk 4.0 Smart Engine Abstraction (SEA): Diagram blok Smart Engine Abstraction sederhana.

#strong[Deskripsi singkat:] Gambar berupa diagram blok smart engine abstraction sederhana. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram blok Smart Engine Abstraction sederhana. Konteks bab: 'Smart Engine Abstraction (SEA)'. Konteks section: 'Smart Engine Abstraction (SEA)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 18: P: Stakeholder
<gambar-18-p-stakeholder>
#strong[Bab:] Domain Aplikasi (A)

#strong[Section:] P: Stakeholder

#strong[Nama file:] #NormalTok("figures/5-1-p-stakeholder.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-5-1-p-stakeholder");

#strong[Baris rujukan di draft3.qmd:] 814

#strong[Caption:] Gambar usulan untuk 5.1 P: Stakeholder: Peta aktor sederhana untuk domain aplikasi.

#strong[Deskripsi singkat:] Gambar berupa peta aktor sederhana untuk domain aplikasi. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Stakeholder: Peta aktor sederhana untuk domain aplikasi. Konteks bab: 'Domain Aplikasi (A)'. Konteks section: 'P: Stakeholder'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 19: I: Solusi Baru
<gambar-19-i-solusi-baru>
#strong[Bab:] Domain Aplikasi (A)

#strong[Section:] I: Solusi Baru

#strong[Nama file:] #NormalTok("figures/5-2-i-solusi-baru.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-5-2-i-solusi-baru");

#strong[Baris rujukan di draft3.qmd:] 849

#strong[Caption:] Gambar usulan untuk 5.2 I: Solusi Baru: Sketsa perbandingan dua atau tiga konsep solusi.

#strong[Deskripsi singkat:] Gambar berupa sketsa perbandingan dua atau tiga konsep solusi. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Solusi Baru: Sketsa perbandingan dua atau tiga konsep solusi. Konteks bab: 'Domain Aplikasi (A)'. Konteks section: 'I: Solusi Baru'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 20: Cx: Masalah Spesifik
<gambar-20-cx-masalah-spesifik>
#strong[Bab:] Domain Aplikasi (A)

#strong[Section:] Cx: Masalah Spesifik

#strong[Nama file:] #NormalTok("figures/5-3-cx-masalah-spesifik.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-5-3-cx-masalah-spesifik");

#strong[Baris rujukan di draft3.qmd:] 884

#strong[Caption:] Gambar usulan untuk 5.3 Cx: Masalah Spesifik: Diagram sebab-akibat masalah spesifik.

#strong[Deskripsi singkat:] Gambar berupa diagram sebab-akibat masalah spesifik. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Masalah Spesifik: Diagram sebab-akibat masalah spesifik. Konteks bab: 'Domain Aplikasi (A)'. Konteks section: 'Cx: Masalah Spesifik'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 21: P: Testbeds/Dataset
<gambar-21-p-testbedsdataset>
#strong[Bab:] Domain Sistem (S)

#strong[Section:] P: Testbeds/Dataset

#strong[Nama file:] #NormalTok("figures/6-1-p-testbeds-dataset.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-6-1-p-testbeds-dataset");

#strong[Baris rujukan di draft3.qmd:] 942

#strong[Caption:] Gambar usulan untuk 6.1 P: Testbeds/Dataset: Sketsa lingkungan uji atau alur dataset ke eksperimen.

#strong[Deskripsi singkat:] Gambar berupa sketsa lingkungan uji atau alur dataset ke eksperimen. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Testbeds/Dataset: Sketsa lingkungan uji atau alur dataset ke eksperimen. Konteks bab: 'Domain Sistem (S)'. Konteks section: 'P: Testbeds/Dataset'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 22: I: Arsitektur Sistem Cerdas
<gambar-22-i-arsitektur-sistem-cerdas>
#strong[Bab:] Domain Sistem (S)

#strong[Section:] I: Arsitektur Sistem Cerdas

#strong[Nama file:] #NormalTok("figures/6-2-i-arsitektur-sistem-cerdas.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-6-2-i-arsitektur-sistem-cerdas");

#strong[Baris rujukan di draft3.qmd:] 981

#strong[Caption:] Gambar usulan untuk 6.2 I: Arsitektur Sistem Cerdas: Diagram arsitektur sistem cerdas modular.

#strong[Deskripsi singkat:] Gambar berupa diagram arsitektur sistem cerdas modular. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Arsitektur Sistem Cerdas: Diagram arsitektur sistem cerdas modular. Konteks bab: 'Domain Sistem (S)'. Konteks section: 'I: Arsitektur Sistem Cerdas'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 23: P: Energi Sumber/Data Mentah
<gambar-23-p-energi-sumberdata-mentah>
#strong[Bab:] Domain Teknologi (T)

#strong[Section:] P: Energi Sumber/Data Mentah

#strong[Nama file:] #NormalTok("figures/7-1-p-energi-sumber-data-mentah.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-7-1-p-energi-sumber-data-mentah");

#strong[Baris rujukan di draft3.qmd:] 1047

#strong[Caption:] Gambar usulan untuk 7.1 P: Energi Sumber/Data Mentah: Sketsa sumber data mentah yang masuk ke engine.

#strong[Deskripsi singkat:] Gambar berupa sketsa sumber data mentah yang masuk ke engine. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Energi Sumber/Data Mentah: Sketsa sumber data mentah yang masuk ke engine. Konteks bab: 'Domain Teknologi (T)'. Konteks section: 'P: Energi Sumber/Data Mentah'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 24: I: Engine/Modul Teknologi
<gambar-24-i-enginemodul-teknologi>
#strong[Bab:] Domain Teknologi (T)

#strong[Section:] I: Engine/Modul Teknologi

#strong[Nama file:] #NormalTok("figures/7-2-i-engine-modul-teknologi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-7-2-i-engine-modul-teknologi");

#strong[Baris rujukan di draft3.qmd:] 1081

#strong[Caption:] Gambar usulan untuk 7.2 I: Engine/Modul Teknologi: Diagram modul teknologi yang saling terhubung.

#strong[Deskripsi singkat:] Gambar berupa diagram modul teknologi yang saling terhubung. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Engine/Modul Teknologi: Diagram modul teknologi yang saling terhubung. Konteks bab: 'Domain Teknologi (T)'. Konteks section: 'I: Engine/Modul Teknologi'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 25: P: Fenomena/Prinsip Sains
<gambar-25-p-fenomenaprinsip-sains>
#strong[Bab:] Domain Riset Fundamental (F)

#strong[Section:] P: Fenomena/Prinsip Sains

#strong[Nama file:] #NormalTok("figures/8-1-p-fenomena-prinsip-sains.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-8-1-p-fenomena-prinsip-sains");

#strong[Baris rujukan di draft3.qmd:] 1140

#strong[Caption:] Gambar usulan untuk 8.1 P: Fenomena/Prinsip Sains: Sketsa fenomena ilmiah yang mendasari sistem.

#strong[Deskripsi singkat:] Gambar berupa sketsa fenomena ilmiah yang mendasari sistem. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Fenomena/Prinsip Sains: Sketsa fenomena ilmiah yang mendasari sistem. Konteks bab: 'Domain Riset Fundamental (F)'. Konteks section: 'P: Fenomena/Prinsip Sains'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 26: I: Teori/Model Baru
<gambar-26-i-teorimodel-baru>
#strong[Bab:] Domain Riset Fundamental (F)

#strong[Section:] I: Teori/Model Baru

#strong[Nama file:] #NormalTok("figures/8-2-i-teori-model-baru.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-8-2-i-teori-model-baru");

#strong[Baris rujukan di draft3.qmd:] 1180

#strong[Caption:] Gambar usulan untuk 8.2 I: Teori/Model Baru: Diagram model konseptual baru berbasis teori.

#strong[Deskripsi singkat:] Gambar berupa diagram model konseptual baru berbasis teori. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Teori/Model Baru: Diagram model konseptual baru berbasis teori. Konteks bab: 'Domain Riset Fundamental (F)'. Konteks section: 'I: Teori/Model Baru'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 27: Representasi Fakta & Aturan
<gambar-27-representasi-fakta-aturan>
#strong[Bab:] Prolog (Penalaran Simbolik)

#strong[Section:] Representasi Fakta & Aturan

#strong[Nama file:] #NormalTok("figures/9-1-representasi-fakta-aturan.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-9-1-representasi-fakta-aturan");

#strong[Baris rujukan di draft3.qmd:] 1263

#strong[Caption:] Gambar usulan untuk 9.1 Representasi Fakta & Aturan: Sketsa basis pengetahuan Prolog yang sederhana.

#strong[Deskripsi singkat:] Gambar berupa sketsa basis pengetahuan prolog yang sederhana. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa basis pengetahuan Prolog yang sederhana. Konteks bab: 'Prolog (Penalaran Simbolik)'. Konteks section: 'Representasi Fakta & Aturan'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 28: Mesin Inferensi Logika
<gambar-28-mesin-inferensi-logika>
#strong[Bab:] Prolog (Penalaran Simbolik)

#strong[Section:] Mesin Inferensi Logika

#strong[Nama file:] #NormalTok("figures/9-2-mesin-inferensi-logika.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-9-2-mesin-inferensi-logika");

#strong[Baris rujukan di draft3.qmd:] 1303

#strong[Caption:] Gambar usulan untuk 9.2 Mesin Inferensi Logika: Diagram query-inferensi-jawaban dalam Prolog.

#strong[Deskripsi singkat:] Gambar berupa diagram query-inferensi-jawaban dalam prolog. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram query-inferensi-jawaban dalam Prolog. Konteks bab: 'Prolog (Penalaran Simbolik)'. Konteks section: 'Mesin Inferensi Logika'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 29: Pemetaan Komponen Ontologi
<gambar-29-pemetaan-komponen-ontologi>
#strong[Bab:] Prolog (Penalaran Simbolik)

#strong[Section:] Pemetaan Komponen Ontologi

#strong[Nama file:] #NormalTok("figures/9-3-pemetaan-komponen-ontologi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-9-3-pemetaan-komponen-ontologi");

#strong[Baris rujukan di draft3.qmd:] 1341

#strong[Caption:] Gambar usulan untuk 9.3 Pemetaan Komponen Ontologi: Sketsa jembatan ontologi ke basis pengetahuan simbolik.

#strong[Deskripsi singkat:] Gambar berupa sketsa jembatan ontologi ke basis pengetahuan simbolik. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa jembatan ontologi ke basis pengetahuan simbolik. Konteks bab: 'Prolog (Penalaran Simbolik)'. Konteks section: 'Pemetaan Komponen Ontologi'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 30: Pemrosesan Data
<gambar-30-pemrosesan-data>
#strong[Bab:] Python (Algoritma & Aplikasi)

#strong[Section:] Pemrosesan Data

#strong[Nama file:] #NormalTok("figures/10-1-pemrosesan-data.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-10-1-pemrosesan-data");

#strong[Baris rujukan di draft3.qmd:] 1398

#strong[Caption:] Gambar usulan untuk 10.1 Pemrosesan Data: Diagram pipeline data Python.

#strong[Deskripsi singkat:] Gambar berupa diagram pipeline data python. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram pipeline data Python. Konteks bab: 'Python (Algoritma & Aplikasi)'. Konteks section: 'Pemrosesan Data'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 31: Antarmuka Pengguna
<gambar-31-antarmuka-pengguna>
#strong[Bab:] Python (Algoritma & Aplikasi)

#strong[Section:] Antarmuka Pengguna

#strong[Nama file:] #NormalTok("figures/10-2-antarmuka-pengguna.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-10-2-antarmuka-pengguna");

#strong[Baris rujukan di draft3.qmd:] 1434

#strong[Caption:] Gambar usulan untuk 10.2 Antarmuka Pengguna: Sketsa layar antarmuka pengguna sederhana.

#strong[Deskripsi singkat:] Gambar berupa sketsa layar antarmuka pengguna sederhana. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa layar antarmuka pengguna sederhana. Konteks bab: 'Python (Algoritma & Aplikasi)'. Konteks section: 'Antarmuka Pengguna'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 32: Orkestrasi Simulasi
<gambar-32-orkestrasi-simulasi>
#strong[Bab:] Python (Algoritma & Aplikasi)

#strong[Section:] Orkestrasi Simulasi

#strong[Nama file:] #NormalTok("figures/10-3-orkestrasi-simulasi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-10-3-orkestrasi-simulasi");

#strong[Baris rujukan di draft3.qmd:] 1469

#strong[Caption:] Gambar usulan untuk 10.3 Orkestrasi Simulasi: Diagram orkestrasi simulasi multi-modul.

#strong[Deskripsi singkat:] Gambar berupa diagram orkestrasi simulasi multi-modul. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram orkestrasi simulasi multi-modul. Konteks bab: 'Python (Algoritma & Aplikasi)'. Konteks section: 'Orkestrasi Simulasi'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 33: PySWIP
<gambar-33-pyswip>
#strong[Bab:] Bridge Libraries

#strong[Section:] PySWIP

#strong[Nama file:] #NormalTok("figures/11-1-pyswip.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-11-1-pyswip");

#strong[Baris rujukan di draft3.qmd:] 1532

#strong[Caption:] Gambar usulan untuk 11.1 PySWIP: Sketsa arsitektur Python-PySWIP-Prolog.

#strong[Deskripsi singkat:] Gambar berupa sketsa arsitektur python-pyswip-prolog. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa arsitektur Python-PySWIP-Prolog. Konteks bab: 'Bridge Libraries'. Konteks section: 'PySWIP'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 34: Janus (SWI-Prolog)
<gambar-34-janus-swi-prolog>
#strong[Bab:] Bridge Libraries

#strong[Section:] Janus (SWI-Prolog)

#strong[Nama file:] #NormalTok("figures/11-2-janus-swi-prolog.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-11-2-janus-swi-prolog");

#strong[Baris rujukan di draft3.qmd:] 1574

#strong[Caption:] Gambar usulan untuk 11.2 Janus (SWI-Prolog): Sketsa pertukaran data dua arah Python-Janus-Prolog.

#strong[Deskripsi singkat:] Gambar berupa sketsa pertukaran data dua arah python-janus-prolog. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa pertukaran data dua arah Python-Janus-Prolog. Konteks bab: 'Bridge Libraries'. Konteks section: 'Janus (SWI-Prolog)'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 35: PrologMQI
<gambar-35-prologmqi>
#strong[Bab:] Bridge Libraries

#strong[Section:] PrologMQI

#strong[Nama file:] #NormalTok("figures/11-3-prologmqi.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-11-3-prologmqi");

#strong[Baris rujukan di draft3.qmd:] 1607

#strong[Caption:] Gambar usulan untuk 11.3 PrologMQI: Diagram koneksi klien ke server Prolog melalui MQI.

#strong[Deskripsi singkat:] Gambar berupa diagram koneksi klien ke server prolog melalui mqi. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Diagram koneksi klien ke server Prolog melalui MQI. Konteks bab: 'Bridge Libraries'. Konteks section: 'PrologMQI'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 36: Skenario Bandung-Jakarta
<gambar-36-skenario-bandung-jakarta>
#strong[Bab:] Studi Kasus: Transportasi 2030

#strong[Section:] Skenario Bandung-Jakarta

#strong[Nama file:] #NormalTok("figures/12-1-skenario-bandung-jakarta.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-12-1-skenario-bandung-jakarta");

#strong[Baris rujukan di draft3.qmd:] 1690

#strong[Caption:] Gambar usulan untuk 12.1 Skenario Bandung-Jakarta: Peta garis sederhana koridor Bandung-Jakarta.

#strong[Deskripsi singkat:] Gambar berupa peta garis sederhana koridor bandung-jakarta. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Peta garis sederhana koridor Bandung-Jakarta. Konteks bab: 'Studi Kasus: Transportasi 2030'. Konteks section: 'Skenario Bandung-Jakarta'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 37: Evaluasi Fleet EV vs Bus vs Kereta Cepat
<gambar-37-evaluasi-fleet-ev-vs-bus-vs-kereta-cepat>
#strong[Bab:] Studi Kasus: Transportasi 2030

#strong[Section:] Evaluasi Fleet EV vs Bus vs Kereta Cepat

#strong[Nama file:] #NormalTok("figures/12-2-evaluasi-fleet-ev-vs-bus-vs-kereta-cepat.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-12-2-evaluasi-fleet-ev-vs-bus-vs-kereta-cepat");

#strong[Baris rujukan di draft3.qmd:] 1743

#strong[Caption:] Gambar usulan untuk 12.2 Evaluasi Fleet EV vs Bus vs Kereta Cepat: Sketsa tiga moda transportasi berdampingan.

#strong[Deskripsi singkat:] Gambar berupa sketsa tiga moda transportasi berdampingan. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Sketsa tiga moda transportasi berdampingan. Konteks bab: 'Studi Kasus: Transportasi 2030'. Konteks section: 'Evaluasi Fleet EV vs Bus vs Kereta Cepat'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.

= Gambar 38: Metrik: Waktu, Biaya, Emisi CO2
<gambar-38-metrik-waktu-biaya-emisi-co2>
#strong[Bab:] Studi Kasus: Transportasi 2030

#strong[Section:] Metrik: Waktu, Biaya, Emisi CO2

#strong[Nama file:] #NormalTok("figures/12-3-metrik-waktu-biaya-emisi-co2.png");

#strong[Label rujukan dalam teks:] #NormalTok("fig-12-3-metrik-waktu-biaya-emisi-co2");

#strong[Baris rujukan di draft3.qmd:] 1792

#strong[Caption:] Gambar usulan untuk 12.3 Metrik: Waktu, Biaya, Emisi CO2: Sketsa tiga sumbu evaluasi: waktu, biaya, emisi.

#strong[Deskripsi singkat:] Gambar berupa sketsa tiga sumbu evaluasi: waktu, biaya, emisi. dalam gaya sketsa pena hitam di atas latar putih, sederhana, bersih, dan mudah dibaca.

#strong[Prompt lengkap untuk Nano Banana Pro:]

#Skylighting(([#NormalTok("Buat satu ilustrasi untuk buku akademik teknik. Subjek utama: Waktu, Biaya, Emisi CO2: Sketsa tiga sumbu evaluasi: waktu, biaya, emisi. Konteks bab: 'Studi Kasus: Transportasi 2030'. Konteks section: 'Metrik: Waktu, Biaya, Emisi CO2'. Susun gambar sebagai diagram konsep atau skema penjelas, bukan ilustrasi artistik bebas. Pastikan inti gagasan pada section tersebut langsung terbaca hanya dari bentuk, alur panah, pengelompokan blok, dan ikon-ikon sederhana. Berikan ruang kosong yang cukup di sekeliling elemen utama agar nyaman ditempatkan di halaman buku. Gaya visual wajib: ilustrasi line-art akademik, latar putih polos, tinta/pena hitam saja, tanpa warna, tanpa gradasi, tanpa bayangan berat, tanpa tekstur kertas, tanpa latar dekoratif. Komposisi bersih, seimbang, minimalis, mudah dibaca pada ukuran cetak buku. Gunakan bentuk geometris sederhana, ikon teknik, panah, node, blok, kotak, lingkaran, dan label singkat bila perlu. Semua teks di dalam gambar harus sangat sedikit, cukup 1–5 label pendek yang jelas dan dapat dibaca. Hindari wajah realistis, detail anatomi rumit, perspektif dramatis, ornamen berlebihan, dan elemen fotorealistik. Utamakan fungsi edukatif, kejelasan konsep, dan keterbacaan hitam-putih. Boleh gunakan orientasi lanskap bila diagram alur lebih jelas, atau potret bila struktur bertingkat lebih sesuai. Gunakan ketebalan garis konsisten, dengan hirarki visual ringan antara elemen utama dan elemen pendukung. Bila ada panah, buat panah sederhana dan tegas. Bila ada ikon, gunakan ikon universal yang sangat sederhana. Hasil akhir harus tampak seperti gambar pena hitam yang rapi untuk buku kuliah atau monograf teknik. Jangan gunakan warna, jangan gunakan latar abu-abu, jangan gunakan efek 3D, jangan gunakan shading tebal, jangan gunakan tekstur kompleks, jangan gunakan elemen dekoratif yang tidak relevan, dan jangan memenuhi gambar dengan detail kecil.");],));
#strong[Catatan produksi:] - Pastikan rasio aspek menyesuaikan kebutuhan layout buku. - Simpan hasil akhir dengan nama file persis seperti yang dirujuk di atas. - Jaga konsistensi gaya dengan gambar lain dalam buku.
