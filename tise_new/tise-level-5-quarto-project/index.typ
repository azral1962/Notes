// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
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

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
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
  }

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
// IN HEADER!!!


#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "iso-b5",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Buku DNA TISE level 5],
  subtitle: [Monograf Template untuk Rekayasawan, Stakeholder, dan Agents],
  author: "Armein Z. R. Langi",
  lang: "id",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// IN BEFORE !!!
#set text(
  font: "New Computer Modern", // Font family name
  size: 12pt, // Font size
)
// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Prakata]
<prakata>
Monograf ini disusun sebagai #strong[Buku DNA] bagi TISE level 5. Artinya, buku ini bukan hanya menjelaskan teori, tetapi juga dimaksudkan menjadi rujukan kerja bersama bagi rekayasawan, stakeholder, dan agents yang ingin mewujudkan konfigurasi solusi kemanusiaan secara nyata. Dalam kerangka ini, TISE level 5 dipahami sebagai level rekayasa di mana persoalan kemanusiaan dihadapi melalui pembentukan, penguatan, dan pengoperasian konfigurasi stakeholder bermisi.

Agar efektif, Buku DNA ini harus menjalankan dua fungsi sekaligus. Pertama, ia harus menjadi #strong[rujukan konseptual] yang menjelaskan bagaimana evolusi rekayasa bergerak dari TISE level 0 sampai TISE level 5. Kedua, ia harus menjadi #strong[alat peningkatan readiness], karena dalam kenyataan inovasi TISE level 5 hanya dapat diwujudkan bila para stakeholder bertumbuh dalam kesadaran identitas naratif, kejelasan misi, kompetensi, motivasi, komitmen, dan kemampuan membaca peluang kontribusi.

Karena itu, monograf ini direstruktur sebagai template bertingkat. Setelah pendahuluan yang memberi tinjauan umum atas keseluruhan konsep, pembahasan utama disusun dari #strong[Part 1 yang berfokus pada rekayasa TISE level 5], kemudian turun bertahap ke #strong[Part 2 untuk TISE level 4], #strong[Part 3 untuk TISE level 3], #strong[Part 4 untuk TISE level 2], #strong[Part 5 untuk TISE level 1], dan #strong[Part 6 untuk TISE level 0]. Di bagian akhir, monograf ini memberikan rangkuman keseluruhan, arah pengembangan berikutnya, serta lampiran teknis berupa daftar pertanyaan per level yang perlu dijawab oleh para stakeholder. Kumpulan jawaban itu kemudian dapat diolah oleh agents untuk menghasilkan #strong[Dokumen DNA] yang, bila dijalankan oleh para stakeholder, akan membantu mewujudkan visi konfigurasi terbaik.

#heading(level: 1, numbering: none)[Abstrak]
<abstrak>
Monograf ini merumuskan #strong[TISE level 5] sebagai level tertinggi dalam hirarki rekayasa TISE, yaitu level di mana rekayasa berfokus pada pembentukan konfigurasi stakeholder bermisi untuk memecahkan persoalan kemanusiaan. Argumen utama monograf ini adalah bahwa persoalan manusia abad ke-21 tidak cukup dipahami hanya sebagai persoalan energi, material, dan informasi, tetapi perlu dipandang sebagai persoalan mobilisasi potensi manusia, readiness stakeholder, distribusi benefit, legitimasi regulatif, operasi solusi, dan pengorganisasian misi secara kolektif.

Untuk itu, monograf ini disusun sebagai #strong[Buku DNA]. Setelah memberikan tinjauan umum tentang keseluruhan konsep, buku ini membahas rekayasa secara bertingkat dari #strong[TISE level 5] sampai #strong[TISE level 0]. Pada TISE level 5, mesin utamanya adalah #strong[Matrix of Mission] dan siklus operasionalnya adalah #strong[MOS-7]. Pada level-level di bawahnya, solusi diturunkan secara bertahap menjadi rekayasa DNA desain, rekayasa identitas naratif, rekayasa agentik PUDAL, rekayasa smart engine PSKVE, dan akhirnya rekayasa tradisional berbasis core engine.

Monograf ini juga menegaskan bahwa keberhasilan inovasi TISE level 5 bergantung pada #strong[peningkatan readiness stakeholder]. Karena itu, edukasi, training, coaching, dan pembelajaran berkelanjutan diposisikan sebagai bagian inheren dari rekayasa. Sebagai keluaran operasional, buku ini dilengkapi dengan lampiran teknis berupa daftar pertanyaan per level. Jawaban para stakeholder atas pertanyaan-pertanyaan ini diproses oleh agents untuk menghasilkan #strong[Dokumen DNA] yang memuat daftar tujuan pada berbagai level dan cara para stakeholder mencapainya.

