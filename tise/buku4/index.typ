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
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Rekayasa Multidisiplin di Era Kecerdasan Sistem],
  subtitle: [Triune-Intelligence Smart Engineering Level 5],
  author: "Armein Z. R. Langi",
  date: "2026-04-20",
  lang: "id",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
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
Monograf ini disusun untuk merumuskan secara sistematis perkembangan konseptual dalam paradigma #strong[Triune-Intelligence Smart Engineering (TISE)] hingga mencapai #strong[TISE level 5], yaitu level di mana TISE hadir sebagai pusat keunggulan rekayasa bagi penyelesaian persoalan kemanusiaan. Jika rekayasa klasik berhasil besar dalam membangun infrastruktur peradaban material, maka masyarakat abad ke-21 menghadapi tuntutan baru: bagaimana membantu manusia hidup secara aktif, produktif, dan bermakna melalui konfigurasi sosial yang saling menopang misi.

Monograf ini berangkat dari keyakinan bahwa rekayasa perlu bergerak melampaui batas-batas sektoralnya. Rekayasa tidak lagi hanya berbicara tentang mesin fisik, proses industri, atau sistem komputasi, tetapi juga tentang bagaimana manusia, institusi, teknologi, narasi, dan nilai dapat diorganisasikan menjadi solusi yang hidup. Karena itu, monograf ini menelusuri evolusi abstraksi rekayasa dari #strong[core engine] pada TISE level 0, menuju #strong[smart engine/mesin PSKVE] pada TISE level 1, #strong[mesin agentik PUDAL] pada TISE level 2, #strong[teater identitas naratif] pada TISE level 3, #strong[DNA desain meta-TISE] pada TISE level 4, hingga #strong[Matrix of Mission] sebagai mesin konfigurasi stakeholder pada TISE level 5.

Secara khusus, monograf ini menempatkan #strong[MOS-7] sebagai siklus operasional TISE level 5 dan #strong[Matrix of Mission] sebagai mesin utama untuk membentuk serta mengevaluasi konfigurasi stakeholder bermisi. Melalui kedua perangkat ini, TISE level 5 dirumuskan sebagai bentuk kelembagaan rekayasa yang mampu memobilisasi potensi manusia yang berlimpah untuk memecahkan persoalan kemanusiaan dengan prinsip #strong[dari manusia untuk manusia].

Sebagai monograf, tulisan ini tidak dimaksudkan sebagai laporan proyek atau manual teknis semata, melainkan sebagai fondasi konseptual yang dapat menopang riset, pendidikan, desain artefak, pembentukan pusat keunggulan, dan pengembangan metodologi lanjutan. Lebih jauh lagi, monograf ini diposisikan sebagai sebuah #strong[Buku DNA], yaitu dokumen acuan yang dapat dibaca, ditafsirkan, dan dijalankan oleh para rekayasawan, stakeholder, dan agents dalam bagian dan peran mereka masing-masing. Dengan demikian, monograf ini diharapkan menjadi titik tolak bagi pembentukan bidang kajian rekayasa yang lebih manusiawi, lebih reflektif, dan lebih relevan bagi tantangan abad ke-21, sekaligus menjadi naskah pengarah bagi perwujudan nyata TISE level 5.

#heading(level: 1, numbering: none)[Abstrak]
<abstrak>
Monograf ini merumuskan #strong[TISE level 5] sebagai level perkembangan rekayasa di mana paradigma #strong[Triune-Intelligence Smart Engineering (TISE)] hadir dalam bentuk #strong[pusat keunggulan rekayasa] untuk memecahkan persoalan kemanusiaan. Argumen utamanya adalah bahwa persoalan manusia abad ke-21 tidak lagi memadai jika dipahami hanya sebagai persoalan energi, material, dan informasi, melainkan perlu dipandang sebagai persoalan konfigurasi stakeholder bermisi, distribusi benefit, legitimasi regulatif, operasi solusi, dan mobilisasi potensi manusia.

Untuk menjelaskan pergeseran tersebut, monograf ini menyusun hirarki level rekayasa: #strong[TISE level 0] sebagai rekayasa tradisional berbasis core engine; #strong[TISE level 1] sebagai smart engineering berbasis smart engine/mesin PSKVE; #strong[TISE level 2] sebagai rekayasa agentik berbasis mesin PUDAL; #strong[TISE level 3] sebagai rekayasa pementasan identitas naratif; #strong[TISE level 4] sebagai rekayasa meta-artefak berbasis DNA desain; dan #strong[TISE level 5] sebagai rekayasa konfigurasi stakeholder berbasis Matrix of Mission.

Dalam monograf ini, #strong[Matrix of Mission] dirumuskan sebagai mesin utama TISE level 5, sedangkan #strong[MOS-7] dirumuskan sebagai siklus operasional untuk mendengar keluhan manusia, memodelkan stakeholder, mendesain konfigurasi solusi, membangun komitmen, membangun artefak, mengoperasionalkan solusi, dan mengevaluasi integritas serta dampaknya. Dari sudut pandang literatur, posisi ini dapat dipahami sebagai perluasan atas tradisi PSS, stakeholder motivation matrix, dan multi-stakeholder requirements @morelli2002@vezzoli2014@berkovich2014@sholihah2019. Dengan kerangka tersebut, TISE level 5 dipahami bukan sekadar sebagai metode desain, melainkan sebagai bentuk kelembagaan yang memobilisasi manusia untuk menolong manusia lain, sekaligus membuka lapangan kerja baru dalam pelayanan kemanusiaan, operasi solusi, pendampingan, dan fasilitasi komunitas.

Kontribusi utama monograf ini meliputi: (1) perumusan ontologi bertingkat bagi evolusi rekayasa dari core engine ke Matrix of Mission; (2) generalisasi konsep energi menjadi #strong[energon]\; (3) definisi formal atas PSKVE, PUDAL, stakeholder bermisi, Matrix of Mission, dan TISE level 5; serta (4) proposisi konseptual dan agenda riset bagi pengembangan TISE level 5 sebagai bidang ilmu dan praktik. Dengan demikian, monograf ini menawarkan dasar konseptual bagi rekayasa yang lebih integratif, partisipatif, agentik, dan manusiawi.

#strong[Kata kunci:] TISE level 5, monograf rekayasa, Matrix of Mission, MOS-7, stakeholder bermisi, energon, PSKVE, PUDAL, pusat keunggulan, rekayasa kemanusiaan.

#part[Bagian I. Pengantar Monograf dan Posisi TISE level 5]
= Bab 1. Pendahuluan
<bab-1.-pendahuluan>
== Latar Belakang
<latar-belakang>
Sepanjang sejarah peradaban modern, rekayasa telah terbukti menjadi salah satu kekuatan utama yang memungkinkan manusia mengatasi berbagai persoalan hidupnya. Rekayasa telah melahirkan pemukiman yang lebih layak, gedung dan tempat kerja yang menopang produktivitas, jalan raya yang menghubungkan wilayah, transportasi udara yang mempercepat mobilitas, sistem pangan yang mendukung populasi besar, infrastruktur energi yang memungkinkan aktivitas ekonomi, teknologi komunikasi yang menghubungkan manusia lintas jarak, serta industri yang menghasilkan barang dan layanan dalam skala besar. Dalam pengertian ini, rekayasa telah menjadi salah satu fondasi terpenting bagi keberhasilan peradaban dalam menanggapi kebutuhan-kebutuhan dasar manusia.

Namun, pada abad ke-21, persoalan manusia tidak lagi berhenti pada penyediaan kebutuhan dasar material dan infrastruktur. Persoalan mulai bergeser ke arah kebutuhan akan kehidupan yang #strong[aktif, produktif, dan bermakna]. Manusia tidak cukup hanya memiliki rumah, jalan, listrik, makanan, atau alat komunikasi. Manusia ingin hidup sebagai pribadi yang memiliki arah, mampu berkarya, dapat berkontribusi, dan merasa bahwa hidupnya berarti. Kebutuhan ini semakin nyata dalam masyarakat yang kompleks, terdigitalisasi, dan saling bergantung, di mana keberhasilan seseorang sangat dipengaruhi oleh kemampuan untuk memahami misi dirinya sendiri, memahami misi orang lain, dan membangun konfigurasi sosial yang saling menopang.

Dengan demikian, kebutuhan manusia modern semakin bersifat #strong[misioner]. Yang dicari bukan sekadar survival, melainkan kemampuan menjalankan misi kehidupan secara aktif dan produktif bersama orang lain. Dalam konteks ini, persoalan kemanusiaan sering kali muncul bukan hanya karena kurangnya teknologi, tetapi karena tidak terbangunnya konfigurasi stakeholder yang saling memahami, saling menopang, dan bersama-sama membentuk solusi yang hidup. Karena itu, dibutuhkan lompatan paradigma: bukan hanya menggunakan engineering untuk menghasilkan artefak, tetapi juga menjadikan engineering sebagai cara masyarakat membentuk dirinya sendiri.

Di sinilah muncul kebutuhan akan dua gerakan yang saling terkait, yaitu #strong[memasyarakatkan engineering] dan #strong[mengengineeringkan masyarakat]. Memasyarakatkan engineering berarti menjadikan cara berpikir rekayasa, cara memodelkan masalah, cara membangun solusi, dan cara mengevaluasi sistem sebagai bagian dari budaya masyarakat luas. Sebaliknya, mengengineeringkan masyarakat berarti memperlakukan masyarakat, relasi sosial, organisasi, dan konfigurasi stakeholder sebagai sesuatu yang dapat direkayasa secara sadar agar menjadi lebih efektif, adil, produktif, dan bermakna. Dengan kata lain, masyarakat perlu belajar menjadi engineers dalam arti luas, sementara engineers perlu semakin sungguh-sungguh mengarahkan ilmunya untuk mengatasi persoalan masyarakat.

Transformasi semacam ini tidak dapat dijalankan hanya dengan niat baik atau teknologi semata. Diperlukan metodologi yang efektif untuk mendengar persoalan manusia, memodelkan stakeholder, membangun komitmen, merekayasa artefak, mengoperasionalkan solusi, dan mengevaluasi dampaknya secara berkelanjutan. Kebutuhan inilah yang melatarbelakangi pengembangan paradigma #strong[Triune-Intelligence Smart Engineering (TISE)].

== Rumusan Masalah
<rumusan-masalah>
Monograf ini berangkat dari beberapa pertanyaan utama:

+ Bagaimana TISE level 5 dapat dirumuskan sebagai pusat keunggulan rekayasa?
+ Bagaimana masalah kemanusiaan dipahami sebagai objek rekayasa dalam paradigma TISE?
+ Bagaimana MOS-7 dapat diadaptasi menjadi siklus operasional TISE level 5?
+ Bagaimana stakeholder diberdayakan untuk menjalankan misi masing-masing dalam pembangunan artefak solusi?
+ Bagaimana integritas, etika, dan keberlanjutan solusi dijaga?

== Tujuan Monograf
<tujuan-monograf>
Monograf ini bertujuan:

+ merumuskan definisi dan posisi konseptual TISE level 5 dalam evolusi rekayasa;
+ menjelaskan hubungan antara TISE level 0, TISE level 1, TISE level 2, TISE level 3, TISE level 4, dan TISE level 5;
+ merumuskan Matrix of Mission sebagai mesin utama konfigurasi stakeholder;
+ merumuskan MOS-7 sebagai #emph[mission operating cycle] bagi pusat keunggulan rekayasa kemanusiaan;
+ menawarkan ontologi, definisi formal, dan proposisi ilmiah bagi pengembangan TISE level 5;
+ memberi dasar bagi penelitian, pengajaran, pembentukan pusat keunggulan, dan implementasi kelembagaan TISE level 5.