Dengan demikian, monograf ini berfungsi sekaligus sebagai fondasi konseptual, template rekayasa, alat peningkatan readiness, dan kerangka pembentukan pusat keunggulan TISE level 5.

#strong[Kata kunci:] TISE level 5, Buku DNA, Matrix of Mission, MOS-7, readiness stakeholder, rekayasa kemanusiaan, PSKVE, PUDAL.

#heading(level: 1, numbering: none)[Bab 1. Pendahuluan: Tinjauan Umum atas Buku DNA TISE]
<bab-1.-pendahuluan-tinjauan-umum-atas-buku-dna-tise>
#heading(level: 2, numbering: none)[Mengapa Buku DNA Diperlukan]
<mengapa-buku-dna-diperlukan>
Dalam praktik, inovasi TISE level 5 tidak lahir hanya dari rancangan teoretis, tetapi dari kemampuan banyak pihak untuk membaca visi bersama, memahami perannya, serta menjalankan kontribusinya secara serempak. Karena itu, monograf ini perlu berfungsi seperti #strong[DNA], yaitu sebagai naskah acuan yang dapat dibaca bersama oleh para stakeholder. Buku ini adalah bagian dari #strong[proses peningkatan readiness] itu sendiri.

TISE level 5 memobilisasi para stakeholder agar bersama-sama menjalankan bagiannya untuk mewujudkan misi masing-masing. Namun, konfigurasi stakeholder dan #emph[arrangement] yang mungkin dibentuk biasanya tidak unik. Beberapa konfigurasi dapat sama-sama layak. Karena itu, rekayasa TISE level 5 memerlukan penetapan #strong[visi konfigurasi terbaik], yaitu konfigurasi yang paling feasible, paling adil, paling produktif, dan paling bermakna bagi keseluruhan sistem.

#heading(level: 2, numbering: none)[Fungsi Ganda Monograf]
<fungsi-ganda-monograf>
Monograf ini menjalankan fungsi ganda:

+ sebagai #strong[rujukan konseptual] tentang evolusi rekayasa dari TISE level 0 sampai TISE level 5;
+ sebagai #strong[template DNA] yang dapat dipakai ulang oleh rekayasawan;
+ sebagai #strong[instrumen peningkatan readiness stakeholder]\;
+ sebagai #strong[sumber pertanyaan teknis] yang dapat dijawab oleh stakeholder;
+ sebagai #strong[bahan mentah bagi agents] untuk menyusun Dokumen DNA operasional.

#heading(level: 2, numbering: none)[Struktur Buku]
<struktur-buku>
Struktur buku ini sengaja disusun dari atas ke bawah. Setelah bab pendahuluan yang memberi gambaran utuh, bagian utama dimulai dari TISE level 5 sebagai level tertinggi, lalu turun bertahap sampai TISE level 0. Susunan ini dipilih karena dalam praktik rekayasa kemanusiaan, orientasi solusi harus berangkat dari level tertinggi, yaitu level misi, konfigurasi stakeholder, dan visi sistem, lalu diterjemahkan bertahap ke level yang lebih rendah sampai ke mesin teknis.

Pembagian hirarkis ini memiliki satu benang merah rekayasa yang sama, yaitu #strong[memobilisasi sumber daya yang melimpah untuk dikonversikan menjadi kerja secara terkendali sehingga menghasilkan nilai yang berharga]. Nilai itu dapat hadir sebagai kemampuan untuk mencapai output, behavior, fungsi, target, tujuan, atau misi yang diinginkan. Dalam kerangka ini, level-level yang lebih tinggi memberikan #strong[konteks, arah, dan motivasi], sedangkan level-level yang lebih rendah memberikan #strong[tumpuan realitas, keterlaksanaan, dan keandalan]. Karena itu, seluruh hirarki TISE perlu dibaca bukan sebagai pecahan-pecahan yang terpisah, melainkan sebagai satu rantai rekayasa yang utuh dari visi sampai realisasi.

#heading(level: 2, numbering: none)[Posisi terhadap Literatur]
<posisi-terhadap-literatur>
Secara literatur, monograf ini berdiri di atas tradisi Product-Service Systems (PSS), stakeholder motivation matrix, multi-stakeholder requirements, dan stakeholder engagement @morelli2002@vezzoli2014@berkovich2014@sholihah2019@giordano2018@lievens2021. Namun, monograf ini melangkah lebih jauh dengan memindahkan fokus dari motivasi ke #strong[misi], dari peta aktor ke #strong[konfigurasi stakeholder], dan dari alat representasi ke #strong[Buku DNA] yang membimbing pembentukan solusi secara bertingkat.