== Kontribusi Monograf
<kontribusi-monograf>
Kontribusi utama monograf ini adalah menggeser TISE dari sekadar paradigma atau metodologi menjadi #strong[institusi rekayasa yang operasional], yaitu pusat keunggulan yang mampu memobilisasi banyak agen TISE dan banyak stakeholder di sekitar misi-misi kemanusiaan.

Secara lebih rinci, kontribusi monograf ini dapat diringkas sebagai berikut:

+ menyusun #strong[hirarki evolusi rekayasa] dari TISE level 0 hingga TISE level 5;
+ memperkenalkan konsep #strong[energon] sebagai generalisasi energi bagi TISE level 1;
+ merumuskan #strong[smart engine/mesin PSKVE] sebagai abstraksi utama TISE level 1;
+ menempatkan #strong[PUDAL], #strong[identitas naratif], dan #strong[DNA desain] sebagai level-level abstraksi lanjutan dalam perkembangan TISE;
+ merumuskan #strong[Matrix of Mission] sebagai mesin utama konfigurasi stakeholder pada TISE level 5;
+ menempatkan #strong[MOS-7] sebagai siklus operasional bagi pusat keunggulan TISE level 5;
+ merumuskan agenda riset untuk pengembangan TISE level 5 sebagai bidang ilmu dan praktik.

== Posisi Monograf dalam Literatur
<posisi-monograf-dalam-literatur>
Monograf ini berada pada persimpangan beberapa rumpun literatur. Pertama, literatur #strong[Product-Service Systems (PSS)] menegaskan bahwa solusi kontemporer semakin hadir sebagai kombinasi produk dan layanan yang terintegrasi untuk memenuhi kebutuhan pengguna, bukan sebagai produk tunggal. Kedua, literatur #strong[service design] dan #strong[system design tools] telah memperkenalkan alat-alat visual untuk memetakan aktor, relasi, dan motivasi dalam sistem layanan. Ketiga, literatur #strong[multi-stakeholder requirements] menunjukkan bahwa solusi yang bernilai sering bergantung pada kemampuan menangkap dan mengoordinasikan kebutuhan banyak pihak sekaligus. Keempat, literatur #strong[stakeholder engagement and management] menekankan bahwa kualitas solusi sangat dipengaruhi oleh cara para aktor didefinisikan, dilibatkan, dan dihubungkan dalam keseluruhan siklus sistem.

Dalam konteks itu, monograf ini menempatkan #strong[Matrix of Mission] sebagai pengembangan dari tradisi #strong[stakeholder motivation matrix] dalam literatur PSS dan service design @morelli2002@vezzoli2014@giordano2018. Namun, pengembangan yang diusulkan di sini bergerak melampaui motivasi menuju #strong[misi], #strong[benefit], #strong[kontribusi silang], #strong[tipologi stakeholder] (USER, SOURCE, REGULATOR, PROVIDER), dan #strong[operasi siklik] melalui MOS-7. Dengan demikian, monograf ini tidak hanya mengusulkan alat visual baru, tetapi juga sebuah kerangka ontologis dan kelembagaan baru bagi rekayasa kemanusiaan.

= Bab 2. Tinjauan Pustaka dan Dasar Konseptual
<bab-2.-tinjauan-pustaka-dan-dasar-konseptual>
== Product-Service Systems sebagai Latar Penting
<product-service-systems-sebagai-latar-penting>
Salah satu landasan penting bagi monograf ini adalah literatur #strong[Product-Service Systems (PSS)]. Nicola Morelli menekankan perlunya pergeseran dari produksi barang menuju penyediaan solusi sistemik yang terdiri atas kombinasi produk dan layanan @morelli2002. Dalam pengertian ini, desain tidak lagi hanya menangani bentuk artefak, tetapi juga hubungan antaraktor, proses penggunaan, dan struktur penyampaian nilai. Literatur PSS selanjutnya juga menegaskan bahwa PSS merupakan bundel elemen fisik dan layanan yang diintegrasikan untuk menyelesaikan masalah pengguna @vezzoli2014@berkovich2014.

== Stakeholder Motivation Matrix dan Akar Matrix of Mission
<stakeholder-motivation-matrix-dan-akar-matrix-of-mission>
Literatur desain untuk PSS telah mengembangkan alat-alat representasi sistem seperti #emph[system map], #emph[interaction storyboard], dan #strong[stakeholder motivation matrix] @vezzoli2014. Dalam literatur tersebut, #emph[motivation matrix] dijelaskan sebagai tabel dua-arah yang memungkinkan perancang melihat motivasi tiap aktor, kontribusi yang diberikan kepada kemitraan, #emph[expected benefits], serta potensi sinergi atau konflik dengan aktor lain @vezzoli2014.

Monograf ini mengakui secara eksplisit bahwa #strong[Matrix of Mission] berada dalam garis pengembangan konseptual dari tradisi tersebut @morelli2002@vezzoli2014. Namun, Matrix of Mission yang diusulkan di sini memperluas fokus #emph[motivation matrix]. Jika #emph[motivation matrix] terutama bertanya mengapa aktor mau terlibat dan apa yang mereka kontribusikan atau harapkan, maka Matrix of Mission menempatkan #strong[misi] sebagai pusat diagonal utama dan menghubungkannya dengan benefit, kontribusi antarpihak, keberlanjutan operasi, serta evaluasi kelayakan konfigurasi stakeholder. Karena itu, Matrix of Mission bukan hanya alat motivasional, melainkan mesin konfigurasi sosial-operasional.

== Multi-Stakeholder Requirements dan Konfigurasi Solusi
<multi-stakeholder-requirements-dan-konfigurasi-solusi>
Literatur PSS yang lebih baru juga menunjukkan bahwa sistem nyata biasanya dibentuk oleh #strong[konsorsium multi-stakeholder], dan keberhasilan desain sangat bergantung pada kemampuan menangkap serta mewujudkan kebutuhan banyak pihak secara serempak @sholihah2019. Dengan demikian, fokus pada kebutuhan aktor tunggal tidak lagi memadai. Solusi harus dipahami sebagai hasil negosiasi, integrasi, dan pengaturan ketergantungan antarpihak.

== Stakeholder Engagement, Stakeholder Map, dan Rekayasa Kemanusiaan
<stakeholder-engagement-stakeholder-map-dan-rekayasa-kemanusiaan>
Literatur service design menunjukkan bahwa #strong[stakeholder map] berperan sebagai alat percakapan untuk membangun layanan yang lebih #emph[people-led] dan #emph[citizen-centred] @giordano2018. Literatur lain tentang stakeholder engagement dalam inovasi juga menekankan bahwa ekosistem inovasi modern terdiri dari konstelasi stakeholder yang heterogen, dengan tujuan, motif, dan kapabilitas yang berbeda @lievens2021.

== Posisi Kebaruan Monograf
<posisi-kebaruan-monograf>
Kebaruan utama monograf ini terletak pada lima hal. Pertama, monograf ini menyusun #strong[hirarki evolusi rekayasa] dari TISE level 0 hingga TISE level 5. Kedua, monograf ini memperkenalkan #strong[energon] sebagai generalisasi energi. Ketiga, monograf ini menempatkan #strong[PSKVE] dan #strong[PUDAL] ke dalam kerangka rekayasa bertingkat. Keempat, monograf ini mengembangkan #strong[Matrix of Mission] dari tradisi stakeholder motivation matrix menjadi mesin konfigurasi stakeholder bermisi. Kelima, monograf ini menghubungkan semuanya dengan #strong[MOS-7] sebagai siklus operasional bagi pusat keunggulan rekayasa kemanusiaan.

#part[Bagian II. Evolusi Rekayasa Menuju TISE level 5]
= Bab 3. Evolusi Paradigma Rekayasa: dari TISE level 0 hingga TISE level 5
<bab-3.-evolusi-paradigma-rekayasa-dari-tise-level-0-hingga-tise-level-5>
== TISE level 0: Rekayasa Tradisional Berbasis Core Engine
<tise-level-0-rekayasa-tradisional-berbasis-core-engine>
Pada #strong[TISE level 0], rekayasa dapat dipahami sebagai kegiatan #strong[mengelola energi menjadi kerja] melalui artefak-artefak yang dapat diabstraksikan sebagai #strong[mesin inti] (#emph[core engine]). Mesin, dalam arti luas, adalah konfigurasi instrumen yang mengubah, menyalurkan, menyimpan, mengendalikan, atau menstabilkan energi agar suatu kerja tertentu dapat dicapai. Di balik keragaman disiplin rekayasa, terdapat pola umum: rekayasa adalah desain dan implementasi mesin energi untuk memecahkan masalah yang terkait dengan #strong[beban energi, material, dan informasi (EMI)].

Pada level ini, mesin dikendalikan terutama melalui mekanisme sederhana seperti #strong[on-off] atau melalui satu besaran kendali dominan yang bersifat satu dimensi, misalnya percepatan atau perlambatan. Secara fungsional terdapat dua jenis mesin: #strong[mesin statik] yang dirancang untuk menjaga kestabilan struktur atau keadaan diam, dan #strong[mesin dinamik] yang dirancang untuk mengatur perpindahan, kecepatan, percepatan, aliran, atau perubahan keadaan.

== TISE level 1: Smart Engineering Berbasis Smart Engine atau Mesin PSKVE
<tise-level-1-smart-engineering-berbasis-smart-engine-atau-mesin-pskve>
Pada level ini, logika kendali diperluas dari satu besaran dominan ke #strong[lima dimensi], yaitu #strong[P, S, K, V, dan E] (#emph[Product, Service, Knowledge, Value, Environment]). Karena itu, sistem kendalinya memerlukan #strong[lima derajat kebebasan], sehingga dibutuhkan komputer, algoritma pengendalian, dan kemampuan komputasional yang lebih tinggi.

TISE level 1 adalah perluasan dari TISE level 0. Jika pada TISE level 0 fokus utama berada pada konversi energi, material, dan informasi, maka pada TISE level 1 fokusnya diperluas pada konversi berbagai jenis energon yang hadir dalam kehidupan manusia, organisasi, dan masyarakat. TISE level 1 karena itu dapat didefinisikan sebagai #strong[rekayasa multidisiplin untuk membangun instrumen konversi energon dalam konfigurasi mesin PSKVE].

== TISE level 2: Rekayasa Agentik Berbasis Mesin PUDAL
<tise-level-2-rekayasa-agentik-berbasis-mesin-pudal>
Pada level ini, mesin PSKVE tidak lagi cukup dikendalikan hanya oleh komputer dan algoritma biasa. Ia dikendalikan oleh #strong[mesin cerdas PUDAL] (#emph[Perception, Understanding, Decision, Action, Learning]). Di sini #strong[Triune Intelligence] berinteraksi untuk menjalankan fungsi kendali statik maupun dinamik. Prompts berfungsi sebagai mekanisme komunikasi antaragents.