= Part 1. Rekayasa TISE level 5
<part-1.-rekayasa-tise-level-5>
= Bab 2. TISE level 5 sebagai Pusat Keunggulan Rekayasa
<bab-2.-tise-level-5-sebagai-pusat-keunggulan-rekayasa>
== Definisi TISE level 5
<definisi-tise-level-5>
#strong[TISE level 5] adalah level rekayasa di mana TISE hadir sebagai pusat keunggulan yang memobilisasi stakeholder bermisi, agents, dan artefak cerdas untuk memecahkan persoalan kemanusiaan melalui konfigurasi stakeholder, Matrix of Mission, dan MOS-7.

== Misi Utama
<misi-utama>
Misi utama TISE level 5 adalah #strong[memobilisasi potensi manusia yang berlimpah untuk memecahkan persoalan kemanusiaan]. Dengan demikian, TISE level 5 tidak hanya membangun solusi bagi manusia, tetapi juga membuka medan kerja baru bagi manusia.

== Visi Konfigurasi Terbaik
<visi-konfigurasi-terbaik>
Karena konfigurasi stakeholder dan #emph[arrangement] solusi tidak unik, TISE level 5 harus berangkat dari sebuah #strong[visi konfigurasi terbaik]. Visi ini menyatakan bentuk konfigurasi stakeholder yang ingin diwujudkan, jenis hubungan yang perlu dibangun, bentuk value exchange yang diinginkan, serta keadaan akhir yang dipandang layak dan bermakna.

== Stakeholder Readiness
<stakeholder-readiness>
Dalam kenyataan, inovasi TISE level 5 memerlukan peningkatan level readiness dari stakeholder. Karena itu, rekayasa pada level ini harus mencakup proses peningkatan:

- kesadaran atas identitas naratif;
- kemampuan memformulasikan misi;
- kompetensi;
- motivasi;
- tingkat komitmen;
- kemampuan membaca opportunity.

Dengan demikian, edukasi, training, coaching, dan pembelajaran terus-menerus merupakan bagian inheren dari TISE level 5. TISE level 5 tidak boleh dipahami hanya sebagai rekayasa konfigurasi sosial, tetapi juga sebagai rekayasa #strong[pertumbuhan manusia di dalam konfigurasi tersebut].

= Bab 3. Matrix of Mission, MOS-7, dan Stakeholder Readiness
<bab-3.-matrix-of-mission-mos-7-dan-stakeholder-readiness>
== Matrix of Mission
<matrix-of-mission>
#strong[Matrix of Mission] adalah mesin utama TISE level 5. Pada diagonal utama, tiap stakeholder memuat misi yang perlu dijalankan dan benefit yang diharapkan. Pada sel non-diagonal, dimuat kontribusi yang diberikan satu stakeholder kepada stakeholder lain demi menopang terpenuhinya misi masing-masing.

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([], [A / USER], [B / SOURCE], [C / REGULATOR], [D / PROVIDER],),
  table.hline(),
  [1 / USER], [Misi USER; Benefit USER], [Kontribusi USER ke SOURCE], [Kontribusi USER ke REGULATOR], [Kontribusi USER ke PROVIDER],
  [2 / SOURCE], [Kontribusi SOURCE ke USER], [Misi SOURCE; Benefit SOURCE], [Kontribusi SOURCE ke REGULATOR], [Kontribusi SOURCE ke PROVIDER],
  [3 / REGULATOR], [Kontribusi REGULATOR ke USER], [Kontribusi REGULATOR ke SOURCE], [Misi REGULATOR; Benefit REGULATOR], [Kontribusi REGULATOR ke PROVIDER],
  [4 / PROVIDER], [Kontribusi PROVIDER ke USER], [Kontribusi PROVIDER ke SOURCE], [Kontribusi PROVIDER ke REGULATOR], [Misi PROVIDER; Benefit PROVIDER],
)
== Tipologi Stakeholder
<tipologi-stakeholder>
TISE level 5 mengelompokkan stakeholder ke dalam empat tipe utama: #strong[USER], #strong[SOURCE], #strong[REGULATOR], dan #strong[PROVIDER].

== Stakeholder Readiness Framework
<stakeholder-readiness-framework>
Sebagai pelengkap Matrix of Mission, monograf ini mengusulkan #strong[Stakeholder Readiness Framework]. Framework ini memeriksa kesiapan stakeholder pada enam dimensi:

+ #strong[Narrative readiness]\;
+ #strong[Mission readiness]\;
+ #strong[Competency readiness]\;
+ #strong[Motivational readiness]\;
+ #strong[Commitment readiness]\;
+ #strong[Opportunity readiness].

Keenam dimensi ini penting karena konfigurasi terbaik di atas kertas belum tentu dapat berjalan dalam kenyataan bila para stakeholder belum cukup siap untuk menjalankan bagian mereka. Dengan kata lain, Matrix of Mission memetakan #strong[arsitektur kontribusi], sedangkan Stakeholder Readiness Framework memetakan #strong[arsitektur kesiapan].

== MOS-7 sebagai Siklus Operasional
<mos-7-sebagai-siklus-operasional>
MOS-7 adalah siklus rekayasa stakeholder bermisi yang terdiri dari tujuh langkah:

+ Hear / Identify;
+ Model / Discern;
+ Design / Formulate;
+ Commit / Seek;
+ Build / Co-Create;
+ Operate / Delivery;
+ Evaluate-Audit / Protect.

Struktur ini mempertahankan roh transformasional MOS-7 sebagai siklus yang dimulai dari pendengaran terhadap keluhan manusia, bergerak menuju pembentukan respons yang relevan, lalu berakhir pada penjagaan integritas dan audit misi.

= Bab 4. Workflow Rekayasa TISE level 5 Full-Scale
<bab-4.-workflow-rekayasa-tise-level-5-full-scale>
== Fase Linear
<fase-linear>
Workflow TISE level 5 terdiri dari enam fase linear:

+ Persepsi Masalah;
+ Konsep dan Model;
+ Desain dan Planning;
+ Konstruksi;
+ Operasional;
+ Evaluasi.

Untuk menjawab kebutuhan pada setiap fase, MOS-7 diputar berkali-kali. Karena itu, metodologi TISE level 5 bersifat #strong[linear pada tingkat fase, tetapi siklik pada tingkat operasi].

== Tabel Workflow Full-Scale
<tabel-workflow-full-scale>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Fase Linear], [Fokus Utama], [Putaran MOS-7 yang Dominan], [Level TISE yang Paling Dominan], [Keluaran Utama],),
  table.hline(),
  [Persepsi Masalah], [Mendengar keluhan dan mengidentifikasi stakeholder], [Hear, Model], [TISE level 5], [Rumusan persoalan, alternatif konfigurasi],
  [Konsep dan Model], [Memilih konfigurasi terbaik], [Hear, Model, Design, Commit], [TISE level 5 dan 4], [Matrix of Mission terpilih, arah platform],
  [Desain dan Planning], [Menurunkan kebutuhan ke level 4--0], [Design, Commit, Build], [TISE level 4, 3, 2, 1], [DNA platform, desain naratif, PUDAL, PSKVE],
  [Konstruksi], [Membangun atau memodifikasi elemen], [Build, Commit, Operate], [TISE level 4 sampai 0], [Artefak anak, layanan, elemen teknis],
  [Operasional], [Menjalankan solusi nyata], [Operate, Evaluate], [Seluruh level], [Solusi hidup, operasi provider, experience user],
  [Evaluasi], [Audit, pembelajaran, redesign], [Evaluate, Hear, Model], [TISE level 5], [Hasil evaluasi, redesign, siklus baru],
)
== Prinsip Reusability
<prinsip-reusability>
Workflow full-scale tidak harus selalu ditempuh secara lengkap. Bila banyak elemen sudah tersedia dan reusable, rekayasa dapat dipersingkat dan difokuskan pada elemen yang perlu dimodifikasi.

= Part 2. Rekayasa TISE level 4
<part-2.-rekayasa-tise-level-4>
= Bab 5. DNA Desain, Meta-TISE, dan Artefak Anak
<bab-5.-dna-desain-meta-tise-dan-artefak-anak>
Pada #strong[TISE level 4], rekayasa bergerak ke ranah #strong[meta-TISE], yaitu rekayasa terhadap artefak TISE agar menjadi platform untuk melahirkan replika atau #strong[artefak anak]. Rekayasawan perlu membedakan:

- #strong[DNA platform] yang sudah tersedia;
- #strong[DNA gagasan baru] yang ingin ditambahkan.

“Perkawinan” desain terjadi ketika skill, pola, atau aturan baru ditambahkan ke DNA platform sehingga lahir artefak anak yang relevan dengan visi konfigurasi pada TISE level 5. Perspektif ini membuat TISE level 4 sangat penting sebagai jembatan antara visi stakeholder di atas dan keterbatasan realitas teknis-organisasional di bawah.