== TISE level 3: Rekayasa Pementasan Identitas Naratif
<tise-level-3-rekayasa-pementasan-identitas-naratif>
Pada level ini, pementasan #strong[identitas naratif] menjadi penggerak utama atau #strong[energon utama] dari mesin-mesin inti, PSKVE, dan PUDAL. Asumsi dasarnya adalah bahwa setiap orang memiliki misi di dunia ini, yaitu mendeliver identitas naratifnya ke dunia sebagai tugas hidupnya. Artefak rekayasa pada level ini dipahami sebagai #strong[teater megah] tempat identitas naratif dipentaskan sehingga memberi inspirasi atau solusi yang dibutuhkan audiens.

== TISE level 4: Rekayasa Meta-TISE Berbasis DNA Desain
<tise-level-4-rekayasa-meta-tise-berbasis-dna-desain>
Pada level ini, rekayasa bergerak ke ranah #strong[meta-TISE], yaitu rekayasa terhadap artefak TISE itu sendiri agar menjadi platform untuk melahirkan replika atau “anak artefak”. Pada level ini digunakan metafora biologis berupa #strong[DNA desain]. Sebuah sistem terdiri dari berbagai agents yang menggunakan #strong[buku skills] yang sama, tetapi masing-masing berfokus pada bagian tertentu dari keseluruhan sistem.

== TISE level 5: Rekayasa Konfigurasi Stakeholder Berbasis Matrix of Mission
<tise-level-5-rekayasa-konfigurasi-stakeholder-berbasis-matrix-of-mission>
Pada level ini, rekayasa mencapai tingkat kelembagaan dan sosial yang lebih matang. Fokus utamanya bukan lagi mesin inti, mesin PSKVE, PUDAL, identitas naratif, atau DNA desain, tetapi #strong[organisasi, konsorsium, atau komunitas stakeholder] yang dibentuk untuk memecahkan persoalan kemanusiaan. Pada level ini, artefak rekayasa utama adalah #strong[konfigurasi stakeholder] itu sendiri dan mesinnya adalah #strong[Matrix of Mission].

== Tabel Perbandingan TISE level 0--5
<tabel-perbandingan-tise-level-05>
Untuk memperjelas argumen tentang evolusi abstraksi rekayasa, #strong[Tabel 3.1] merangkum perkembangan level rekayasa dari TISE level 0 hingga TISE level 5. Tabel ini perlu dibaca sebagai peta konseptual yang menunjukkan pergeseran fokus, jenis mesin, mekanisme kendali, artefak utama, dan tujuan rekayasa pada setiap level.

#table(
  columns: (12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%),
  align: (auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header([Level], [Nama Level], [Fokus Rekayasa], [Jenis Mesin], [Energon / Sumber Kerja Utama], [Mekanisme Kendali], [Artefak Utama], [Tujuan Utama],),
  table.hline(),
  [0], [Rekayasa tradisional], [Konversi EMI menjadi kerja atau bentuk tersimpan/tertransmisikan], [Core Engine], [Energi fisik, material, informasi], [On-off, besaran satu dimensi, kendali statik/dinamik klasik], [Mesin, struktur, proses, perangkat sektoral], [Menyelesaikan persoalan sektoral secara stabil, efisien, dan andal],
  [1], [Smart Engineering], [Konversi energon menjadi PSKVE], [Smart Engine / Mesin PSKVE], [Energon 1--5], [Kendali multidimensi 5 derajat kebebasan], [Lingkungan kerja cerdas: stasiun, jalan, kendaraan], [Menghasilkan produk, layanan, pengetahuan, nilai, dan lingkungan yang memecahkan masalah],
  [2], [Rekayasa agentik], [Pengendalian agentik atas mesin PSKVE], [Mesin PUDAL], [Triune Intelligence yang bekerja melalui agen], [PUDAL dan prompts], [Sistem agentik yang mengorkestrasi PSKVE], [Menutup gap secara adaptif dan cerdas],
  [3], [Rekayasa naratif], [Pementasan identitas naratif sebagai energon utama], [Teater Naratif], [Identitas naratif, misi hidup, agensi, makna], [Interaksi naratif dan prompting reflektif], [Teater kehidupan / lingkungan naratif], [Memberdayakan stakeholder untuk mendeliver misinya],
  [4], [Rekayasa meta-TISE], [Rekayasa meta-artefak yang dapat melahirkan artefak baru], [Mesin DNA Desain / Meta-TISE], [Buku skills dan pola desain], [Konsistensi DNA desain], [Platform TISE yang dapat menghasilkan replika atau anak artefak], [Membangun platform rekayasa yang reproduktif],
  [5], [Rekayasa konfigurasi stakeholder], [Rekayasa konfigurasi stakeholder bermisi], [Matrix of Mission], [Potensi manusia, misi stakeholder, komitmen kolektif], [Matrix of Mission dan MOS-7], [Organisasi, konsorsium, komunitas stakeholder, pusat keunggulan], [Memobilisasi manusia untuk memecahkan persoalan kemanusiaan],
)
== Definisi Ringkas TISE level 5
<definisi-ringkas-tise-level-5>
#strong[TISE level 5] adalah level rekayasa di mana TISE hadir sebagai pusat keunggulan yang memobilisasi stakeholder bermisi, agen-agen TISE, dan artefak cerdas untuk memecahkan persoalan kemanusiaan melalui konfigurasi stakeholder, pengoperasian MOS-7, dan penggunaan Matrix of Mission secara berulang, adaptif, dan bermakna.

= Bab 4. Ontologi dan Definisi Formal
<bab-4.-ontologi-dan-definisi-formal>
== Kebutuhan akan Definisi Formal
<kebutuhan-akan-definisi-formal>
Agar TISE level 5 dapat berkembang sebagai paradigma ilmiah, ia tidak cukup dijelaskan secara metaforis atau naratif saja. Diperlukan ontologi dan definisi formal yang memungkinkan istilah-istilah utamanya dipakai secara konsisten dalam penelitian, pengajaran, desain sistem, dan evaluasi implementasi.