= Part 3. Rekayasa TISE level 3
<part-3.-rekayasa-tise-level-3>
= Bab 6. Identitas Naratif, Teater Solusi, dan Pementasan Misi
<bab-6.-identitas-naratif-teater-solusi-dan-pementasan-misi>
Pada #strong[TISE level 3], identitas naratif menjadi energon utama. Setiap stakeholder dipandang sebagai pembawa misi yang ingin mendeliver identitas naratifnya ke dunia.

Artefak pada level ini dipahami sebagai #strong[teater solusi], yaitu ruang tempat stakeholder menjalankan peran, menampilkan keunggulannya, dan memberi inspirasi atau manfaat bagi audiens. Rumah sakit dapat dipandang sebagai teater di mana para profesional medis menampilkan keahlian, kasih, dan ketepatan tindakan mereka dalam menyembuhkan pasien. Kelas teknik dapat dipahami sebagai teater tempat dosen dan mahasiswa bersama-sama mementaskan pencarian pengetahuan dan pembentukan jati diri profesional.

= Part 4. Rekayasa TISE level 2
<part-4.-rekayasa-tise-level-2>
= Bab 7. Mesin Agentik PUDAL dan Orkestrasi Triune Intelligence
<bab-7.-mesin-agentik-pudal-dan-orkestrasi-triune-intelligence>
Pada #strong[TISE level 2], mesin utama adalah #strong[PUDAL] (#emph[Perception, Understanding, Decision, Action, Learning]). Triune Intelligence bekerja melalui agents untuk menjalankan fungsi kendali statik dan dinamik. Prompts digunakan sebagai mekanisme komunikasi antaragents, antarlevel, dan antara manusia dengan sistem.

Pada perkembangan TISE yang lebih matang, prompts tidak hanya berfungsi sebagai instruksi imperatif, tetapi juga sebagai alat reflektif yang dapat membantu stakeholder memahami arti pengalaman, kegagalan, dan keberhasilannya. Melalui prompts, agents tidak hanya mengendalikan sistem, tetapi juga membantu manusia menafsirkan kembali perannya di dalam sistem.

= Part 5. Rekayasa TISE level 1
<part-5.-rekayasa-tise-level-1>
= Bab 8. Smart Engineering, Energon, dan Mesin PSKVE
<bab-8.-smart-engineering-energon-dan-mesin-pskve>
Pada #strong[TISE level 1], rekayasa diperluas dari konversi energi, material, dan informasi menjadi konversi #strong[energon].

Energon adalah segala sesuatu yang memiliki kapasitas untuk melakukan kerja atau memungkinkan kerja terjadi. Lima jenis energon yang penting adalah:

+ energi fisik;
+ waktu dan perhatian manusia;
+ skill dan pengetahuan;
+ token bernilai;
+ peran, status, atau keanggotaan.

Mesin #strong[PSKVE] adalah smart engine yang mengonversi energon menjadi:

- Product;
- Service;
- Knowledge;
- Value;
- Environment.

Kekuatan utama mesin PSKVE terletak pada kemampuannya untuk tidak mereduksi solusi menjadi satu jenis output saja. Sebuah solusi dapat gagal bila hanya menghasilkan produk, tetapi tidak menghadirkan layanan; dapat rapuh bila hanya memberi layanan tanpa membangun pengetahuan; dapat tidak berkelanjutan bila tidak menghasilkan nilai yang dirasakan; dan dapat sulit hidup bila tidak didukung lingkungan yang tepat.

= Part 6. Rekayasa TISE level 0
<part-6.-rekayasa-tise-level-0>
= Bab 9. Rekayasa Tradisional, Core Engine, dan EMI
<bab-9.-rekayasa-tradisional-core-engine-dan-emi>
Pada #strong[TISE level 0], rekayasa berfokus pada desain dan implementasi #strong[core engine] untuk memecahkan masalah terkait #strong[energi, material, dan informasi (EMI)]. Secara fungsional, pada level ini terdapat dua jenis mesin:

- mesin statik;
- mesin dinamik.

TISE level 0 tetap menjadi fondasi yang harus tersedia agar semua level di atasnya dapat diwujudkan secara nyata. Dalam arti ini, level tertinggi tidak membatalkan level terendah. Sebaliknya, semakin tinggi level rekayasa, semakin besar kebutuhan akan keandalan, keterukuran, dan realitas yang disediakan oleh level di bawahnya.

= Bab 10. Summary dan What Next
<bab-10.-summary-dan-what-next>
== Summary
<summary>
Monograf ini menunjukkan bahwa rekayasa dapat dipahami secara bertingkat dari TISE level 0 sampai TISE level 5. Pada level tertinggi, persoalan utama bukan lagi hanya mesin teknis, tetapi konfigurasi stakeholder bermisi. Karena itu, TISE level 5 membutuhkan Matrix of Mission, MOS-7, Stakeholder Readiness Framework, dan pusat keunggulan yang memobilisasi manusia untuk manusia.

Di balik seluruh pembagian level tersebut, terdapat satu benang merah yang sama: rekayasa adalah upaya #strong[memobilisasi sumber daya yang melimpah untuk dikonversikan menjadi kerja secara terkendali sehingga menghasilkan nilai yang berharga]. Nilai itu dapat berupa kemampuan mencapai output, behavior, fungsi, target, tujuan, atau misi yang diinginkan. Dalam keseluruhan hirarki ini, level yang lebih tinggi memberi konteks dan motivasi, sedangkan level yang lebih rendah memberi tumpuan realitas dan keandalan.

== What Next
<what-next>
Langkah berikut setelah membaca Buku DNA ini adalah:

+ memilih domain persoalan kemanusiaan;
+ membentuk visi konfigurasi terbaik;
+ mengidentifikasi stakeholder dan readiness-nya;
+ menjalankan paket pertanyaan teknis per level;
+ mengolah jawaban dengan bantuan agents;
+ menghasilkan Dokumen DNA operasional;
+ menjalankan Dokumen DNA itu bersama para stakeholder.

#show: appendices.with("Lampiran", hide-parent: true)
#heading(level: 1, numbering: none)[Lampiran]
= Lampiran A. Paket Pertanyaan Teknis untuk TISE level 5
<lampiran-a.-paket-pertanyaan-teknis-untuk-tise-level-5>
Pertanyaan-pertanyaan berikut dapat dipakai dalam wawancara, workshop, focus group discussion, survei, atau prompting agents.

== A.1 Persoalan Kemanusiaan
<a.1-persoalan-kemanusiaan>
+ Siapa stakeholder utama yang sedang mengalami hambatan dalam menjalankan misinya?
+ Apa keluhan utama yang paling nyata dirasakan stakeholder utama?
+ Apa dampak persoalan ini bagi hidup, pekerjaan, relasi, atau martabat stakeholder utama?
+ Mengapa persoalan ini penting untuk ditangani sekarang?
+ Apa risiko bila persoalan ini tidak ditangani?

== A.2 Visi Konfigurasi Terbaik
<a.2-visi-konfigurasi-terbaik>
+ Konfigurasi stakeholder seperti apa yang dipandang paling ideal?
+ Nilai apa yang ingin dihasilkan oleh konfigurasi tersebut?
+ Hubungan seperti apa yang diharapkan terjadi antar stakeholder?
+ Bagaimana gambaran keberhasilan bila konfigurasi terbaik itu terwujud?
+ Apa indikator bahwa konfigurasi yang dibangun benar-benar layak, adil, dan berkelanjutan?

== A.3 Tipologi Stakeholder
<a.3-tipologi-stakeholder>
+ Siapa USER utama dalam sistem ini?
+ Siapa SOURCE yang dapat menyumbang skill, pengetahuan, sumber daya, legitimasi, atau jejaring?
+ Siapa REGULATOR yang mewakili kepentingan yang lebih besar?
+ Siapa PROVIDER yang dapat menjalankan solusi dalam operasi nyata?
+ Adakah stakeholder yang memegang lebih dari satu peran sekaligus?

== A.4 Matrix of Mission
<a.4-matrix-of-mission>
+ Apa misi yang perlu dijalankan oleh masing-masing stakeholder?
+ Benefit apa yang diharapkan masing-masing stakeholder dari partisipasinya?
+ Kontribusi apa yang dapat diberikan setiap stakeholder kepada stakeholder lain?
+ Siapa yang menopang siapa dalam konfigurasi ini?
+ Apakah ada ketimpangan kontribusi dan benefit yang perlu diperbaiki?
+ Apakah ada stakeholder yang terlalu penting tetapi belum cukup didukung?

== A.5 Stakeholder Readiness
<a.5-stakeholder-readiness>
+ Seberapa sadar stakeholder atas identitas naratif dan perannya?
+ Seberapa jelas stakeholder mampu merumuskan misinya?
+ Apakah stakeholder memiliki kompetensi yang cukup?
+ Apakah motivasinya cukup kuat?
+ Apakah tingkat komitmennya memadai?
+ Apakah stakeholder mampu melihat dan memanfaatkan opportunity yang tersedia?
+ Intervensi apa yang diperlukan untuk meningkatkan readiness masing-masing stakeholder?