== Definisi Energon
<definisi-energon>
#strong[Energon] adalah setiap entitas, kondisi, status, kapasitas, atau sumber daya yang memiliki kemampuan untuk menghasilkan kerja atau memungkinkan kerja terjadi dalam suatu sistem rekayasa.

Secara operasional, energon dapat diklasifikasikan sekurang-kurangnya ke dalam lima jenis: 1. #strong[Energon-1]: energi fisik; 2. #strong[Energon-2]: waktu dan perhatian manusia; 3. #strong[Energon-3]: skill dan pengetahuan; 4. #strong[Energon-4]: token bernilai seperti uang atau insentif; 5. #strong[Energon-5]: peran, status, atau keanggotaan dalam lingkungan kerja dan narasi sosial.

== Definisi Core Engine
<definisi-core-engine>
#strong[Core engine] adalah konfigurasi instrumen yang mengubah, menyalurkan, menyimpan, mengendalikan, atau menstabilkan energi, material, dan informasi untuk menghasilkan kerja atau keluaran tertentu.

== Definisi Smart Engine
<definisi-smart-engine>
#strong[Smart engine] adalah konfigurasi instrumen cerdas yang mengonversi energon menjadi kapasitas kerja, perubahan keadaan, atau keluaran yang dibutuhkan dalam penyelesaian masalah.

== Definisi Mesin PSKVE
<definisi-mesin-pskve>
#strong[Mesin PSKVE] adalah smart engine yang mengonversi energon menjadi lima bentuk utama hasil rekayasa, yaitu #strong[Product, Service, Knowledge, Value, dan Environment].

== Definisi Mesin PUDAL
<definisi-mesin-pudal>
#strong[Mesin PUDAL] adalah mesin agentik yang menjalankan fungsi #strong[Perception, Understanding, Decision, Action, and Learning] untuk mengendalikan dan mengarahkan operasi mesin PSKVE.

== Definisi Identitas Naratif
<definisi-identitas-naratif>
#strong[Identitas naratif] adalah konstruksi kisah hidup yang diinternalisasi oleh seseorang sebagai dasar bagi pemaknaan diri, orientasi misi, dan tindakan hidupnya di dunia.

== Definisi DNA Desain
<definisi-dna-desain>
#strong[DNA desain] adalah representasi sistematis dari pola-pola desain, skills, aturan, dan struktur konseptual yang memungkinkan suatu artefak TISE direplikasi, dikembangkan, atau “dikawinkan” dengan artefak lain untuk melahirkan generasi artefak baru.

== Definisi Stakeholder Bermisi
<definisi-stakeholder-bermisi>
#strong[Stakeholder bermisi] adalah pihak manusiawi atau institusional yang memiliki tujuan, panggilan, atau peran bermakna yang ingin dijalankan, serta dapat berkontribusi, menerima manfaat, atau mengalami hambatan dalam suatu konfigurasi solusi.

== Definisi Matrix of Mission
<definisi-matrix-of-mission>
#strong[Matrix of Mission] adalah mesin konfigurasi stakeholder yang memetakan misi, benefit, dan kontribusi timbal balik antar stakeholder untuk membentuk dan mengevaluasi skema solusi.

== Definisi MOS-7
<definisi-mos-7>
#strong[MOS-7] adalah siklus operasional TISE level 5 yang terdiri dari tujuh langkah: mendengar keluhan, memodelkan stakeholder, mendesain konfigurasi solusi, membangun komitmen, membangun artefak, mengoperasionalkan solusi, serta mengevaluasi dan mengaudit integritas serta dampaknya.

== Definisi TISE level 5
<definisi-tise-level-5>
#strong[TISE level 5] adalah level rekayasa di mana TISE hadir sebagai pusat keunggulan yang menggunakan Matrix of Mission dan MOS-7 untuk memobilisasi potensi manusia yang berlimpah guna memecahkan persoalan kemanusiaan melalui konfigurasi stakeholder bermisi.

#part[Bagian III. Arsitektur TISE level 5 sebagai Buku DNA]
= Bab 5. TISE level 5 sebagai Pusat Keunggulan Rekayasa
<bab-5.-tise-level-5-sebagai-pusat-keunggulan-rekayasa>
== Mengapa Pusat Keunggulan?
<mengapa-pusat-keunggulan>
Masalah kemanusiaan bersifat lintas domain, lintas institusi, dan lintas stakeholder. Karena itu, penyelesaiannya tidak cukup ditangani oleh satu disiplin, satu unit teknis, atau satu artefak tunggal. Diperlukan organisasi yang mampu secara sadar mendengar keluhan manusia, memodelkan konfigurasi stakeholder, merancang solusi, membangun komitmen, dan menjaga operasi serta integritas solusi secara berkelanjutan.

== Visi
<visi>
Visi TISE level 5 adalah #strong[terbentuknya masyarakat yang mampu memobilisasi potensi manusianya secara cerdas, bermartabat, dan terorganisasi untuk memecahkan persoalan kemanusiaan dari manusia untuk manusia].

== Misi
<misi>
Misi utama TISE level 5 adalah #strong[memobilisasi potensi manusia yang berlimpah untuk memecahkan persoalan kemanusiaan].

== Prinsip Direktif
<prinsip-direktif>
Prinsip direktif TISE level 5 adalah #strong[dari manusia untuk manusia].

== Mesin Utama
<mesin-utama>
Mesin utama TISE level 5 adalah #strong[Matrix of Mission].

== Unit Analisis Utama
<unit-analisis-utama>
Unit analisis utama TISE level 5 adalah #strong[stakeholder bermisi dalam konfigurasi relasional].

== Artefak Utama
<artefak-utama>
Artefak utama pada level ini adalah #strong[organisasi, konsorsium, komunitas stakeholder, atau pusat keunggulan] yang dirancang untuk menjalankan MOS-7.

= Bab 6. Matrix of Mission dan Tipologi Stakeholder
<bab-6.-matrix-of-mission-dan-tipologi-stakeholder>
== Stakeholder sebagai Subjek Rekayasa
<stakeholder-sebagai-subjek-rekayasa>
Dalam TISE level 5, stakeholder adalah aktor utama. Mereka bukan hanya penerima manfaat, tetapi pembawa misi, pencipta nilai, pengguna artefak, dan sumber pembelajaran.

== Tipologi Stakeholder
<tipologi-stakeholder>
Untuk membuat rekayasa stakeholder menjadi lebih operasional, TISE level 5 mengelompokkan stakeholder ke dalam empat kategori utama, yaitu #strong[USER], #strong[SOURCE], #strong[REGULATOR], dan #strong[PROVIDER].

== Matrix of Mission sebagai Instrumen Rekayasa Stakeholder
<matrix-of-mission-sebagai-instrumen-rekayasa-stakeholder>
Secara umum, bentuk matriks dapat digambarkan sebagaimana dirangkum pada #strong[Tabel 6.1].

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
= Bab 7. MOS-7 sebagai Siklus Operasional
<bab-7.-mos-7-sebagai-siklus-operasional>
== Prinsip Umum
<prinsip-umum>
MOS-7 dalam TISE level 5 diposisikan sebagai #strong[siklus rekayasa stakeholder bermisi]. Setiap putaran MOS-7 mengubah keluhan kemanusiaan menjadi konfigurasi stakeholder, konfigurasi stakeholder menjadi artefak solusi, dan artefak solusi menjadi praktik operasional yang diaudit dan dipelajari kembali.

== Tujuh Langkah MOS-7
<tujuh-langkah-mos-7>
+ #strong[Identify / Hear]
+ #strong[Model / Discern]
+ #strong[Design / Formulate]
+ #strong[Commit / Seek]
+ #strong[Co-Create / Build]
+ #strong[Operate / Delivery]
+ #strong[Evaluate-Audit / Protect]

= Bab 8. Workflow Rekayasa TISE level 5 Full-Scale
<bab-8.-workflow-rekayasa-tise-level-5-full-scale>
== Fase-Fase Utama Workflow Rekayasa
<fase-fase-utama-workflow-rekayasa>
Secara linear, workflow rekayasa TISE level 5 dapat dibagi ke dalam enam fase utama: 1. #strong[Persepsi Masalah] 2. #strong[Konsep dan Model] 3. #strong[Desain dan Planning] 4. #strong[Konstruksi] 5. #strong[Operasional] 6. #strong[Evaluasi]

Untuk memperjelas hubungan antara fase linear, putaran MOS-7, dan penurunan level rekayasa dari TISE level 5 ke TISE level 0, #strong[Tabel 8.1] merangkum workflow rekayasa TISE level 5 secara full-scale.

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Fase Linear], [Fokus Utama], [Putaran MOS-7 yang Dominan], [Level TISE yang Paling Dominan], [Keluaran Utama],),
  table.hline(),
  [Persepsi Masalah], [Mendengar keluhan manusia, mengidentifikasi stakeholder utama, peluang provider, dan alternatif konfigurasi], [Hear, Model], [TISE level 5], [Rumusan persoalan kemanusiaan, daftar stakeholder, alternatif Matrix of Mission],
  [Konsep dan Model], [Membandingkan konfigurasi stakeholder, memilih konfigurasi terbaik, merumuskan arsitektur solusi], [Hear, Model, Design, Commit], [TISE level 5 dan TISE level 4], [Matrix of Mission terpilih, konsep platform, arah artefak anak],
  [Desain dan Planning], [Menurunkan kebutuhan dari level stakeholder ke level DNA desain, naratif, agentik, PSKVE, dan core engineering], [Design, Commit, Build], [TISE level 4, TISE level 3, TISE level 2, TISE level 1], [DNA platform, DNA gagasan baru, desain teater naratif, rancangan PUDAL, rancangan PSKVE, spesifikasi elemen TISE level 0],
  [Konstruksi], [Membangun atau memodifikasi artefak anak, platform, agen, layanan, dan elemen teknis yang diperlukan], [Build, Commit, Operate], [TISE level 4 sampai TISE level 0], [Artefak anak, modul layanan, mekanisme operasi, elemen teknis siap pakai],
  [Operasional], [Menjalankan solusi dalam kehidupan nyata dengan peran USER, SOURCE, REGULATOR, dan PROVIDER], [Operate, Evaluate], [Seluruh level bekerja bersama, dipandu TISE level 5], [Solusi hidup, operasi provider, pengalaman user, legitimasi regulator, value exchange nyata],
  [Evaluasi], [Audit integritas, dampak, keberlanjutan, fairness, dan peluang redesign], [Evaluate, Hear, Model], [TISE level 5], [Hasil evaluasi, audit, pembelajaran, redesign, dan persiapan siklus berikutnya],
)
== Workflow Hipotetikal Full-Scale
<workflow-hipotetikal-full-scale>
+ Menyiapkan TISE level 5 dan MOS-7.
+ Mengembangkan TISE level 4 yang relevan.
+ Mengembangkan TISE level 3 dalam perspektif TISE level 4.
+ Mengembangkan TISE level 2 dalam konteks TISE level 3.
+ Mengembangkan TISE level 1 dalam konteks TISE level 2.
+ Mengembangkan TISE level 0.