== A.6 Lapangan Kerja Baru
<a.6-lapangan-kerja-baru>
+ Peluang kerja baru apa yang dapat dibuka melalui konfigurasi ini?
+ Peran PROVIDER apa saja yang dibutuhkan?
+ Kompetensi apa yang perlu dikembangkan agar peran PROVIDER dapat diisi?
+ Bagaimana solusi ini dapat menjadi sarana mobilisasi angkatan kerja?
+ Bagaimana memastikan bahwa lapangan kerja yang dibuka tetap bermakna dan berkelanjutan?

= Lampiran B. Paket Pertanyaan Teknis untuk TISE level 4
<lampiran-b.-paket-pertanyaan-teknis-untuk-tise-level-4>
+ Platform apa yang sudah tersedia?
+ Apa kekuatan utama platform tersebut?
+ Bagian mana yang sudah proven dan layak dipertahankan?
+ Batasan apa yang dimiliki platform saat ini?
+ Gagasan baru apa yang perlu ditambahkan?
+ Artefak anak seperti apa yang ingin dilahirkan?
+ Bagian DNA mana yang reusable dan mana yang perlu dimodifikasi?

= Lampiran C. Paket Pertanyaan Teknis untuk TISE level 3
<lampiran-c.-paket-pertanyaan-teknis-untuk-tise-level-3>
+ Identitas naratif siapa yang paling penting untuk dipentaskan dalam solusi ini?
+ Kisah apa yang dibawa stakeholder ke dalam sistem?
+ Apa yang ingin stakeholder deliver kepada dunia melalui perannya?
+ Ruang atau lingkungan seperti apa yang akan menjadi teater solusi?
+ Pengalaman apa yang perlu dirasakan audiens?
+ Prompt apa yang dapat membantu stakeholder memahami perannya?

= Lampiran D. Paket Pertanyaan Teknis untuk TISE level 2
<lampiran-d.-paket-pertanyaan-teknis-untuk-tise-level-2>
+ Apa yang perlu dipersepsi oleh sistem?
+ Bagaimana data atau pengalaman itu dimaknai?
+ Keputusan apa yang perlu diambil oleh sistem?
+ Tindakan apa yang perlu dilakukan setelah keputusan diambil?
+ Umpan balik apa yang akan dikumpulkan?
+ Prompt apa yang diperlukan sebagai bahasa koordinasi?

= Lampiran E. Paket Pertanyaan Teknis untuk TISE level 1
<lampiran-e.-paket-pertanyaan-teknis-untuk-tise-level-1>
+ Energon apa saja yang tersedia dalam sistem?
+ Energon apa yang melimpah tetapi belum termobilisasi?
+ Product apa yang perlu dihasilkan?
+ Service apa yang perlu dialami stakeholder?
+ Knowledge apa yang dibutuhkan sistem?
+ Value apa yang ingin dihasilkan?
+ Environment seperti apa yang diperlukan agar solusi hidup?

= Lampiran F. Paket Pertanyaan Teknis untuk TISE level 0
<lampiran-f.-paket-pertanyaan-teknis-untuk-tise-level-0>
+ Core engine apa yang diperlukan?
+ Fungsi utamanya apa?
+ Apakah ia terutama bersifat statik atau dinamik?
+ Beban energi apa yang harus ditangani?
+ Material apa yang menjadi medium utama sistem?
+ Informasi apa yang perlu diproses atau ditransmisikan?
+ Risiko kegagalan apa yang harus diantisipasi?
+ Standar atau regulasi teknis apa yang harus dipenuhi?

= Lampiran G. Dari Jawaban Stakeholder ke Dokumen DNA
<lampiran-g.-dari-jawaban-stakeholder-ke-dokumen-dna>
Jawaban para stakeholder atas pertanyaan-pertanyaan teknis pada tiap level dikumpulkan sebagai bahan mentah. Kumpulan jawaban ini kemudian diolah oleh agents untuk menghasilkan #strong[Dokumen DNA].

== Isi Pokok Dokumen DNA
<isi-pokok-dokumen-dna>
Dokumen DNA sekurang-kurangnya memuat:

+ daftar tujuan pada berbagai level;
+ visi konfigurasi terbaik yang dipilih;
+ konfigurasi stakeholder dan Matrix of Mission;
+ hasil penilaian stakeholder readiness;
+ pembagian peran dan kontribusi;
+ artefak, platform, dan elemen teknis yang perlu tersedia;
+ tahapan kerja dan siklus MOS-7 yang akan dijalankan;
+ indikator evaluasi dan audit;
+ strategi peningkatan readiness stakeholder secara berkelanjutan.

== Peran Agents
<peran-agents>
Agents berperan untuk:

+ mengelompokkan dan merapikan jawaban stakeholder;
+ mendeteksi kekosongan atau inkonsistensi jawaban;
+ menyusun draft konfigurasi solusi;
+ menghasilkan Dokumen DNA dalam format yang dapat dipahami dan dijalankan;
+ mendukung revisi dokumen setelah evaluasi dan audit.

= Lampiran H. Dari Jawaban Stakeholder ke Dokumen Akademik
<lampiran-h.-dari-jawaban-stakeholder-ke-dokumen-akademik>
Lampiran ini menjelaskan bagaimana jawaban atas paket pertanyaan teknis pada Lampiran A sampai Lampiran G dapat diolah menjadi #strong[dokumen akademik].

== Pemetaan ke Struktur Dokumen Akademik
<pemetaan-ke-struktur-dokumen-akademik>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Bagian Dokumen Akademik], [Sumber Utama dari Lampiran Teknis], [Pertanyaan Kunci yang Diolah],),
  table.hline(),
  [Judul], [Lampiran A, G], [Masalah apa, solusi apa, domain apa, dan pendekatan TISE level berapa?],
  [Abstrak dan Keywords], [Lampiran A--G], [Apa masalahnya, apa tujuan, model apa yang dipakai, bagaimana metodologinya, dan apa kontribusinya?],
  [Pendahuluan], [Lampiran A], [Siapa USER, apa persoalannya, mengapa penting, apa gap praktik/riset, dan apa urgensinya?],
  [Teori dan Model], [Lampiran A--F], [Konsep TISE level 5, Matrix of Mission, readiness, MOS-7, PUDAL, PSKVE, dan level-level pendukung apa yang relevan?],
  [Metodologi dan Desain], [Lampiran A--G], [Bagaimana konfigurasi stakeholder dibentuk, bagaimana workflow dijalankan, bagaimana desain artefak dikembangkan, dan bagaimana data dikumpulkan?],
  [Pengembangan dan Eksperimen], [Lampiran B--F], [Artefak apa yang dibangun, bagaimana diuji, indikator apa yang dipakai, dan eksperimen apa yang dilakukan?],
  [Diskusi], [Lampiran A--G], [Apa makna hasil, apa keterbatasan, bagaimana readiness memengaruhi hasil, apa implikasi teoretis dan praktisnya?],
  [Kesimpulan], [Lampiran A, G], [Apa temuan utama, apa kontribusi, apa rekomendasi implementasi, dan apa langkah selanjutnya?],
)
== Contoh Misi
<contoh-misi>
#quote(block: true)[
#strong[Mewujudkan sistem rekomendasi cerdas multiobjektif untuk memenuhi kebutuhan makanan sehat, berselera, dan terjangkau bagi warga kampus, dengan memobilisasi stakeholder kampus agar bersama-sama membangun ekosistem pangan yang lebih bernilai, berkelanjutan, dan responsif terhadap preferensi pengguna.]
]

== Contoh Judul
<contoh-judul>
#strong[Sistem Rekomendasi Cerdas Multiobjektif untuk Memenuhi Kebutuhan Makanan Sehat, Berselera, dan Terjangkau bagi Warga Kampus: Pendekatan TISE level 5 Berbasis Matrix of Mission dan MOS-7]

== Contoh Abstrak Singkat
<contoh-abstrak-singkat>
Kebutuhan makanan sehat, berselera, dan terjangkau merupakan persoalan penting bagi warga kampus karena berkaitan dengan kesehatan, produktivitas, kepuasan hidup, dan keberlanjutan aktivitas akademik. Studi ini mengusulkan pengembangan sistem rekomendasi cerdas multiobjektif dengan pendekatan TISE level 5 untuk membantu membentuk konfigurasi stakeholder yang mampu memenuhi kebutuhan tersebut. Matrix of Mission digunakan untuk memetakan misi, benefit, dan kontribusi USER, SOURCE, REGULATOR, dan PROVIDER, sedangkan MOS-7 digunakan sebagai siklus operasional desain dan evaluasi. Sistem rekomendasi dirancang untuk menyeimbangkan beberapa objektif sekaligus, yaitu kesehatan, selera, keterjangkauan, dan kesiapan operasional penyedia makanan. Kontribusi studi ini adalah integrasi antara rekayasa rekomendasi cerdas multiobjektif dengan kerangka rekayasa kemanusiaan TISE level 5, sehingga solusi tidak hanya optimal secara komputasional tetapi juga layak secara sosial-operasional.

#bibliography(("references.bib"))

// IN AFTER !!!