#part[Bagian IV. Domain Aplikasi dan Reusability DNA]
= Bab 9. Persoalan Kemanusiaan sebagai Objek Rekayasa
<bab-9.-persoalan-kemanusiaan-sebagai-objek-rekayasa>
Masalah kemanusiaan adalah situasi di mana manusia atau komunitas manusia mengalami hambatan dalam menjalankan misinya, kehilangan agensi, mengalami penderitaan, atau hidup dalam kondisi yang tidak selaras dengan nilai dan martabat kemanusiaannya.

= Bab 10. Domain Aplikasi TISE level 5
<bab-10.-domain-aplikasi-tise-level-5>
Domain aplikasi TISE level 5 dapat mencakup antara lain: 1. makanan sehat; 2. lansia berkualitas; 3. pendidikan teknik abad ke-21; 4. konsentrasi ADHD; 5. decision making masyarakat cerdas; 6. rekayasa finansial untuk proyek IT; 7. personal finance; 8. digital loan.

= Bab 11. Reusability, Modifikasi, dan Rekayasa Berbasis Template DNA
<bab-11.-reusability-modifikasi-dan-rekayasa-berbasis-template-dna>
== Buku DNA sebagai Template Rekayasa
<buku-dna-sebagai-template-rekayasa>
Pada akhirnya, monograf ini dimaksudkan sebagai #strong[Buku DNA] bagi TISE level 5. Artinya, buku ini tidak hanya menjelaskan teori, tetapi menyediakan pola dasar yang dapat digunakan ulang oleh rekayasawan, stakeholder, dan agents dalam domain yang berbeda-beda.

== Elemen Stabil dalam Buku DNA
<elemen-stabil-dalam-buku-dna>
Elemen-elemen yang relatif stabil dan sebaiknya dipertahankan sebagai template umum meliputi: 1. hirarki level rekayasa dari TISE level 0 hingga TISE level 5; 2. konsep energon, core engine, smart engine, PSKVE, PUDAL, identitas naratif, DNA desain, dan Matrix of Mission; 3. tipologi stakeholder USER, SOURCE, REGULATOR, dan PROVIDER; 4. struktur MOS-7; 5. workflow full-scale dari level tertinggi ke level terbawah; 6. prinsip direktif dari manusia untuk manusia.

== Elemen Adaptif yang Dapat Dimodifikasi
<elemen-adaptif-yang-dapat-dimodifikasi>
Bagian-bagian yang dimaksudkan untuk dimodifikasi oleh rekayasawan sesuai konteks antara lain: 1. domain persoalan kemanusiaan yang dipilih; 2. identitas stakeholder utama dan stakeholder pendukung; 3. isi Matrix of Mission; 4. DNA platform yang sudah tersedia dan DNA gagasan baru yang ditambahkan; 5. artefak anak yang ingin dilahirkan; 6. model operasi PROVIDER; 7. indikator evaluasi, audit, dan keberhasilan.

= Bagian V. Pengembangan Ilmiah dan Kelembagaan
<bagian-v.-pengembangan-ilmiah-dan-kelembagaan>
= Bab 12. Proposisi, Agenda Riset, dan Pengembangan Lanjutan
<bab-12.-proposisi-agenda-riset-dan-pengembangan-lanjutan>
== Proposisi Inti TISE level 5
<proposisi-inti-tise-level-5>
+ #strong[Persoalan kemanusiaan abad ke-21 pada umumnya adalah persoalan konfigurasi stakeholder, bukan semata persoalan artefak tunggal.]
+ #strong[Karena itu, mesin utama pada level rekayasa tertinggi bukan hanya mesin teknis, melainkan mesin konfigurasi misi, yaitu Matrix of Mission.]
+ #strong[Keberhasilan solusi tidak hanya ditentukan oleh performa teknis artefak, tetapi oleh kesesuaian misi, benefit, kontribusi, dan komitmen antar stakeholder.]
+ #strong[MOS-7 diperlukan sebagai siklus operasional untuk membentuk, menggerakkan, dan mengevaluasi konfigurasi stakeholder tersebut.]
+ #strong[TISE level 5 diperlukan sebagai bentuk kelembagaan yang memungkinkan mobilisasi potensi manusia secara sistematis untuk memecahkan persoalan kemanusiaan.]

= Bab 13. Kesimpulan: Buku DNA untuk Rekayasawan, Stakeholder, dan Agents
<bab-13.-kesimpulan-buku-dna-untuk-rekayasawan-stakeholder-dan-agents>
TISE level 5 adalah tahap perkembangan paradigma rekayasa cerdas yang menempatkan TISE sebagai pusat keunggulan untuk memecahkan persoalan kemanusiaan. Dengan menjadikan MOS-7 sebagai siklus operasional, TISE level 5 mampu mengubah keluhan manusia menjadi agenda rekayasa, mengubah kombinasi stakeholder menjadi kekuatan kolektif, dan mengubah artefak menjadi solusi yang hidup dalam operasi nyata.

Sebagai Buku DNA, monograf ini menyimpan struktur, prinsip, bahasa, ontologi, workflow, mesin, dan pola-pola desain yang dapat dibaca dan diacu bersama oleh para rekayasawan, stakeholder, dan agents. Setiap pihak tidak perlu membaca seluruh sistem dengan intensitas yang sama; masing-masing dapat membaca bagian yang relevan dengan misi dan perannya. Tetapi justru karena seluruh pihak mengacu pada buku yang sama, konsistensi, kesinambungan, dan reproduktibilitas TISE level 5 dapat dijaga.

= Daftar Pustaka
<daftar-pustaka>
#block[
] <refs>
= Summary
<summary>
In summary, this book has no content whatsoever.

#heading(level: 1, numbering: none)[Daftar Pustaka]
<daftar-pustaka-1>
#block[
] <refs>
#show: appendices.with("Lampiran", hide-parent: true)
#heading(level: 1, numbering: none)[Lampiran]
= Workflow
<workflow>



#bibliography(("references.bib"))

