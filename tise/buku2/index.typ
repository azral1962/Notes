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


#import "@preview/bookly:2.1.2": *


#let config-colors = (
  primary: rgb("#1d90d0"),
  secondary: rgb("#dddddd").darken(15%),
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


// Typst custom formats typically consist of a 'typst-template.typ' (which is
// the source code for a typst template) and a 'typst-show.typ' which calls the
// template's function (forwarding Pandoc metadata values as required)
//
// This is an example 'typst-show.typ' file (based on the default template  
// that ships with Quarto). It calls the typst function named 'article' which 
// is defined in the 'typst-template.typ' file. 
//
// If you are creating or packaging a custom typst template you will likely
// want to replace this file and 'typst-template.typ' entirely. You can find
// documentation on creating typst templates here and some examples here:
//   - https://typst.app/docs/tutorial/making-a-template/
//   - https://github.com/typst/templates
#show: bookly.with(
  title: "Rekayasa Sistem Cerdas",
  author: "Armein Z. R. Langi",
  lang: "id",
  theme: fancy,
  
  tufte: false,

  title-page: book-title-page(
    subtitle: "Arsitektur dan Representasi Pengetahuan",
    series: "Seri TISE Triune Intelligence Smart Engineering",
    institution: "Institut Teknologi Bandung",
  ),
  config-options: (
    open-right: true,
    alt-margins: true,
  ),
)



// IN BEFORE !!!
#set text(
  font: "New Computer Modern", // Font family name
  size: 12pt, // Font size
)

#show: front-matter


#show: main-matter
#states.isfrontmatter.update(true)

#tableofcontents

#listoffigures

#listoftables
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

#heading(level: 1, numbering: none)[Pengantar]
<pengantar>
Buku ini memperkenalkan kerangka kerja #strong[Smart Engineering] yang mengintegrasikan kecerdasan buatan dan alami melalui siklus #strong[PUDAL] untuk menciptakan artefak #strong[PSKVE]. Penulis mengusulkan penggunaan #strong[ontologi] sebagai spesifikasi konsep yang menghubungkan domain aplikasi, sistem, teknologi, dan penelitian fundamental dalam satu struktur terpadu. Implementasi teknisnya memanfaatkan kekuatan gabungan antara #strong[Prolog] untuk penalaran logika simbolik dan #strong[Python] untuk pengolahan data serta simulasi interaktif. Kerangka kerja ini diterapkan dalam studi kasus transportasi masa depan untuk mengevaluasi efisiensi layanan, biaya, dan dampak lingkungan secara holistik. Melalui konsep #strong[Smart Engine Abstraction (SEA)], metode ini menjembatani model konseptual manusia dengan struktur data mesin guna menyelesaikan tantangan rekayasa multidisiplin yang kompleks. Keseluruhan teks memberikan panduan metodologis bagi insinyur untuk membangun sistem cerdas yang mampu melakukan transformasi energi fisik maupun nilai informasi secara transaksional.

#heading(level: 1, numbering: none)[Bagian 1: Konsep Inti Ontologi]
<bagian-1-konsep-inti-ontologi>
Secara formal, #strong[ontologi] didefinisikan sebagai spesifikasi eksplisit dari konseptualisasi bersama yang memodelkan suatu domain pengetahuan. Ontologi menyediakan primitif representasional yang terstruktur sehingga data dan relasi di dalamnya dapat dipahami, dikueri, dan dinalar oleh mesin.

#strong[Konsep Inti Ontologi] Dalam ilmu komputer dan informasi, komponen bangunan fundamental dari ontologi terdiri atas empat elemen:

- #strong[Kelas (#emph[Classes/Concepts]):] Pengelompokan abstrak yang mewakili kumpulan objek dengan karakteristik yang sama (misalnya: entitas Mahasiswa, Kursus, atau Kendaraan). Kelas dapat disusun secara hierarkis sehingga kelas yang lebih spesifik dapat mewarisi properti dari kelas yang lebih umum.

- #strong[Individu (#emph[Individuals/Instances]):] Entitas dasar, konkret, atau spesifik yang menjadi anggota dari suatu kelas. Sebagai contoh, 'Alice Wonderland' adalah individu dari kelas Mahasiswa, atau 'EV\_Sedan' adalah individu dari kelas Kendaraan.

- #strong[Properti (#emph[Properties/Attributes]):] Karakteristik spesifik yang mendeskripsikan individu dalam kelas tertentu, lengkap dengan nama properti dan tipe nilainya (misalnya: ID mahasiswa, atau nilai kecepatan sebuah kendaraan).

- #strong[Relasi (#emph[Relationships]):] Keterkaitan makna semantik yang menghubungkan kelas maupun individu di dalam ontologi. Relasi ini membentuk pola jaringan kompleks, seperti hierarki kepemilikan (#NormalTok("is_a");), komposisi (#NormalTok("part_of");), atau interaksi aksi (misalnya, mahasiswa #NormalTok("enrolls_in"); sebuah kursus).

#strong[Konteksnya dalam Smart Engineering Framework] Dalam paradigma #emph[Smart Engineering], konsep inti ontologi di atas dimanfaatkan secara lebih luas sebagai fondasi model konseptual untuk merancang, memahami, dan memecahkan permasalahan teknis kompleks lintas domain. Peran ontologi dalam kerangka kerja ini mencakup:

- #strong[Pondasi untuk Siklus Kecerdasan (PUDAL):] #emph[Smart Engineering] berpusat pada integrasi Sistem Cerdas (sistem alami dan buatan) yang terus-menerus beroperasi melalui siklus PUDAL: #emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]. Ontologi memberikan basis pengetahuan formal bagi mesin pada tahap #strong["Understand"] dan #strong["Decision-making"], yang memungkinkan agen atau kendaraan cerdas menginterpretasikan keadaan lingkungan serta menarik kesimpulan strategis.

- #strong[Pemodelan Energi PSKVE Multidimensi:] Kerangka ontologi #emph[Smart Engineering] memperluas konsep energi yang biasanya murni berupa fisik menjadi wujud nilai yang lebih luas, yaitu #strong[PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]). Ontologi menstrukturkan bagaimana entitas-entitas teknis mampu melakukan "Konversi Transaksional" antardimensi ini. Misalnya, mengonversi pengetahuan (seperti algoritma baterai EV) menjadi energi nilai (pengurangan biaya) atau layanan (waktu tempuh).

- #strong[Pemecahan Masalah 4 Domain (PICOC):] Ontologi memungkinkan pemecahan sebuah inovasi teknik (seperti desain transportasi canggih) ke dalam empat lapisan domain: #emph[Application] (Kebutuhan Pengguna), #emph[System] (Kendaraan/Sistem Utama), #emph[Technology] (Mesin/Teknologi Inti), dan #emph[Fundamental Research] (Prinsip Dasar).

- #strong[Implementasi Platform Hibrida (Prolog-Python):] Untuk mengimplementasikan ontologi ke dalam aplikasi teknik yang nyata, kerangka #emph[Smart Engineering] menggunakan bahasa #strong[Prolog] (di mana kelas, properti, individu, dan relasi ontologi dikonversi menjadi fakta dan aturan logika) yang digabungkan dengan #strong[Python] sebagai penyedia daya algoritmik dan antarmuka simulasi. Sebagai contoh praktis, ontologi Prolog digunakan untuk menyimpan data properti kendaraan dan rute untuk tahun 2030, lalu aplikasi Python menjalankan simulasi kueri untuk mengalkulasi efisiensi biaya maupun pengurangan emisi CO2 lintas rute Bandung-Jakarta.

= Sistem Cerdas & Siklus PUDAL
<sistem-cerdas-siklus-pudal>
Dalam kerangka #emph[Smart Engineering], #strong[Sistem Cerdas (#emph[Intelligent Systems])] didefinisikan sebagai entitas yang mampu menjalankan siklus #strong[PUDAL] (#emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]). Siklus fundamental ini membuat sebuah sistem mampu menerima stimulus eksternal, bersifat adaptif, memiliki otonomi, berorientasi pada tujuan, serta mampu menghasilkan respons dan peningkatan performa internal.

Ontologi berperan sebagai lapisan fondasi yang sangat penting bagi arsitektur Sistem Cerdas karena menyediakan kerangka kosakata dan struktur data yang dapat dimengerti oleh mesin (#emph[machine-understandable]). Jika dihubungkan dengan #strong[Konsep Inti Ontologi] (yang berpusat pada elemen #emph[Kelas], #emph[Individu], #emph[Properti], dan #emph[Relasi]), tahapan-tahapan siklus PUDAL pada Sistem Cerdas beroperasi sebagai berikut:

- #strong[Perceive (Mempersepsikan) & Understand (Memahami):] Ketika Sistem Cerdas mengumpulkan data mentah (stimulus) dari lingkungannya melalui sensor, ontologi digunakan untuk menyusun dan menginterpretasikan data tersebut menjadi model representasi realitas. Data ini diklasifikasikan sebagai representasi #strong[Individu] (entitas spesifik) yang merupakan bagian dari #strong[Kelas] (kategori konsep) tertentu. Mesin memberikan makna pada data dengan memetakan #strong[Properti] (atribut data) dan membangun #strong[Relasi] (keterkaitan semantik) dari objek-objek tersebut sesuai kerangka ontologi yang disepakati.

- #strong[Decision-making & Planning (Pengambilan Keputusan):] Berdasarkan pemahaman terstruktur dari langkah sebelumnya, sistem memilih tindakan atau rencana yang paling tepat. Basis pengetahuan ontologis memberdayakan sistem mesin logika (seperti bahasa Prolog) untuk melakukan penalaran algoritmik otomatis (#emph[automated reasoning]). Sistem menggunakan aturan-aturan logis (#emph[rules]) terhadap relasi dan kelas yang ada untuk menarik kesimpulan logis baru yang belum tertulis secara eksplisit, yang sangat krusial dalam pengambilan keputusan.

- #strong[Act-Response (Bertindak) & Learning-evaluating (Mengevaluasi/Belajar):] Sistem kemudian mengeksekusi pilihan aksinya ke dalam modifikasi lingkungan dan menilai apakah hasil aksinya berhasil. Proses "belajar" pada mesin dapat diwujudkan dengan menggunakan ontologi dinamis, di mana hasil dari evaluasi aksi dapat dikonversi menjadi fakta logis baru. Sistem memperbarui basis pengetahuannya dengan memodifikasi #strong[Properti], memasukkan #strong[Individu] baru, atau mendefinisikan #strong[Relasi] baru, yang akan meningkatkan performa pada siklus PUDAL di masa depan.

Dalam konteks #emph[Smart Engineering] yang lebih luas, ontologi dan siklus PUDAL diaplikasikan dalam dua bentuk utama:

+ #strong[Pada Artefak Rekayasa (PSVKE):] Produk akhir yang dihasilkan berupa artefak bernilai PSKVE (#emph[Product, Service, Knowledge, Value, Environment]) yang tersemat komponen cerdas di dalamnya, di mana mesin berinteraksi secara cerdas dengan penggunanya.

+ #strong[Pada Proses Rekayasanya Sendiri:] Proses desain dan evaluasi dari tim insinyur itu sendiri diperlakukan layaknya sebuah sistem cerdas yang menjalankan siklus mirip PUDAL. Tim menggunakan pemodelan ontologi untuk mengurai kompleksitas secara interdisipliner, memastikan model konseptual dari pikiran manusia selaras dengan struktur data logis yang akan dinalar oleh sistem komputasi (kecerdasan buatan). Paradigma gabungan (#emph[human-machine paradigm]) ini dirancang untuk dapat mengamplifikasi kemampuan dari kecerdasan alami manusia melalui komputasi.

== Perceive (Persepsi)
<perceive-persepsi>
Dalam siklus PUDAL (#emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]) yang menjadi karakteristik utama dari sebuah Sistem Cerdas, #strong[tahap Perceive (Persepsi) berfungsi sebagai langkah paling awal dan gerbang masuknya informasi]. Siklus ini selalu diawali atau dipicu ketika sebuah sistem cerdas menerima stimulus.

Secara spesifik, #strong[tahap] #strong[Perceive] #strong[adalah proses di mana sistem mengumpulkan data, baik dari lingkungan eksternalnya maupun dari status internalnya sendiri]. Untuk menangkap data tersebut, sistem cerdas #strong[menggunakan sensor atau berbagai mekanisme masukan (input) lainnya]. Data mentah yang berhasil dikumpulkan pada tahap persepsi ini sangat esensial karena menjadi bahan dasar yang akan diteruskan ke tahap #emph[Understand], di mana sistem memproses dan menginterpretasikan data tersebut untuk membangun model pemahaman terhadap situasi saat itu.

Dalam paradigma #emph[Smart Engineering], konsep "Perceive" diterapkan secara berlapis pada dua jenis Sistem Cerdas:

- #strong[Pada Artefak atau Sistem Mesin:] Entitas cerdas (seperti kendaraan otonom atau platform digital) mengandalkan sensor fisikal maupun input data untuk mempersepsikan lingkungannya. Kemampuan persepsi inilah yang pada akhirnya memungkinkan mesin untuk menjadi entitas yang adaptif, berorientasi pada tujuan, dan dapat bertindak secara otonom di dunia nyata.

- #strong[Pada Proses Rekayasa (Tim Insinyur):] Proses perancangan (#emph[engineering process]) yang dilakukan oleh manusia juga dipandang sebagai sebuah sistem cerdas yang menjalankan siklus menyerupai PUDAL. Dalam konteks ini, tahap "Perceive" terjadi ketika #strong[para insinyur mempersepsikan atau menangkap kebutuhan pengguna (user needs) beserta batasan-batasan (constraints) dari masalah yang ada]. Persepsi awal dari insinyur ini menjadi landasan untuk memahami domain masalah sebelum merancang dan mengimplementasikan artefak.

Singkatnya, tahapan #emph[Perceive] merupakan fondasi observasional yang krusial, tanpanya Sistem Cerdas (baik yang berupa kecerdasan buatan maupun tim perancang manusia) tidak akan memiliki konteks apa pun untuk dipahami, diputuskan, dan dipelajari.

== Understand (Memahami)
<understand-memahami>
Dalam siklus PUDAL (#emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]) yang menjadi motor penggerak sebuah Sistem Cerdas, tahap #strong[Understand (Memahami) merupakan proses di mana sistem memproses dan menginterpretasikan data yang telah dikumpulkan pada tahap persepsi].

Tujuan utama dari tahapan ini adalah #strong[untuk membangun sebuah model atau representasi dari situasi saat itu beserta konteksnya]. Jika tahap #emph[Perceive] (Persepsi) hanya berfungsi menangkap data mentah (stimulus) dari lingkungan, maka tahap #emph[Understand] adalah momen di mana sistem---baik itu mesin buatan maupun pikiran manusia---memberikan makna, struktur, dan konteks pada data tersebut.

Dalam paradigma #emph[Smart Engineering], proses "Memahami" ini diaplikasikan pada dua dimensi utama:

- #strong[Pada Artefak atau Sistem Komputasi:] Agar sebuah mesin buatan dapat "memahami" lingkungannya, ia memerlukan struktur pengetahuan formal, seperti #strong[ontologi], yang membuat data tersebut dapat dimengerti oleh mesin (#emph[machine-understandable]). Pada tahap ini, agen cerdas mengonversi sinyal sensor menjadi representasi konseptual (misalnya, mengenali bahwa suatu objek adalah entitas dari kelas tertentu dengan properti khusus). Representasi situasional inilah yang mutlak diperlukan sebelum mesin dapat beralih ke tahap #emph[Decision-making & Planning] untuk memilih tindakan yang rasional dan adaptif.

- #strong[Pada Proses Rekayasa (Tim Insinyur):] Desain rekayasa itu sendiri dipandang sebagai sebuah sistem cerdas di mana tim insinyur manusia juga beroperasi melalui siklus yang mirip dengan PUDAL. Dalam konteks manusia, tahap #emph[Understand] direpresentasikan oleh momen di mana #strong[insinyur memahami domain permasalahan secara holistik setelah mempersepsikan kebutuhan pengguna dan batasan-batasan desain]. Pemahaman konseptual yang mendalam ini sangat krusial agar solusi teknis yang akan dirancang benar-benar relevan dengan masalah yang ada.

Secara keseluruhan, tahapan #emph[Understand] bertindak sebagai #strong[jembatan kognitif] yang vital. Tanpa kemampuan untuk menerjemahkan data mentah menjadi sebuah representasi dan konteks yang terstruktur, suatu Sistem Cerdas tidak akan memiliki dasar pengetahuan (baik logis maupun intuitif) untuk merencanakan keputusan atau belajar dari pengalaman.

== Decision (Keputusan)
<decision-keputusan>
Dalam siklus PUDAL (#emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]) yang menjadi inti penggerak sebuah Sistem Cerdas, tahap #strong[Decision-making & Planning (Pengambilan Keputusan dan Perencanaan)] merupakan fase penentuan arah tindakan. Pada tahap ini, #strong[sistem secara spesifik memilih rencana atau tindakan yang paling sesuai berdasarkan pemahaman situasional dan tujuan yang ingin dicapainya].

Fase pengambilan keputusan ini sangat krusial karena ia secara fundamental memungkinkan sebuah Sistem Cerdas untuk menjadi entitas yang adaptif, berorientasi pada tujuan, serta memiliki kemampuan untuk beroperasi secara otonom dalam berbagai tingkatan.

Dalam kerangka kerja #emph[Smart Engineering], proses "Keputusan" ini diterapkan pada dua area fungsional:

- #strong[Pengambilan Keputusan oleh Komputasi Mesin:] Agar mesin dapat mengambil keputusan yang rasional dan cerdas, mereka mengandalkan kemampuan penalaran dari platform berbasis pengetahuan (seperti integrasi bahasa pemrograman Prolog). Pada tahap ini, mesin memproses data yang telah terstruktur menggunakan aturan logika formal dan mesin inferensi untuk #strong[mengevaluasi batasan, memverifikasi konsistensi, dan menarik kesimpulan logis yang tidak terlihat secara kasat mata (non-obvious conclusions)]. Contoh nyata dari tahap ini pada sistem mesin adalah saat program secara otomatis menghasilkan keputusan diagnostik dari suatu kegagalan alat atau mengevaluasi apakah suatu syarat desain sudah terpenuhi sebelum melakukan eksekusi sistem.

- #strong[Pengambilan Keputusan oleh Tim Insinyur Manusia:] Paradigma #emph[Smart Engineering] juga memandang proses desain yang dilakukan oleh manusia sebagai sebuah Sistem Cerdas itu sendiri. Dalam proses operasional tim insinyur, setelah mereka selesai menangkap batasan (Persepsi) dan menganalisis domain permasalahan (Memahami), tahap keputusan direpresentasikan sebagai momen di mana #strong[para insinyur secara kolektif membuat keputusan-keputusan desain teknis]. Keputusan desain inilah yang pada akhirnya menjadi dasar rencana yang akan diwujudkan dalam implementasi pembuatan purwarupa (yang masuk ke dalam fase #emph[Act]).

Secara keseluruhan, tahap Pengambilan Keputusan merupakan titik transisi utama di mana sebuah Sistem Cerdas mengonversi pemahaman observasionalnya menjadi sebuah rencana intervensi strategis untuk menyelesaikan masalah atau mencapai target yang ditetapkan.

== Act (Tindakan)
<act-tindakan>
Dalam siklus PUDAL (#emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]) yang mendasari Sistem Cerdas, tahap #strong[Act-Response (Tindakan) adalah fase eksekusi di mana rencana atau keputusan diwujudkan ke dalam bentuk tindakan nyata].

Setelah sistem memproses data (Persepsi), membangun konteks (Memahami), dan memilih strategi (Keputusan), tahap #emph[Act-Response] merupakan #strong[momen di mana sistem secara aktif mengeksekusi tindakan yang dipilihnya untuk berinteraksi dengan, atau memodifikasi, lingkungannya]. Tahap ini merepresentasikan "respons" langsung sistem terhadap "stimulus" awal yang diterimanya.

Sama seperti tahapan sebelumnya dalam kerangka #emph[Smart Engineering], konsep "Tindakan" ini diimplementasikan dalam dua dimensi utama:

- #strong[Pada Sistem Mesin atau Artefak Cerdas:] Tahap #emph[Act] terjadi ketika mesin melakukan intervensi fisik atau komputasional. Berdasarkan konsep #emph[Smart Engine Abstraction] (SEA), entitas mesin cerdas bertindak dengan #strong[mengonversi input (seperti gaya atau energi mentah) menjadi output yang memiliki nilai (solusi atau pekerjaan)]. Sebagai contoh pada sistem transportasi, tahap ini adalah saat sistem kontrol kendaraan (#emph[vehicle]) benar-benar mengeksekusi navigasi fisik di jalan raya setelah memutuskan rute terbaik.

- #strong[Pada Proses Rekayasa (Tim Insinyur Manusia):] Dalam memandang proses kerja insinyur sebagai sebuah sistem cerdas, tahap #emph[Act] merupakan transisi dari sekadar konsep di atas kertas menjadi realitas fisik. Para insinyur "bertindak" melalui #strong[kegiatan implementasi teknis dan pembuatan purwarupa (prototyping)]. Mereka mengeksekusi desain yang telah diputuskan sebelumnya untuk menciptakan artefak rekayasa yang nyata.

Dalam konteks siklus PUDAL secara keseluruhan, tahap #strong[Tindakan (Act) bertindak sebagai pemicu perubahan di dunia nyata]. Eksekusi dari mesin maupun insinyur ini akan menghasilkan dampak atau memodifikasi lingkungan sekitarnya. Efek dari tindakan inilah yang kemudian akan diukur, dinilai, dan dijadikan bahan pembelajaran pada tahap akhir siklus, yaitu #emph[Learning-evaluating] (Belajar/Mengevaluasi).

== Learning (Belajar)
<learning-belajar>
Dalam siklus PUDAL (#emph[Perceive, Understand, Decision-making & planning, Act-Response, Learning-evaluating]), tahap #strong[Learning-evaluating (Belajar dan Mengevaluasi)] adalah fase pamungkas yang memastikan sebuah Sistem Cerdas dapat terus berkembang.

Setelah sistem mengeksekusi sebuah keputusan di dunia nyata pada tahap #emph[Act], tahap #emph[Learning] adalah proses di mana #strong[sistem menilai atau mengevaluasi hasil (kegagalan maupun keberhasilan) dari tindakan tersebut]. Berdasarkan hasil penilaian ini, sistem kemudian #strong[memperbarui pengetahuan atau model internalnya untuk meningkatkan performanya di masa depan]. Fase ini berfokus pada upaya sistem untuk menghasilkan perbaikan internal.

Kemampuan "Belajar" ini merupakan hal yang sangat fundamental karena #strong[inilah kunci utama yang membuat sebuah sistem mampu menjadi entitas yang adaptif, memiliki otonomi, dan secara konsisten berorientasi pada tujuan].

Dalam kerangka #emph[Smart Engineering], konsep belajar dan mengevaluasi ini diterapkan secara berkesinambungan pada dua elemen utama:

- #strong[Pada Sistem Mesin (Artefak Cerdas):] Setelah agen cerdas (seperti kendaraan otonom atau perangkat lunak analitik) bertindak, ia mengukur efek dari tindakannya tersebut. Mesin kemudian memodifikasi basis pengetahuannya (seperti memperbarui fakta atau aturan dalam model ontologi/Prolog) agar perhitungan dan keputusannya di siklus PUDAL berikutnya menjadi lebih akurat, efisien, dan relevan dengan perubahan lingkungan.

- #strong[Pada Proses Rekayasa (Tim Insinyur):] Proses desain rekayasa yang dilakukan manusia juga mengandalkan tahap evaluasi ini. Bagi para insinyur, fase #emph[Learning] terjadi ketika mereka #strong[mengevaluasi hasil pengujian (testing) dan mengumpulkan umpan balik (feedback) dari purwarupa yang telah mereka buat]. Evaluasi observasional ini memberi para insinyur pengetahuan baru yang digunakan untuk melakukan iterasi, merevisi desain, dan memperbaiki solusi teknis pada siklus pengembangan selanjutnya.

= Artefak PSKVE
<artefak-pskve>
Dalam paradigma #emph[Smart Engineering], hasil akhir dari proses rekayasa tidak lagi dipandang sekadar sebagai benda fisik mekanis, melainkan sebagai #strong[Artefak PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]). Artefak ini dirancang untuk menjadi entitas cerdas---atau memiliki komponen kecerdasan di dalamnya---yang mampu berinteraksi secara holistik dengan pengguna maupun lingkungannya.

Agar mesin komputasi atau perangkat lunak dapat merancang, mengevaluasi, dan menyimulasikan kompleksitas dari artefak cerdas ini, kerangka kerjanya menggunakan #strong[Konsep Inti Ontologi]. Ontologi menyediakan struktur formal bagi sistem (seperti basis pengetahuan pada bahasa Prolog) untuk memetakan kelima dimensi PSKVE ke dalam bentuk yang dapat dinalar oleh mesin ( #emph[machine-understandable] ), menggunakan empat komponen bangunan utamanya: Kelas, Individu, Properti, dan Relasi.

Hubungan antara Artefak PSKVE dengan Konsep Inti Ontologi dapat dipetakan sebagai berikut:

- #strong[Kelas (Classes) dan Individu (Individuals) sebagai Wujud Artefak:] Di dalam basis pengetahuan ontologis, entitas fisik atau abstrak dari Artefak PSKVE didefinisikan sebagai #strong[Individu] yang bernaung di bawah suatu #strong[Kelas]. Sebagai contoh nyata dalam simulasi transportasi cerdas, "EV\_Sedan" atau "High-Speed Electric Train" adalah entitas individu spesifik di dalam kelas "Kendaraan" (merepresentasikan dimensi #emph[Product] secara fisik) yang keberadaannya dideklarasikan secara eksplisit agar mesin dapat mengenalinya.

- #strong[Properti (Properties) sebagai Pengukur Dimensi PSKVE:] Kelima dimensi energi PSKVE yang abstrak tersebut diterjemahkan secara komputasional menjadi atribut atau #strong[Properti] yang melekat pada individu artefak tersebut.

- #strong[Product Energy] (energi fisik artefak) dimodelkan melalui properti teknis seperti kapasitas penumpang atau konsumsi bahan bakar.

- #strong[Service Energy] (interaksi dan layanan) dimodelkan melalui properti performa seperti estimasi waktu tempuh atau tingkat keandalan (MTBF).

- #strong[Knowledge Energy] (algoritma/informasi) dimodelkan melalui properti tingkat kesiapan teknologi (TRL) atau kompleksitas model data kecerdasan buatan yang disematkan ke dalam artefak.

- #strong[Value Energy] (nilai ekonomis/sosial) dimodelkan melalui properti biaya per penumpang, harga tiket, atau penghematan siklus hidup.

- #strong[Environmental Space Energy] (dampak lingkungan/ruang) dimodelkan melalui properti jejak karbon (emisi CO2), efisiensi lahan, hingga tingkat polusi suara.

- #strong[Relasi (Relationships) sebagai Konversi Transaksional:] Salah satu karakteristik utama Artefak PSKVE adalah kemampuannya melakukan "Konversi Transaksional", yaitu pertukaran atau transformasi antardimensi PSKVE. Di dalam ontologi, proses ini diwujudkan melalui #strong[Relasi] berwujud aturan logika (#emph[rules]) yang saling mengaitkan satu properti dengan properti lain secara multi-domain. Contoh interaksi transaksional ini adalah bagaimana mesin menyimulasikan bahwa keberadaan #emph[Knowledge Energy] (perangkat lunak cerdas untuk baterai EV) akan memberikan efek pada #emph[Product Energy] (kinerja mesin yang lebih efisien), yang secara logis memiliki relasi langsung pada perbaikan #emph[Environmental Space Energy] (emisi CO2 yang lebih rendah) dan #emph[Value Energy] (total biaya operasional yang lebih murah).

Secara keseluruhan, pemanfaatan ontologi berfungsi sebagai fondasi bahasa formal yang memastikan seluruh aspek multidimensional dan interdisipliner dari Artefak PSKVE tidak hanya menjadi konsep bisnis di atas kertas, tetapi memiliki struktur data riil yang bisa dinalar, dioptimalkan, dan dieksekusi secara terkomputasi oleh kecerdasan buatan.

== Product (Produk)
<product-produk>
Dalam paradigma #emph[Smart Engineering], luaran atau hasil akhir dari proses rekayasa disebut sebagai #strong[Artefak PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]), yaitu artefak yang cerdas atau memiliki komponen cerdas yang tersemat di dalamnya.

Di dalam kerangka energi multidimensional ini, #strong[Product (Produk)] direpresentasikan secara lebih spesifik sebagai #strong[Product Energy (Energi Produk)]. Sumber mendefinisikan #emph[Product Energy] sebagai energi fisik atau alamiah, baik yang masih berbentuk bawaan maupun yang telah dikonversi, yang berada di dalam sebuah produk fisik. Contoh nyata dari wujud #emph[Product Energy] ini adalah energi kimia yang tersimpan di dalam sebuah baterai atau energi kinetik penggerak yang dihasilkan oleh sebuah mesin.

Dalam konteks Artefak PSKVE yang lebih luas, "Produk" tidak berdiri sendiri, melainkan berinteraksi secara dinamis dengan empat dimensi energi lainnya melalui proses yang disebut sebagai #strong[Konversi Transaksional (Transactional Conversion)]. Berikut adalah wujud interaksi energi produk dalam sistem rekayasa:

- #strong[Interaksi dengan Dimensi Value (Nilai) dan Service (Layanan):] Dalam perekonomian #emph[Smart Engineering], interaksi pengguna selalu melibatkan pertukaran antardimensi energi ini. Sebagai contoh, seorang konsumen menukarkan energi finansial (#emph[Value Energy]) untuk membeli sebuah perangkat pintar, yang memberikannya akses terhadap bentuk fisik alat tersebut (#emph[Product Energy]) beserta teknologi cerdas di dalamnya (#emph[Knowledge Energy]). Contoh lain pada transportasi, seorang penumpang menukarkan uang tiket (#emph[Value Energy]) untuk menikmati perpindahan lokasi (#emph[Service Energy]) melalui operasional sebuah kendaraan fisik (#emph[Product Energy]).

- #strong[Interaksi dengan Dimensi Knowledge (Pengetahuan) dan Environment (Lingkungan):] Dimensi pengetahuan sangat krusial dalam memaksimalkan potensi sebuah produk. Pengetahuan yang disematkan ke dalam produk---seperti algoritma pintar pada sistem baterai EV---secara langsung akan meningkatkan performa dan efisiensi dari #emph[Product Energy] itu sendiri. Tingkat efisiensi energi produk fisik inilah yang pada akhirnya menentukan seberapa besar dampak artefak tersebut terhadap #emph[Environmental Space Energy] (misalnya penekanan tingkat emisi gas buang CO2).

Dari kacamata perancangan sistem rekayasa (Domain Sistem dan Teknologi), dimensi "Produk" menjadi fokus optimalisasi mesin cerdas. Dalam Domain Sistem, entitas kendaraan dipandang sebagai agen yang bertugas mengelola ketersediaan #emph[Product Energy] (seperti bahan bakar atau listrik). Sementara pada Domain Teknologi, sebuah #emph[smart engine] bertugas menjalankan siklus cerdasnya (PUDAL) untuk mencari cara paling efisien dalam mengonversi #emph[Product Energy] tersebut menjadi energi kerja mekanis murni.

Singkatnya, dalam #emph[Smart Engineering], sebuah "Produk" tidak lagi dilihat sekadar sebagai cangkang material fisik, melainkan sebagai wadah pengonversi energi (#emph[Product Energy]) yang secara terus-menerus bertransaksi dan saling memengaruhi dengan layanan yang diberikan, pengetahuan yang ditanamkan, nilai ekonomis yang dihasilkan, dan lingkungan di sekitarnya.

== Service (Layanan)
<service-layanan>
Dalam kerangka rekayasa #emph[Smart Engineering], hasil akhir dari sebuah perancangan disebut sebagai #strong[Artefak PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]), yaitu artefak yang terintegrasi dengan kecerdasan agar mampu berinteraksi secara cerdas dengan penggunanya maupun lingkungannya.

Di dalam model multi-dimensi energi ini, #strong[Service (Layanan)] secara spesifik dikonseptualisasikan sebagai #strong[Service Energy] #strong[\(Energi Layanan)]. Energi Layanan didefinisikan sebagai energi yang dikeluarkan atau ditangkap melalui proses penyediaan dan konsumsi sebuah layanan, yang secara kuat berkaitan dengan #strong[metrik perhatian (attention), waktu, dan tingkat interaksi]. Contoh wujud nyata dari dimensi ini adalah seberapa lama waktu dan perhatian yang diinvestasikan pengguna saat berinteraksi dengan sebuah platform digital.

Dalam konteks Artefak PSKVE yang lebih luas, dimensi Layanan selalu terikat dalam proses dinamis yang disebut #strong[Konversi Transaksional], di mana ia saling bertukar wujud dengan dimensi energi lainnya:

- #strong[Interaksi dengan Value (Nilai) dan Product (Produk):] Dalam simulasi seperti transportasi publik, seorang penumpang melakukan konversi transaksional dengan menukarkan uang tiket (#emph[Value Energy]) untuk bisa mendapatkan efisiensi perpindahan lokasi (#emph[Service Energy]), yang difasilitasi oleh operasional mesin kendaraan fisik (#emph[Product Energy]).

- #strong[Interaksi dengan Knowledge (Pengetahuan):] Pada jenis layanan digital, pengguna mungkin mengorbankan waktu dan perhatian interaktif mereka (#emph[Service Energy]) untuk dapat mengekstraksi informasi yang dibutuhkan (#emph[Knowledge Energy]) atau mendapatkan hiburan (#emph[Value Energy]).

Agar sistem mesin atau model ontologi dapat mengevaluasi dan membandingkan kualitas "Layanan" dari suatu artefak cerdas, konsep layanan ini harus dikuantifikasi ke dalam properti yang terukur.

- #strong[Efisiensi Waktu:] Dalam studi simulasi transportasi rute Bandung-Jakarta, Energi Layanan secara utama diukur menggunakan #strong[estimasi waktu tempuh perjalanan]. Sebagai contoh, moda Kereta Cepat (#emph[High-Speed Train]) tercatat menawarkan performa terbaik dari aspek Energi Layanan karena mampu memberikan efisiensi waktu perjalanan tercepat bagi penumpangnya.

- #strong[Kualitas Interaksi:] Untuk pengembangan model ontologi yang lebih mutakhir di masa depan, kuantifikasi dimensi #emph[Service Energy] disarankan untuk diperluas ke berbagai metrik kualitas, seperti #strong[tingkat keandalan sistem (MTBF -] #strong[Mean Time Between Failures), indeks kenyamanan pengguna, serta seberapa mudah layanan tersebut diakses (accessibility) oleh beragam kelompok demografi pengguna].

Singkatnya, dimensi Layanan di dalam Artefak PSKVE menempatkan waktu, interaksi, dan kenyamanan manusia sebagai bentuk energi berharga. Sistem #emph[Smart Engineering] bertujuan merancang mesin dan algoritma agar proses transformasi dari energi fisik produk menjadi layanan ini bisa berjalan seefisien dan sebaik mungkin.

== Knowledge (Pengetahuan)
<knowledge-pengetahuan>
Dalam kerangka rekayasa #emph[Smart Engineering], luaran atau hasil dari sebuah perancangan disebut sebagai #strong[Artefak PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]) yang dirancang untuk memiliki komponen cerdas di dalamnya. Di dalam model energi multidimensional ini, #strong[Knowledge (Pengetahuan)] secara spesifik dikonseptualisasikan sebagai #strong[Energi Pengetahuan (Knowledge Energy)].

#strong[Definisi dan Wujud Energi Pengetahuan] Energi Pengetahuan didefinisikan sebagai energi intelektual atau informasional yang terwujud dalam bentuk skema, algoritma, kepakaran/keahlian, serta pengetahuan operasional ("#emph[how-to]"). Contoh nyata dari wujud energi pengetahuan ini adalah logika atau struktur instruksi di dalam sebuah model Kecerdasan Buatan (AI). Pada tingkat Teknologi (Domain Teknologi), #emph[Knowledge Energy] inilah yang diintegrasikan ke dalam sebuah #emph[smart engine] (mesin cerdas) agar mesin tersebut mampu menjalankan siklus PUDAL dan mengoptimalkan operasinya.

#strong[Konversi Transaksional dengan Dimensi PSKVE Lainnya] Sama seperti dimensi produk atau layanan, #emph[Knowledge Energy] di dalam artefak dirancang untuk secara konstan berinteraksi dan bertransformasi dengan dimensi energi lainnya melalui proses "Konversi Transaksional":

- #strong[Meningkatkan Kualitas Produk dan Lingkungan:] Pengetahuan cerdas yang disematkan ke dalam sistem secara langsung mengendalikan performa mesin. Sebagai contoh simulasi transportasi, #emph[Knowledge Energy] yang tertanam dalam algoritma teknologi baterai kendaraan listrik (EV) atau pada sistem manajemen #emph[smart grid] (jaringan cerdas) akan secara langsung mengefisienkan #emph[Product Energy] (konsumsi daya fisik). Efisiensi tersebut secara logis akan menekan dampak emisi gas buang, yang berarti memperbaiki kualitas #emph[Environmental Space Energy].

- #strong[Bertransaksi dengan Layanan dan Nilai:] Dari kacamata ekonomi dan interaksi pengguna, konsumen menukarkan biaya finansial (#emph[Value Energy]) untuk mendapatkan perangkat fisik (#emph[Product Energy]) beserta Energi Pengetahuan yang tertanam di dalamnya. Selain itu, pengguna kerap menginvestasikan waktu serta atensi mereka (#emph[Service Energy]) untuk menggali informasi dari sistem cerdas tersebut (#emph[Knowledge Energy]). Tantangan riset ke depan adalah mencari model matematis konversi dari seberapa besar "energi pengetahuan" pada sebuah perangkat lunak bisa secara efektif dikonversi menjadi "energi nilai" komersial (#emph[Value Energy]).

#strong[Kuantifikasi dalam Pemodelan (Ontologi)] Agar #emph[Knowledge Energy] ini dapat dimasukkan, diukur, dan disimulasikan oleh mesin penalaran (seperti pada model ontologi Prolog), dimensi abstrak ini harus diurai menjadi kumpulan metrik atau properti yang dapat dikuantifikasi. Beberapa properti pengukur tingkat #emph[Knowledge Energy] pada suatu artefak meliputi .:

- #strong[TRL (Technology Readiness Level] #strong[\/ Tingkat Kesiapan Teknologi):] Seberapa matang pengetahuan teknis tersebut bisa diaplikasikan.

- #strong[Kompleksitas Algoritma:] Tingkat kerumitan dan kapabilitas komputasi dari perangkat lunak yang mendasarinya.

- #strong[Kebutuhan Data (Data Requirements):] Kuantitas dan kualitas data yang diwajibkan agar komponen sistem AI bisa berfungsi optimal.

Singkatnya, di dalam konsep Artefak PSKVE, "Pengetahuan" bukan sekadar buku panduan manual, melainkan diperlakukan sebagai #strong[energi intelektual (seperti algoritma dan AI) penggerak utama mesin] yang menjembatani efisiensi performa perangkat fisik, nilai ekonomi pengguna, hingga keamanan bagi lingkungan sekitarnya.

== Value (Nilai)
<value-nilai>
Dalam kerangka desain #emph[Smart Engineering], luaran atau hasil akhir dari proses rekayasa disebut sebagai #strong[Artefak PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam model energi multidimensional ini, dimensi #strong[Value (Nilai)] dikonseptualisasikan secara khusus sebagai #strong[Energi Nilai (Value Energy)].

#strong[Definisi Energi Nilai] #emph[Value Energy] merepresentasikan #strong[potensi atau kelayakan nyata (realized worth) dari sebuah artefak, yang wujudnya tidak terbatas pada metrik uang atau finansial, tetapi juga meluas pada nilai sosial, budaya, hingga reputasi]. Contoh nyata dari perwujudan dimensi nilai ini adalah tingkat kapitalisasi pasar dari suatu produk atau tingkat pengaruh sosial yang dihasilkannya di masyarakat.

#strong[Konversi Transaksional dengan Dimensi PSKVE Lainnya] Di dalam sebuah Artefak PSKVE, Energi Nilai bersifat dinamis karena terus-menerus berinteraksi dan bertukar wujud dengan dimensi-dimensi lainnya melalui mekanisme "Konversi Transaksional".

- #strong[Interaksi Produk, Pengetahuan, dan Layanan:] Konsumen melakukan konversi ini dalam kehidupan sehari-hari, contohnya dengan menukarkan uang (#emph[Value Energy]) untuk membeli sebuah perangkat keras pintar (#emph[Product Energy]) yang digerakkan oleh algoritma cerdas (#emph[Knowledge Energy]).- Pada contoh layanan transportasi, penumpang secara harfiah menukarkan uang mereka (#emph[Value Energy]) demi mendapatkan jasa efisiensi waktu perjalanan (#emph[Service Energy]) melalui pemanfaatan mesin kendaraan tersebut (#emph[Product Energy]).- Selain itu, saat pengguna menggunakan sebuah platform digital, mereka menginvestasikan waktu dan perhatian (#emph[Service Energy]) untuk mengekstraksi informasi (#emph[Knowledge Energy]) atau sekadar mendapatkan hiburan dan manfaat lainnya (#emph[Value Energy]).

#strong[Kuantifikasi dan Metrik Evaluasi] Agar #emph[Value Energy] ini dapat dimasukkan ke dalam model ontologi (seperti Prolog) dan dioptimalkan oleh kecerdasan buatan, nilai abstrak ini harus diterjemahkan menjadi metrik yang terukur secara komputasional:

- #strong[Total Biaya:] Pada studi simulasi perbandingan transportasi rute Bandung-Jakarta tahun 2030, #emph[Value Energy] dievaluasi dengan menggunakan metrik #strong[total biaya per penumpang]. Ini dikalkulasi dengan mengakumulasikan seluruh biaya energi/bahan bakar, tarif jalan tol, alokasi biaya perawatan tahunan (untuk moda seperti bus atau mobil listrik pribadi), atau menggunakan harga tiket langsung (untuk kereta cepat).

- #strong[Perluasan Metrik Ekonomi dan Sosial:] Untuk perancangan artefak cerdas yang lebih komprehensif di masa depan, sumber-sumber menyarankan agar pengukuran dimensi Nilai ini diperluas. Metrik yang diusulkan mencakup #strong[perhitungan Biaya Siklus Hidup yang utuh (Full Lifecycle Costing] #strong[\/ LCC), analisis biaya-manfaat bagi masyarakat, probabilitas penciptaan lapangan kerja, serta seberapa besar dampak artefak tersebut terhadap perkembangan ekonomi lokal].

Salah satu fokus riset fundamental di masa depan dalam kerangka #emph[Smart Engineering] adalah mengembangkan pemodelan formal untuk mengukur tingkat konversi antar-dimensi ini. Sebagai contoh, para peneliti harus merumuskan bagaimana metrik abstrak dari #emph[Knowledge Energy] (seperti kebaruan perangkat lunak buatan insinyur) dapat dikonversi secara efektif untuk menjadi #emph[Value Energy] (seperti keuntungan finansial) yang dirasakan langsung oleh penggunanya.

== Environment (Lingkungan)
<environment-lingkungan>
Dalam paradigma #emph[Smart Engineering], luaran akhir dari proses rekayasa adalah #strong[Artefak PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]), di mana dimensi #strong[Environment (Lingkungan)] dikonseptualisasikan secara khusus sebagai #strong[Environmental Space Energy] #strong[\(Energi Ruang Lingkungan)].

#strong[Definisi dan Wujud Energi Ruang Lingkungan] Berbeda dengan sekadar lingkungan fisik tempat sebuah benda berada, Energi Ruang Lingkungan merujuk pada #strong[daya pengaruh dari sebuah ruang atau lingkungan, yang mencakup kualitas visioner, imersif, dan inspirasionalnya, serta jejak ekologis yang ditimbulkannya]. Wujud dari dimensi energi ini bisa berupa hal yang bersifat membangun---seperti desain ruang kerja kolaboratif yang mampu menumbuhkan kreativitas penggunanya---maupun hal yang berupa dampak (#emph[environmental footprint]) seperti jejak emisi karbon yang ditinggalkan oleh sistem operasional.

#strong[Konversi Transaksional dengan Dimensi PSKVE Lainnya] Di dalam sebuah sistem cerdas multi-domain, Energi Lingkungan tidak berdiri sendiri; ia saling memengaruhi dan ditransformasikan bersama dimensi energi lainnya melalui proses "Konversi Transaksional".

- #strong[Interaksi dengan Pengetahuan (Knowledge) dan Produk (Product):] #emph[Environmental Space Energy] sangat erat kaitannya dengan inovasi teknologi yang tertanam pada artefak. Sebagai contoh nyata, Energi Pengetahuan berupa algoritma kecerdasan buatan pada teknologi baterai kendaraan listrik (EV) atau manajemen jaringan cerdas (#emph[smart grid]) akan secara langsung mengendalikan efisiensi konsumsi Energi Produk (kinerja perangkat keras). Peningkatan efisiensi mesin fisik tersebut secara logis akan menekan dampak gas buang CO2 secara drastis, yang berarti kualitas dari Energi Ruang Lingkungan menjadi jauh lebih baik.

#strong[Kuantifikasi dan Metrik Evaluasi dalam Ontologi] Agar keberadaan Lingkungan dapat dihitung dan dioptimalkan oleh mesin penalar cerdas (seperti menggunakan ontologi basis pengetahuan Prolog digabungkan dengan Python), dimensi abstrak ini harus diukur ke dalam properti yang konkret:

- #strong[Emisi Karbon (CO2):] Pada contoh studi kasus simulasi pemilihan transportasi Bandung-Jakarta 2030, kualitas Lingkungan dikuantifikasi secara utama melalui metrik #strong[emisi CO2 ekuivalen per penumpang]. Hasil pemodelan mesin mampu menyajikan perbandingan bahwa opsi moda seperti Kereta Cepat Listrik memberikan performa perlindungan Lingkungan yang lebih superior dengan menghasilkan tingkat emisi per penumpang terendah, dibandingkan pemakaian armada Bus Diesel yang jauh lebih berpolusi.

- #strong[Perluasan Metrik Holistik di Masa Depan:] Agar perancangan artefak PSKVE menjadi lebih presisi di masa mendatang, pengembangan model evaluasi untuk dimensi #emph[Environmental Space Energy] disarankan tidak hanya berhenti di emisi karbon. Kerangka kerja ini mengusulkan metrik yang lebih luas, seperti #strong[penilaian polusi suara (noise pollution), efisiensi tata guna lahan (land use efficiency), dampak visual terhadap ruang, hingga kalkulasi jejak emisi siklus hidup secara utuh---dari tahap awal manufaktur pembuatan artefak hingga fase pembuangannya].

Secara keseluruhan, pemosisian Lingkungan sebagai suatu "Energi" dalam Artefak PSKVE merevolusi pandangan desain rekayasa. Sebuah sistem dikatakan benar-benar cerdas jika mesinnya tidak sekadar mengejar performa teknis (Produk) dan efisiensi waktu (Layanan), tetapi secara sadar mengoptimalkan Pengetahuan komputasionalnya untuk menjaga serta menciptakan kualitas Ruang Lingkungan hidup yang keberlanjutan secara holistik.

= Energi Multi-Dimensi
<energi-multi-dimensi>
Dalam paradigma #emph[Smart Engineering], konsep #strong[Energi Multi-Dimensi] memperluas pandangan tradisional tentang energi---yang biasanya murni bersifat fisik (seperti energi kimia atau kinetik)---menjadi lima dimensi holistik yang disebut #strong[PSKVE (Product, Service, Knowledge, Value, Environment)].

Agar mesin komputasi (kecerdasan buatan) dapat mengevaluasi, memproses, dan menyimulasikan kelima bentuk energi ini, abstraksi energi tersebut harus dipetakan ke dalam struktur data formal menggunakan #strong[Konsep Inti Ontologi]. Integrasi ini memungkinkan teori energi multidimensi direpresentasikan melalui empat bangunan dasar ontologi, yaitu:

- #strong[Properti (Properties) sebagai Pengukur Dimensi Energi:] Di dalam basis pengetahuan ontologis (seperti pada bahasa Prolog), abstraksi dari setiap dimensi energi PSKVE diterjemahkan secara langsung menjadi atribut atau #emph[Properti] matematis yang terukur. Sebagai contoh pemodelan pada transportasi:

- #strong[Product Energy] dikuantifikasi sebagai properti teknis seperti konsumsi daya listrik atau bahan bakar.

- #strong[Service Energy] (yang terkait dengan waktu dan interaksi) diukur melalui properti estimasi waktu tempuh perjalanan.

- #strong[Value Energy] (nilai ekonomis) direpresentasikan sebagai properti total biaya operasional per penumpang atau harga tiket.

- #strong[Environmental Space Energy] dimodelkan melalui properti jejak emisi CO2 ekuivalen.

- #strong[Kelas (Classes) dan Individu (Individuals) sebagai Wadah Energi:] Entitas fisik maupun sistem yang membawa dan mengonversi energi multi-dimensi ini didefinisikan sebagai #strong[Individu] yang bernaung di bawah suatu #strong[Kelas]. Misalnya, di dalam sistem ontologi, "EV\_Sedan" atau "High-Speed Electric Train" dideklarasikan secara eksplisit sebagai individu spesifik dari kelas "Kendaraan". Mesin menggunakan deklarasi ini untuk mengenali spesifikasi kapasitas energi dari masing-masing kendaraan tersebut.

- #strong[Relasi (Relationships) sebagai Model Konversi Transaksional:] Salah satu karakteristik sentral dari Energi Multi-Dimensi adalah kemampuannya untuk saling bertukar dan mentransformasikan wujud antardimensi, sebuah proses yang disebut #strong[Konversi Transaksional]. Di dalam ontologi, pertukaran energi lintas dimensi ini dimodelkan menggunakan #strong[Relasi] dan aturan logika (#emph[rules]).Ontologi memfasilitasi mesin untuk menalar logika interaksi kompleks ini. Sebagai contoh, sistem dapat menyimulasikan relasi logika di mana peningkatan #strong[Knowledge Energy] (seperti perbaikan algoritma pintar pada manajemen baterai) akan memengaruhi efisiensi #strong[Product Energy] (perangkat keras mesin), yang mana relasi tersebut secara otomatis akan menghasilkan dampak turunan pada penurunan emisi gas buang (#strong[Environmental Energy]).

Pemanfaatan konsep inti ontologi di sini bertindak sebagai fondasi operasional yang vital. Tanpa ontologi, Energi Multi-Dimensi hanya akan menjadi konsep teoretis. Namun dengan ontologi, kelima dimensi energi ini berhasil diubah menjadi parameter komputasional terstruktur yang memungkinkan perangkat lunak untuk menalar efisiensi, mengevaluasi #emph[trade-off] (tarik-ulur) antar-energi, dan merancang solusi teknik interdisipliner secara otomatis.

== Energi Produk (Fisik)
<energi-produk-fisik>
Dalam kerangka #emph[Smart Engineering], konsep Energi Multi-Dimensi memperluas pandangan tradisional---yang sebelumnya hanya melihat energi murni dari kacamata fisik---menjadi lima dimensi holistik yang disebut PSKVE (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam model ini, #strong[Energi Produk (Product Energy) didefinisikan sebagai wujud energi alamiah atau fisik, baik yang masih bawaan maupun yang telah dikonversi, yang melekat di dalam sebuah produk]. Contoh nyata dari keberadaan Energi Produk adalah energi kimia yang tersimpan di dalam sel baterai atau energi kinetik yang menggerakkan suatu mesin.

Sebagai bagian dari ekosistem Energi Multi-Dimensi, #strong[Energi Produk tidak beroperasi secara terisolasi, melainkan secara konstan saling bertukar dan bertransformasi dengan dimensi energi lainnya melalui mekanisme yang disebut "Konversi Transaksional"]. Keterkaitan ini terlihat jelas melalui interaksi berikut:

- #strong[Integrasi dengan Pengetahuan (Knowledge) dan Lingkungan (Environment):] Energi Pengetahuan (#emph[Knowledge Energy]), seperti algoritma cerdas pada manajemen baterai kendaraan listrik (EV) atau jaringan cerdas (#emph[smart grid]), secara langsung mengendalikan dan mengoptimalkan efisiensi konsumsi Energi Produk pada perangkat keras. Seberapa efisien Energi Produk ini dikelola oleh kecerdasan mesin akan berimbas langsung pada kualitas Energi Ruang Lingkungan, seperti seberapa besar jejak emisi karbon yang dihasilkan.

- #strong[Pertukaran dengan Nilai (Value) dan Layanan (Service):] Dari kacamata ekonomi dan pengguna, sebuah konversi transaksional terjadi ketika konsumen menukarkan uang finansial mereka (Energi Nilai) untuk memperoleh perangkat pintar yang di dalamnya memuat wujud fisik alat tersebut (Energi Produk) beserta algoritma cerdasnya (Energi Pengetahuan). Pada contoh transportasi, penumpang membayar tiket (Energi Nilai) demi mendapatkan akses terhadap operasional kendaraan fisik tersebut (Energi Produk) untuk menghasilkan efisiensi waktu perjalanan (Energi Layanan).

Dalam pemecahan masalah rekayasa (seperti metafora sistem transportasi lintas domain), pengelolaan Energi Produk menjadi fokus operasional utama pada tingkatan teknis:

- #strong[Pada Domain Sistem:] Entitas utama seperti kendaraan dipandang sebagai sistem cerdas yang bertugas menavigasi lingkungan sekaligus secara aktif mengelola ketersediaan Energi Produk (seperti konsumsi bahan bakar atau daya listrik) miliknya.

- #strong[Pada Domain Teknologi:] Komponen inti seperti mesin cerdas (#emph[Smart Engine]) memanfaatkan siklus PUDAL untuk mengoptimalkan konversi teknologi, yakni berfokus pada cara mengubah Energi Produk menjadi energi kerja (mekanis) yang efisien bagi kendaraan tersebut.

Singkatnya, meskipun Energi Produk merupakan representasi daya fisik yang menjadi motor penggerak material dari suatu artefak, kerangka energi multidimensional memosisikannya sebagai komponen yang harus dikendalikan oleh "pengetahuan" algoritmik demi mencapai efisiensi tertinggi, sekaligus menghasilkan "layanan" dan "nilai" yang optimal bagi pengguna serta "lingkungan".

== Energi Layanan (Atensi)
<energi-layanan-atensi>
Dalam kerangka #emph[Smart Engineering], konsep #strong[Energi Multi-Dimensi] memperluas pandangan tradisional tentang energi (yang biasanya hanya merujuk pada energi fisik) menjadi lima dimensi holistik yang disebut #strong[PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam model ini, #strong[Energi Layanan (Service Energy)] dikonseptualisasikan secara khusus sebagai bentuk energi yang berkaitan erat dengan #strong[waktu, interaksi, dan atensi (perhatian) manusia].

#strong[Definisi dan Wujud Energi Layanan] Energi Layanan didefinisikan sebagai energi yang dikeluarkan atau ditangkap melalui proses penyediaan maupun konsumsi sebuah layanan. Wujud nyata dari dimensi energi ini tidak berupa daya mekanis, melainkan keterlibatan dari sisi manusia. Sebagai contoh, durasi waktu dan tingkat perhatian (#emph[user engagement]) yang diinvestasikan oleh seseorang saat berinteraksi dengan sebuah platform digital merupakan wujud langsung dari Energi Layanan.

#strong[Konversi Transaksional dengan Dimensi Energi Lainnya] Sebagai bagian dari Energi Multi-Dimensi, Energi Layanan bersifat dinamis dan terus-menerus bertukar wujud dengan dimensi energi lainnya melalui proses yang disebut "Konversi Transaksional". Interaksi ini terlihat jelas dalam skenario berikut:

- #strong[Pertukaran dengan Nilai (Value) dan Produk (Product):] Dalam simulasi sistem transportasi publik, sebuah konversi transaksional terjadi ketika penumpang menukarkan uang finansial mereka (Energi Nilai) untuk memperoleh jasa perpindahan lokasi (Energi Layanan), yang mana layanan tersebut difasilitasi oleh operasional mesin kendaraan fisik (Energi Produk).

- #strong[Pertukaran dengan Pengetahuan (Knowledge) dan Nilai (Value):] Pada sistem interaktif, seorang pengguna mengorbankan waktu dan perhatian interaktif mereka (Energi Layanan) untuk dapat mengekstraksi informasi dari suatu sistem (Energi Pengetahuan) atau sekadar untuk mendapatkan hiburan dan manfaat lainnya (Energi Nilai).

#strong[Kuantifikasi dan Evaluasi dalam Ontologi Sistem Cerdas] Agar sistem penalaran mesin (seperti platform ontologi gabungan Prolog dan Python) dapat membandingkan dan mengoptimalkan kualitas dari sebuah layanan, abstraksi Energi Layanan ini harus diterjemahkan ke dalam bentuk properti atau metrik yang terukur:

- #strong[Efisiensi Waktu (Estimasi Waktu Tempuh):] Pada studi kasus simulasi pemilihan alternatif transportasi rute Bandung-Jakarta 2030, kualitas Energi Layanan dievaluasi secara utama melalui #strong[estimasi waktu tempuh perjalanan]. Hasil simulasi menunjukkan bahwa moda Kereta Cepat Listrik (#emph[High-Speed Train]) memberikan performa Energi Layanan yang paling superior karena menawarkan waktu perjalanan yang paling singkat bagi penumpangnya.

- #strong[Perluasan Metrik Pengukuran di Masa Depan:] Untuk perancangan artefak cerdas yang lebih komprehensif ke depannya, kerangka kerja ini menyarankan agar pengukuran Energi Layanan diperluas. Metrik yang diusulkan untuk mengkuantifikasi dimensi ini meliputi #strong[pengukuran tingkat keandalan sistem (MTBF -] #strong[Mean Time Between Failures), indeks kenyamanan pengguna, hingga seberapa mudah layanan tersebut dapat diakses (accessibility) oleh beragam kelompok demografi].

Singkatnya, penyertaan Energi Layanan di dalam konsep Energi Multi-Dimensi menegaskan bahwa dalam paradigma rekayasa modern, waktu dan perhatian manusia diperlakukan sebagai wujud "energi" yang berharga. Sistem mesin yang cerdas tidak lagi hanya dirancang untuk menghemat bahan bakar fisik (Produk), tetapi juga untuk memastikan bahwa interaksi layanannya terhadap pengguna dapat berjalan seefisien dan senyaman mungkin.

== Energi Pengetahuan (Algoritma)
<energi-pengetahuan-algoritma>
Dalam kerangka #emph[Smart Engineering], konsep #strong[Energi Multi-Dimensi] memperluas definisi energi dari yang sebelumnya sekadar entitas fisik mekanis menjadi lima dimensi holistik yang disebut #strong[PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam model komprehensif ini, #strong[Energi Pengetahuan (Knowledge Energy) secara spesifik didefinisikan sebagai energi intelektual atau informasional yang terwujud dalam bentuk skema, keahlian kepakaran, hingga algoritma dan logika di dalam sebuah model Kecerdasan Buatan (AI)].

Sebagai bagian integral dari ekosistem Energi Multi-Dimensi, Energi Pengetahuan tidak beroperasi secara terisolasi. Alih-alih, ia berfungsi sebagai motor penggerak "kecerdasan" di dalam sistem yang terus-menerus bertukar wujud dan memengaruhi dimensi energi lainnya melalui mekanisme #strong[Konversi Transaksional]. Interaksi multidimensional algoritma ini terlihat pada proses berikut:

- #strong[Mengendalikan Energi Produk dan Memperbaiki Energi Lingkungan:] Pada tingkat Teknologi, sebuah mesin cerdas (#emph[Smart Engine]) memanfaatkan siklus PUDAL dengan mengintegrasikan Energi Pengetahuan (algoritma) untuk mengoptimalkan konversi Energi Produk (sumber daya fisik seperti bahan bakar) menjadi energi kerja yang efisien. Sebagai contoh, keberadaan #emph[Knowledge Energy] yang tertanam dalam algoritma teknologi baterai kendaraan listrik (EV) atau pada sistem manajemen #emph[smart grid] (jaringan cerdas) akan secara langsung memengaruhi efisiensi #emph[Product Energy]. Peningkatan efisiensi operasional sistem keras fisik ini secara otomatis akan memberikan dampak turunan yang positif terhadap #emph[Environmental Space Energy], seperti penurunan drastis pada tingkat emisi karbon (CO2).

- #strong[Bertransaksi dengan Energi Nilai dan Layanan:] Dari sudut pandang pengguna dan ekonomi, sebuah konversi transaksional terjadi ketika konsumen menukarkan biaya finansial atau uang (#emph[Value Energy]) demi mendapatkan sebuah perangkat cerdas yang di dalamnya memuat wujud keras fisik (#emph[Product Energy]) beserta Energi Pengetahuan (algoritma cerdas). Selain itu, pengguna sering kali harus mengorbankan waktu dan tingkat perhatian mereka (#emph[Service Energy]) untuk dapat berinteraksi dan mengekstraksi informasi berharga dari sistem cerdas tersebut (#emph[Knowledge Energy] atau #emph[Value Energy]).

#strong[Kuantifikasi dalam Pemodelan (Ontologi Sistem Cerdas)] Agar keberadaan Energi Pengetahuan ini dapat dievaluasi, disimulasikan, dan dioptimalkan oleh mesin penalaran komputasi (seperti pada implementasi platform hibrida Prolog-Python), dimensi abstrak dari sebuah algoritma harus diterjemahkan menjadi metrik properti yang dapat dikuantifikasi. Pengembangan model #emph[Smart Engineering] mengusulkan agar Energi Pengetahuan diukur menggunakan parameter seperti:

- #strong[Tingkat Kesiapan Teknologi (TRL -] #strong[Technology Readiness Level)].

- #strong[Tingkat kompleksitas dari algoritma yang mendasari sistem tersebut].

- #strong[Kebutuhan data (data requirements) yang diwajibkan agar komponen kecerdasan buatan (AI) dapat berfungsi secara maksimal].

Singkatnya, di dalam konsep Energi Multi-Dimensi, algoritma diposisikan bukan sekadar sebagai barisan kode pelengkap, melainkan diperlakukan sebagai #strong[energi intelektual utama] yang mampu mengorkestrasi interaksi fungsional ke seluruh domain. #emph[Knowledge Energy] inilah yang memastikan bahwa energi fisik beroperasi pada tingkat efisiensi maksimal untuk memberikan layanan terbaik, nilai ekonomis yang tinggi, sembari menjaga keseimbangan dan keberlanjutan energi lingkungan sekitarnya.

== Energi Nilai (Finansial/Sosial)
<energi-nilai-finansialsosial>
Dalam paradigma #emph[Smart Engineering], energi tidak lagi hanya dipandang sebagai entitas fisik, melainkan diperluas menjadi #strong[Energi Multi-Dimensi] yang mencakup lima elemen PSKVE (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam model holistik ini, #strong[Energi Nilai (Value Energy) secara khusus didefinisikan sebagai potensi atau kelayakan nyata (realized worth) dari sebuah artefak atau sistem].

#strong[Definisi dan Wujud Energi Nilai] Karakteristik utama dari Energi Nilai adalah wujudnya yang sangat luas. Dimensi ini #strong[tidak hanya sebatas pada ukuran finansial atau metrik uang, tetapi juga mencakup nilai sosial, budaya, hingga reputasi]. Contoh nyata dari perwujudan Energi Nilai ini adalah tingkat kapitalisasi pasar yang dimiliki oleh suatu perusahaan atau besarnya pengaruh sosial (#emph[social influence]) yang dihasilkan oleh sebuah inovasi.

#strong[Konversi Transaksional dengan Dimensi Energi Lainnya] Sebagai bagian dari ekosistem Energi Multi-Dimensi, Energi Nilai bersifat sangat dinamis dan berinteraksi secara terus-menerus dengan dimensi lainnya melalui proses #strong[Konversi Transaksional]. Interaksi ini dapat diamati dalam berbagai aktivitas kehidupan:

- #strong[Pertukaran Finansial dan Teknologi:] Seorang konsumen melakukan konversi energi ketika ia menukarkan uang finansial yang dimilikinya (Energi Nilai) untuk membeli sebuah perangkat pintar (Energi Produk) yang di dalamnya telah tertanam algoritma kecerdasan (Energi Pengetahuan).

- #strong[Pertukaran Waktu dan Manfaat:] Seorang pengguna mungkin menginvestasikan waktu dan perhatiannya (Energi Layanan) saat berinteraksi dengan sebuah sistem digital untuk mendapatkan hiburan atau manfaat lain yang bernilai baginya (Energi Nilai/Pengetahuan).

Dalam konteks fundamental riset ke depan, tantangan utamanya adalah bagaimana mengoptimalkan konversi transaksional ini, misalnya meneliti seberapa efektif inovasi perangkat lunak (Energi Pengetahuan) dapat dikonversi menjadi keuntungan yang nyata (Energi Nilai).

#strong[Kuantifikasi Energi Nilai dalam Simulasi Sistem Cerdas] Agar Energi Nilai ini dapat diproses, dievaluasi, dan disimulasikan oleh mesin (seperti implementasi ontologi berbasis bahasa Prolog dan Python), nilai abstrak ini harus diterjemahkan menjadi metrik properti yang konkret.

Dalam studi kasus simulasi pemilihan alternatif transportasi rute Bandung-Jakarta 2030, kualitas #strong[Energi Nilai dikuantifikasi secara langsung melalui metrik Total Biaya per Penumpang].

- Untuk moda seperti armada bus diesel atau mobil listrik (EV) pribadi, perhitungan Energi Nilai ini mencakup akumulasi biaya bahan bakar/listrik, tarif jalan tol, hingga perhitungan pembagian pro-rata dari biaya perawatan tahunan kendaraan.- Sementara itu, untuk moda transportasi seperti Kereta Cepat, harga tiket penumpang digunakan sebagai parameter pengukur Energi Nilai.

#strong[Perluasan Metrik Evaluasi Ekonomi dan Sosial di Masa Depan] Meski simulasi tahap awal menggunakan metrik biaya langsung, sumber-sumber tersebut menekankan bahwa pengukuran biaya operasional semata tidak cukup untuk merepresentasikan keseluruhan "Nilai" dari suatu artefak. Agar analisis menjadi lebih komprehensif, pengembangan model pengukuran Energi Nilai di masa depan disarankan untuk mencakup metrik yang lebih holistik, seperti:

- #strong[Biaya Siklus Hidup yang utuh (Full Lifecycle Costing] #strong[\/ LCC),] yang turut memperhitungkan biaya modal awal untuk pembuatan kendaraan dan infrastrukturnya.

- #strong[Analisis biaya-manfaat kemasyarakatan (societal cost-benefit analysis)].

- #strong[Penilaian potensi penciptaan lapangan kerja dan sejauh mana artefak tersebut memberikan dampak bagi perkembangan ekonomi lokal].

Singkatnya, pemosisian Nilai sebagai sebuah dimensi energi dalam #emph[Smart Engineering] menuntut para insinyur untuk tidak sekadar menciptakan produk yang berfungsi secara fisik, melainkan juga harus memastikan bahwa produk tersebut dirancang agar mampu menghasilkan kelayakan ekonomi, sosial, dan budaya tertinggi bagi masyarakat.

== Energi Ruang Lingkungan (Inspirasi)
<energi-ruang-lingkungan-inspirasi>
Dalam paradigma #emph[Smart Engineering], konsep #strong[Energi Multi-Dimensi] memperluas definisi energi dari sekadar wujud fisik mekanis menjadi lima dimensi holistik yang dikenal sebagai #strong[PSKVE] (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam kerangka komprehensif ini, #strong[Energi Ruang Lingkungan (Environmental Space Energy) secara spesifik didefinisikan sebagai daya pengaruh dari sebuah ruang atau lingkungan, yang mencakup kualitas visioner, imersif, dan inspirasionalnya].

#strong[Wujud Energi Ruang Lingkungan (Inspirasi dan Dampak)] Berbeda dengan pandangan tradisional yang sekadar melihat lingkungan sebagai lokasi fisik statis, dimensi ini memandang bahwa ruang memiliki "energi" yang secara aktif memengaruhi entitas di dalamnya. Wujud nyata dari dimensi ini bisa bersifat sangat membangun (inspirasional), seperti #strong[desain dari sebuah ruang kerja kolaboratif yang terbukti mampu menumbuhkan kreativitas para penggunanya]. Di sisi lain, energi ini juga merepresentasikan dampak ekologis (#emph[environmental footprint]) yang ditinggalkan oleh operasional suatu sistem, seperti jejak emisi karbon.

#strong[Konversi Transaksional dengan Dimensi Energi Lainnya] Sebagai komponen integral dari ekosistem Energi Multi-Dimensi, Energi Ruang Lingkungan bersifat dinamis dan terus-menerus bertukar wujud dengan dimensi energi lainnya melalui proses yang disebut #strong[Konversi Transaksional].

- #strong[Interaksi Erat dengan Pengetahuan (Knowledge) dan Produk (Product):] Kualitas dari Energi Ruang Lingkungan sangat dipengaruhi oleh tingkat kecerdasan buatan yang tertanam dalam suatu artefak. Sebagai contoh, Energi Pengetahuan yang terwujud dalam algoritma teknologi baterai kendaraan listrik (EV) atau sistem manajemen #emph[smart grid] akan secara langsung mengendalikan dan mengoptimalkan Energi Produk (kinerja perangkat keras fisik). Optimalisasi efisiensi pada mesin fisik ini secara logis akan memberikan hasil turunan berupa perbaikan kualitas Energi Ruang Lingkungan, yakni dengan menekan dampak emisi gas buang secara signifikan.

#strong[Kuantifikasi dan Metrik Evaluasi dalam Ontologi] Agar "energi ruang" yang abstrak ini dapat dievaluasi, disimulasikan, dan dioptimalkan oleh sistem penalaran mesin (seperti pada platform hibrida Prolog dan Python), ia harus diurai menjadi properti atau metrik yang dapat dihitung:

- #strong[Pengukuran Jejak Emisi (CO2):] Dalam studi simulasi pemilihan alternatif transportasi rute Bandung-Jakarta 2030, kualitas Energi Ruang Lingkungan secara praktis dikuantifikasi melalui metrik #strong[emisi CO2 ekuivalen per penumpang], yang menakar langsung rekam jejak lingkungan dari operasional kendaraan.

- #strong[Perluasan Metrik Holistik di Masa Depan:] Agar perancangan sistem rekayasa menjadi lebih presisi dalam menilai kualitas lingkungan dan ruang inspirasionalnya, pengembangan kerangka kerja di masa depan mengusulkan metrik pengukuran yang jauh lebih luas. Metrik tersebut mencakup #strong[penilaian polusi suara (noise pollution), efisiensi tata guna lahan, dampak visual dari suatu ruang, hingga kalkulasi jejak emisi siklus hidup secara utuh---sejak tahap manufaktur artefak hingga fase pembuangannya].

Singkatnya, pemosisian Ruang Lingkungan sebagai salah satu pilar Energi dalam model PSKVE menegaskan bahwa perancangan sebuah sistem rekayasa tidak boleh hanya berfokus pada kekuatan mekanis murni (Produk). Sebaliknya, sistem harus dirancang secara cerdas agar mampu melestarikan ekologi sekaligus menciptakan lingkungan yang kaya akan nilai inspirasional dan visioner bagi manusia di dalamnya.

== Konversi Transaksional
<konversi-transaksional>
Dalam kerangka #emph[Smart Engineering], konsep Energi Multi-Dimensi memperluas definisi energi dari sekadar bentuk fisik menjadi lima dimensi holistik yang disebut PSKVE (#emph[Product, Service, Knowledge, Value, Environment]). Di dalam ekosistem energi yang komprehensif ini, #strong[Konversi Transaksional (Transactional Conversion) didefinisikan sebagai proses di mana satu bentuk energi PSKVE dipertukarkan atau ditransformasikan menjadi bentuk energi lain lintas dimensi].

Konsep konversi transaksional ini muncul sebagai konsekuensi dari perluasan paradigma rekayasa, dari yang sebelumnya hanya berfokus pada mesin (#emph[machine-only paradigm]) menjadi paradigma gabungan antara manusia dan mesin (#emph[human-machine paradigm]). Berbeda dengan konversi energi tradisional yang biasanya berfokus pada perubahan wujud di dalam satu dimensi fisik yang sama, #strong[konversi transaksional secara khusus mengkaji pertukaran (transactions) energi antar-dimensi yang berbeda].

Beberapa wujud nyata dari mekanisme #strong[Konversi Transaksional] ini meliputi:

- #strong[Pertukaran Nilai dengan Produk dan Pengetahuan:] Seorang konsumen melakukan konversi transaksional saat menukarkan energi finansial (#emph[Value Energy]) untuk membeli sebuah perangkat pintar yang memuat komponen keras fisik (#emph[Product Energy]) beserta teknologi atau algoritma yang tertanam di dalamnya (#emph[Knowledge Energy]).

- #strong[Pertukaran Layanan dengan Pengetahuan dan Nilai:] Seorang pengguna menginvestasikan waktu dan perhatiannya (#emph[Service Energy]) saat berinteraksi dengan sebuah platform digital guna memperoleh informasi (#emph[Knowledge Energy]) atau hiburan (#emph[Value Energy]).

- #strong[Pertukaran Transportasi:] Pada simulasi sistem transportasi, penumpang secara aktif melakukan konversi dengan membayarkan uang (#emph[Value Energy]) demi mendapatkan layanan perpindahan lokasi yang efisien secara waktu (#emph[Service Energy]) serta akses terhadap operasional kendaraan fisik tersebut (#emph[Product Energy]).

Dalam perancangan sistem rekayasa modern, pemahaman dan optimalisasi konversi transaksional ini menjadi salah satu fokus utama dalam penelitian fundamental #emph[Smart Engineering]. Entitas cerdas di dalam sistem ini dimodelkan menggunakan #strong[Smart Engine Abstraction (SEA)], yang secara konseptual dirancang untuk mentransformasikan berbagai input (baik berupa gaya maupun nilai) menjadi output yang berharga melalui mekanisme konversi transformasional maupun transaksional.

Tantangan utama riset di masa depan adalah #strong[mengembangkan model matematika atau model formal untuk mengkuantifikasi dan mengoptimalkan tingkat konversi transaksional antar-dimensi PSKVE ini]. Sebagai contoh, para peneliti perlu merumuskan cara untuk menghitung seberapa besar dan efektif "energi pengetahuan" (seperti inovasi dari sebuah perangkat lunak baru) dapat dikonversi secara nyata menjadi "energi nilai" (seperti keuntungan finansial bagi perusahaan atau nilai manfaat bagi penggunanya).

= Smart Engine Abstraction (SEA)
<smart-engine-abstraction-sea>
Dalam kerangka #emph[Smart Engineering], #strong[Smart Engine Abstraction (SEA)] adalah model konseptual inti yang digunakan untuk merancang dan menganalisis sistem yang mentransformasikan energi dan memiliki kecerdasan. Model SEA mengabstraksikan sebuah mesin sebagai entitas otonom dan dapat dikendalikan, yang secara spesifik berfungsi mengubah input (baik berupa gaya mekanis maupun nilai abstrak) menjadi output yang berharga. SEA dapat diterapkan lintas domain (baik perangkat keras, perangkat lunak, maupun perangkat spasial) dan tersusun atas komponen-komponen seperti #emph[Source/Intake, Encoder, Internal Power, Decoder, Solution Value, Control], dan #emph[Flywheel].

Agar desain SEA yang kompleks ini dapat dinalar, disimulasikan, dan dievaluasi oleh mesin komputasi (seperti pada simulasi berbasis Prolog), SEA harus dipetakan ke dalam struktur data formal menggunakan #strong[Konsep Inti Ontologi]. Integrasi ini dilakukan dengan cara berikut:

- #strong[Kelas (Classes) dan Individu (Individuals) sebagai Representasi Entitas SEA:] Di dalam basis pengetahuan ontologis (misalnya menggunakan bahasa Prolog), komponen-komponen sistem utama yang beroperasi sebagai SEA---seperti sistem kemudi otonom pada kendaraan, pusat manajemen lalu lintas, atau sistem manajemen jaringan energi---dideklarasikan secara eksplisit sebagai #strong[Individu] (entitas spesifik) yang bernaung di bawah suatu #strong[Kelas]. Representasi ini memastikan setiap mesin cerdas diakui eksistensinya secara logis oleh program.

- #strong[Properti (Properties) untuk Memodelkan Siklus PUDAL dan Transformasi PSKVE:] Kemampuan internal dari setiap SEA diterjemahkan menjadi #strong[Properti] atau atribut logis. Dalam ontologi, properti ini digunakan untuk merinci bagaimana sebuah SEA menjalankan siklus cerdasnya (PUDAL) dan bagaimana ia melakukan transformasi internal terhadap energi multi-dimensi PSKVE (seperti mengonversi #emph[Knowledge Energy] algoritmik menjadi efisiensi #emph[Product Energy]). Komponen-komponen penyusun SEA (seperti #emph[Encoder] atau #emph[Flywheel]) juga dapat dimodelkan sebagai atribut turunan dari individu tersebut.

- #strong[Relasi (Relationships) untuk Menyimulasikan Interaksi antar-SEA:] Sebuah sistem yang kompleks sering kali terdiri dari banyak SEA yang saling terkait (disebut sebagai #emph[system-of-systems]). Ontologi menggunakan #strong[Relasi] (berupa aturan-aturan atau #emph[rules] logika) untuk memodelkan interaksi dinamis dan aliran energi atau nilai di antara berbagai SEA yang terhubung. Pemodelan relasi ini memungkinkan sistem komputasi untuk memahami perilaku #emph[emergent] (kemunculan sifat baru) yang terjadi saat berbagai mesin cerdas bertransaksi dan saling memengaruhi satu sama lain.

Secara keseluruhan, dengan memetakan Smart Engine Abstraction (SEA) ke dalam konsep inti ontologi, para insinyur tidak hanya mendapatkan bahasa atau pola desain bersama yang mempermudah kolaborasi lintas disiplin ., tetapi mereka juga berhasil mengubah konsep arsitektur mesin cerdas ini menjadi bentuk struktur data yang bisa dinalar dan dioptimalkan secara otomatis oleh mesin komputasi (kecerdasan buatan).

#heading(level: 1, numbering: none)[Bagian 2: Metodologi Multi-Domain (PICOC)]
<bagian-2-metodologi-multi-domain-picoc>
Dalam kerangka #emph[Smart Engineering], penyelesaian masalah teknik modern yang sangat kompleks dan lintas disiplin didekonstruksi ke dalam empat domain utama, yakni domain Aplikasi, Sistem, Teknologi, dan Riset Fundamental. Untuk meneliti, mengevaluasi, dan melaporkan solusi pada keempat lapisan domain ini secara sistematis, kerangka kerja ini memanfaatkan #strong[Metodologi PICOC].

Secara mendasar, metodologi PICOC berfungsi sebagai struktur pelaporan yang mengevaluasi sebuah perlakuan (solusi) baru terhadap solusi lama untuk mengukur peningkatan yang dihasilkan dalam memahami atau memecahkan suatu masalah. Komponen metodologi ini terdiri dari:

- #strong[P (Population):] Kelompok target, entitas, atau kumpulan data yang diteliti.

- #strong[I (Intervention):] Perlakuan inovatif berupa solusi, sistem, teknologi, atau proses baru yang diusulkan.

- #strong[C (Control):] Solusi, sistem, atau teknologi lama yang sudah ada dan digunakan sebagai garis dasar (#emph[baseline]) pembanding.

- #strong[O (Outcome):] Efek yang dapat diukur, seperti peningkatan performa, nilai-nilai baru yang dihasilkan, atau temuan pengetahuan baru.

- #strong[Cx (Context):] Masalah spesifik, batasan kebutuhan, atau kesenjangan pengetahuan yang menjadi latar belakang perancangan.

Keunikan metodologi lintas-domain ini dalam ekosistem #emph[Smart Engineering] adalah #strong[penerapan struktur PICOC yang diiterasi secara spesifik pada keempat lapisan (domain) rekayasa]:

- #strong[Pada Domain Aplikasi (PICOC-A):] Fokus evaluasi berada pada penyelesaian masalah pemangku kepentingan (#emph[stakeholders]). Sistem membandingkan solusi baru yang ditawarkan dengan praktik yang digunakan masyarakat saat ini, lalu mengukur hasil akhirnya dalam bentuk peningkatan efisiensi, pengurangan biaya, kepuasan pengguna, atau manfaat nyata (#emph[Value Energy]).

- #strong[Pada Domain Sistem (PICOC-S):] Berfokus pada pengujian rancangan sistem terintegrasi (contohnya perancangan kendaraan cerdas secara utuh) yang akan mewujudkan solusi pada lapisan aplikasi. Di sini, sistem baru dievaluasi performanya (seperti akurasi, kecepatan, pemanfaatan sumber daya, atau keandalan) melawan arsitektur sistem yang sudah ada sebelumnya.

- #strong[Pada Domain Teknologi (PICOC-T):] Berfokus pada evaluasi mesin penggerak (#emph[Smart Engine]) atau modul teknologi inti di dalam sistem. Metodologi ini mengukur seberapa efisien teknologi baru tersebut dalam melakukan tugas konversi spesifik (seperti konversi #emph[Product Energy] menjadi #emph[Service Energy]) jika dibandingkan dengan metode atau instrumen lama.

- #strong[Pada Domain Riset Fundamental (PICOC-F):] Berada di lapisan terdalam untuk memvalidasi prinsip-prinsip saintifik, entitas ontologis, atau teori konversi energi PSKVE yang menjadi landasan inovasi. Metodologi membandingkan kerangka teori baru dengan model lama untuk mengukur penemuan prinsip pengetahuan baru (#emph[Knowledge Energy]) yang tervalidasi secara logika.

Penerapan struktural metodologi PICOC lintas domain ini sangat krusial karena #strong[memastikan adanya koherensi logis antar-lapisan desain]. Dengan pendekatan ini, para insinyur dapat dengan jelas mendemonstrasikan bagaimana keberhasilan penemuan teori di lapisan Fundamental akan menyokong efisiensi konversi pada lapisan Teknologi, yang kemudian menghidupkan kecerdasan operasional di lapisan Sistem, dan bermuara pada penyelesaian masalah yang berdampak langsung bagi manusia di lapisan Aplikasi.

= Domain Aplikasi (A)
<domain-aplikasi-a>
Dalam kerangka desain #emph[Smart Engineering], metodologi PICOC (#emph[Population, Intervention, Control, Outcome, Context]) diterapkan secara berlapis pada empat domain hierarkis---yakni Aplikasi, Sistem, Teknologi, dan Riset Fundamental---untuk mengevaluasi dan menyusun laporan inovasi secara terstruktur.

Pada lapisan teratas, yaitu #strong[Domain Aplikasi (A)], metodologi ini berfokus secara eksklusif pada upaya #strong[menemukan solusi yang lebih baik untuk memecahkan masalah nyata yang dihadapi oleh para pemangku kepentingan (stakeholders)].

Penerapan kelima komponen PICOC pada Domain Aplikasi (PICOC-A) dijabarkan sebagai berikut:

- #strong[P(A) - Populasi (Population):] Menargetkan subjek atau kelompok yang diteliti, yang dalam domain ini berupa #strong[para pemangku kepentingan, seperti pengguna akhir, organisasi, atau masyarakat luas].

- #strong[I(A) - Intervensi (Intervention):] Merepresentasikan #strong[solusi baru yang diusulkan] kepada masyarakat. Solusi pada tingkat aplikasi ini merupakan manifestasi langsung dari sistem cerdas yang telah dirancang pada Domain Sistem (S).

- #strong[C(A) - Kontrol (Control):] Merupakan #strong[solusi lama, sistem eksisting, atau praktik yang saat ini digunakan] oleh populasi. Analisis pada bagian ini mencakup evaluasi terhadap batasan, kelemahan, dan alasan mengapa solusi lama tersebut sudah tidak lagi memadai.

- #strong[O(A) - Hasil (Outcome):] Mengukur secara langsung #strong[peningkatan performa atau manfaat yang dirasakan oleh para pemangku kepentingan]. Metrik pengukurannya sangat berkaitan dengan dimensi #emph[Value Energy], seperti tingkat efisiensi, pengurangan biaya finansial, kemudahan penggunaan (#emph[usability]), hingga kepuasan pengguna.

- #strong[Cx(A) - Konteks (Context):] Mendefinisikan #strong[masalah spesifik yang melatarbelakangi perancangan], beserta spesifikasi kebutuhan (#emph[requirements]) yang harus dipenuhi agar solusi tersebut dapat dikatakan berhasil memecahkan masalah pemangku kepentingan.

Dalam metodologi multi-domain ini, keberhasilan di Domain Aplikasi (A) merupakan pembuktian tertinggi dari seluruh siklus inovasi rekayasa. Peningkatan performa yang diklaim di tingkat Aplikasi (O(A)) tidak berdiri sendiri, melainkan #strong[harus didukung dan dibuktikan oleh keberhasilan arsitektur operasional pada tingkat Sistem (O(S)), yang pada gilirannya disokong oleh efisiensi mesin di tingkat Teknologi (O(T)) dan divalidasi oleh teori di tingkat Riset Fundamental (O(F))]. Struktur pelaporan berjenjang ini memastikan bahwa rancangan teknis yang rumit sekalipun akan selalu berorientasi pada penyelesaian masalah manusia di dunia nyata.

== P: Stakeholder
<p-stakeholder>
Dalam metodologi pelaporan PICOC yang diterapkan pada Domain Aplikasi (PICOC-A), komponen #strong[P (Populasi) secara spesifik direpresentasikan sebagai Stakeholder atau Pemangku Kepentingan].

Dalam kerangka #emph[Smart Engineering], Domain Aplikasi berfokus pada upaya memecahkan masalah nyata, sehingga populasi yang diteliti bukanlah data atau mesin, melainkan subjek manusia atau entitas yang mengalami masalah tersebut.

Berikut adalah peran dan posisi #strong[P: Stakeholder] dalam konteks Domain Aplikasi (A):

- #strong[Definisi dan Wujud Stakeholder (P(A)):] Stakeholder dapat berupa #strong[pengguna akhir (users), organisasi, institusi, masyarakat luas, hingga para insinyur itu sendiri]. Sebagai contoh kasus ekstrem, Perserikatan Bangsa-Bangsa (PBB) dapat bertindak sebagai stakeholder (P) dalam proyek pengiriman pesan ke galaksi lain. Dalam proyek rekayasa perangkat lunak, para insinyur yang membutuhkan alat desain otomatis juga merupakan wujud dari stakeholder. Jika pengujian aplikasi melibatkan manusia secara langsung, definisi P(A) ini harus mencakup rincian seperti kriteria seleksi, ukuran sampel, dan demografi partisipan.

- #strong[Sebagai Penentu Titik Awal Masalah (Konteks):] Analisis di Domain Aplikasi selalu dimulai dengan mengidentifikasi masalah spesifik (Cx(A)) yang tengah dihadapi oleh para stakeholder ini. Analisis harus mendefinisikan dengan jelas apa kesenjangan (#emph[gap]) antara kebutuhan atau keinginan stakeholder dengan solusi yang tersedia bagi mereka saat ini.

- #strong[Target Evaluasi Dampak (Outcome):] Motivasi utama dari penciptaan solusi baru (Intervensi) selalu dinilai berdasarkan seberapa penting penyelesaian masalah tersebut bagi kelompok stakeholder (P(A)). Oleh karena itu, keberhasilan suatu sistem diukur dari #strong[seberapa besar peningkatan performa (O(A))---seperti pengurangan biaya, efisiensi waktu, atau kepuasan---yang dirasakan dan berdampak langsung pada para stakeholder tersebut]. Sebagai contoh, inovasi platform cerdas dinilai berhasil di tingkat aplikasi jika ia memberikan implikasi nyata berupa alat bantu yang lebih otomatis dan cerdas bagi insinyur sebagai stakeholder-nya.

Secara keseluruhan, pemosisian #strong[Stakeholder sebagai Populasi] memastikan bahwa seluruh inovasi teknologi (T) dan sistem (S) yang dikembangkan oleh insinyur tidak kehilangan arah, dan selalu berorientasi pada penyelesaian masalah yang relevan serta memberikan manfaat (#emph[Value Energy]) yang nyata bagi manusia.

== I: Solusi Baru
<i-solusi-baru>
Dalam metodologi pelaporan PICOC yang diterapkan pada Domain Aplikasi (PICOC-A), komponen #strong[I (Intervention / Intervensi)] secara spesifik merepresentasikan #strong[Solusi Baru (New Solution)] yang ditawarkan atau diusulkan untuk memecahkan masalah yang dihadapi oleh para pemangku kepentingan (#emph[stakeholders]).

Berikut adalah peran, karakteristik, dan posisi #strong[I: Solusi Baru] di dalam ekosistem Domain Aplikasi (A):

- #strong[Puncak dari Lapisan Multi-Domain:] Di dalam kerangka kerja #emph[Smart Engineering], Solusi Baru di tingkat Aplikasi (I(A)) tidak berdiri sendiri sebagai ide yang terisolasi. Solusi ini merupakan #strong[manifestasi akhir yang dibangun langsung berdasarkan arsitektur sistem yang telah dirancang pada Domain Sistem (I(S))]. Lebih jauh lagi, wujud solusi ini dimungkinkan karena ia memanfaatkan kemajuan instrumen di lapisan Teknologi (I(T)) dan divalidasi oleh teori-teori pada lapisan Riset Fundamental (I(F)).

- #strong[Fokus pada Peluang dan Pembaruan:] Menghadirkan I(A) berarti memperkenalkan sebuah peluang solusi yang benar-benar baru (#emph[novel]) dan diklaim lebih baik. Penyusunan I(A) harus dirancang sedemikian rupa untuk menunjukkan dengan jelas bagaimana solusi ini memperluas, memperbaiki, atau menawarkan cara kerja yang sangat berbeda (#emph[diverge]) dibandingkan dengan upaya-upaya pemecahan masalah di masa lalu.

- #strong[Contoh Implementasi (Platform Terintegrasi):] Sebagai contoh konkret dalam literatur rekayasa, Solusi Baru (I(A)) yang diusulkan kepada insinyur (sebagai #emph[stakeholder]) dapat berupa sebuah #strong[Platform Terintegrasi Prolog-Python]. Platform ini diusulkan sebagai intervensi solusi baru untuk mengatasi kelemahan alur kerja rekayasa konvensional, dengan memberikan kemampuan penalaran simbolik sekaligus pemrosesan data algoritmik di dalam satu wadah.

- #strong[Subjek Utama Evaluasi:] Pada tahap penyusunan metodologi, bentuk dari Solusi Baru (I(A)) harus dijabarkan dengan sangat rinci terkait implementasi atau pengujiannya. Hal ini karena I(A) akan langsung dikomparasikan atau "diadu" dengan Solusi Lama/Praktik Eksisting (#emph[Control] / C(A)) untuk membuktikan seberapa besar peningkatan performa atau manfaat akhir (#emph[Outcome] / O(A)) yang berhasil diciptakan bagi para pemangku kepentingan.

Secara keseluruhan, #strong[I(A) merupakan jawaban inovatif final---dapat berupa produk, layanan, atau sistem---yang diserahkan secara langsung kepada pemangku kepentingan] guna menyelesaikan kesenjangan masalah secara lebih cerdas dan efisien.

== Cx: Masalah Spesifik
<cx-masalah-spesifik>
Dalam metodologi pelaporan PICOC (#emph[Population, Intervention, Control, Outcome, Context]) yang diterapkan pada Domain Aplikasi (A), komponen #strong[Cx (Konteks) secara spesifik merujuk pada rumusan masalah, batasan (constraints), lingkungan, serta spesifikasi kebutuhan (requirements) yang harus diselesaikan untuk para pemangku kepentingan (stakeholders)].

Di dalam ekosistem perancangan #emph[Smart Engineering], #strong[Cx: Masalah Spesifik] menduduki posisi fundamental dengan peran-peran berikut:

- #strong[Sebagai Titik Tolak dan Pernyataan Masalah (Problem Statement):] Cx(A) merupakan fondasi utama yang memotivasi seluruh proses rekayasa. Pada tahap ini, insinyur harus mendefinisikan secara jelas apa yang menjadi masalah utama pemangku kepentingan (P(A)), serta #strong[mengidentifikasi kesenjangan (gap) antara kondisi ideal yang mereka butuhkan dengan ketersediaan solusi pada saat ini].

- #strong[Mendefinisikan Kriteria Keberhasilan Solusi (Requirements):] Konteks tidak sekadar berisi deskripsi masalah, tetapi juga merumuskan prasyarat yang wajib dipenuhi. Parameter yang dirumuskan dalam Cx(A) ini akan menjadi kompas bagi insinyur untuk memastikan bahwa Solusi Baru (I(A)) dan arsitektur sistem (S) yang mereka rancang benar-benar relevan dan mampu menjawab persoalan pemangku kepentingan.

- #strong[Memberikan Batasan dalam Metodologi Pengujian:] Ketika insinyur merancang pengaturan eksperimen di Domain Aplikasi, komponen Cx(A) dijabarkan kembali untuk #strong[merinci latar atau pengaturan spesifik (setting) serta batasan dari pengujian aplikasi tersebut]. Ini memastikan bahwa solusi yang diuji berada pada lingkungan yang mencerminkan realitas permasalahan yang dihadapi pengguna.

- #strong[Sebagai Tolok Ukur Interpretasi Hasil:] Dalam fase evaluasi akhir, peningkatan performa atau manfaat yang berhasil diciptakan (#emph[Outcome] / O(A)) harus selalu diinterpretasikan ulang berdasarkan konteks masalah awalnya (Cx(A)). Keberhasilan inovasi rekayasa diukur dari #strong[sejauh mana solusi tersebut secara langsung mampu menjawab pertanyaan-pertanyaan atau kesenjangan awal yang ditetapkan di dalam masalah spesifik ini].

Secara keseluruhan, pemosisian #strong[Cx (Konteks)] di dalam Domain Aplikasi bertindak sebagai "jangkar" yang memastikan bahwa kerumitan teknologi dan sistem di lapisan bawahnya tidak akan kehilangan arah. Cx(A) memastikan bahwa setiap tetes inovasi yang dilakukan selalu berorientasi pada pemecahan masalah dunia nyata bagi manusia.

= Domain Sistem (S)
<domain-sistem-s>
Dalam metodologi pelaporan PICOC (#emph[Population, Intervention, Control, Outcome, Context]) yang diterapkan secara berlapis pada kerangka #emph[Smart Engineering], #strong[Domain Sistem (S)] atau #emph[System Layer] menduduki posisi krusial sebagai jembatan penghubung antara penyelesaian masalah pengguna di Domain Aplikasi (A) dan mesin penggerak inti di Domain Teknologi (T).

Fokus utama dari Domain Sistem (S) adalah #strong[mencari atau merancang sebuah arsitektur sistem terintegrasi yang mampu memenuhi spesifikasi kebutuhan (dari domain aplikasi) sekaligus mewadahi dan menjalankan instrumen inovatif (dari domain teknologi)].

Penerapan kelima komponen PICOC secara spesifik pada Domain Sistem (PICOC-S) dijabarkan sebagai berikut:

- #strong[P(S) - Populasi (Population):] Berbeda dengan Domain Aplikasi yang menargetkan manusia (pemangku kepentingan), populasi pada Domain Sistem merujuk pada objek pengujian teknis. Ini mencakup #strong[kumpulan data (datasets), lingkungan simulasi, model rekayasa, atau ranah pengujian (testbeds)] tempat sistem tersebut dioperasikan dan dievaluasi.

- #strong[I(S) - Intervensi (Intervention):] Merepresentasikan #strong[sistem baru yang diusulkan], yang telah diintegrasikan dengan teknologi-teknologi kunci (#emph[Key Technologies]). Dalam contoh transportasi, I(S) adalah rancangan kendaraan cerdas secara utuh. Sedangkan dalam ranah rekayasa perangkat lunak, I(S) dapat berupa arsitektur platform terintegrasi yang menggabungkan mesin Prolog (penalaran) dan Python (komputasi algoritma).

- #strong[C(S) - Kontrol (Control):] Merupakan #strong[sistem dasar (baseline) atau sistem eksisting (lama) yang digunakan sebagai pembanding]. Pada perancangan platform perangkat lunak cerdas, C(S) adalah sistem Prolog mandiri atau skrip Python tradisional yang belum terintegrasi satu sama lain.

- #strong[O(S) - Hasil (Outcome):] Mengukur efektivitas operasional dari sistem yang dirancang melalui metrik performa tingkat sistem. Metrik pengukurannya mencakup #strong[tingkat akurasi, kecepatan (speed), pemanfaatan sumber daya (resource utilization), tingkat keandalan (reliability), hingga fleksibilitas alur kerja].

- #strong[Cx(S) - Konteks (Context):] Mendefinisikan #strong[kebutuhan spesifik akan sebuah sistem yang lebih baik], yang mampu memenuhi prasyarat solusi aplikasi sekaligus mewadahi prasyarat teknologi dasar di baliknya. Ini juga merinci latar belakang batasan desain dari sistem tersebut.

#strong[Posisi Domain Sistem (S) dalam Hierarki Lintas Domain] Di dalam struktur pelaporan yang komprehensif, keberhasilan pada Domain Sistem tidak berdiri sendiri, melainkan memiliki interkoneksi logis yang kuat dengan domain di atas dan di bawahnya:

- Peningkatan performa di tingkat sistem (O(S)) berfungsi sebagai bukti teknis yang secara langsung #strong[mendukung dan memungkinkan terwujudnya manfaat bagi pemangku kepentingan di tingkat Aplikasi (O(A))].- Sebaliknya, keberhasilan operasional sistem secara keseluruhan (O(S)) #strong[dimungkinkan oleh dan sangat bergantung pada peningkatan performa dan efisiensi dari modul mesin/instrumen yang berada di lapisan Teknologi (O(T))].

#strong[Contoh Metaphorikal dalam Rekayasa] Dalam studi perancangan transportasi, Domain Sistem berfokus secara eksklusif pada perancangan #strong[kendaraan sebagai sebuah entitas utuh]. Kendaraan tersebut dipandang sebagai sebuah sistem cerdas kompleks yang memanfaatkan siklus PUDAL untuk menavigasi lingkungan kerjanya, sambil terus-menerus mengelola dan mengoptimalkan Energi Produk (bahan bakar) agar dapat mengangkut beban penumpangnya secara aman dan efisien pada kecepatan yang diharapkan.

== P: Testbeds/Dataset
<p-testbedsdataset>
Dalam metodologi pelaporan PICOC yang diterapkan pada Domain Sistem (PICOC-S), komponen #strong[P (Populasi)] mengalami pergeseran makna yang signifikan dibandingkan domain di atasnya. Jika pada Domain Aplikasi (A) populasi merujuk pada manusia atau pemangku kepentingan (#emph[stakeholders]), pada Domain Sistem (S), #strong[Populasi direpresentasikan secara teknis sebagai] #strong[testbeds] #strong[\(ranah pengujian),] #strong[datasets] #strong[\(kumpulan data),] #strong[test sets] #strong[\(set pengujian), lingkungan simulasi, model rekayasa, hingga] #strong[system states] #strong[\(status/kondisi sistem)].

Pemosisian #strong[P:] #strong[Testbeds/Dataset] dalam ekosistem Domain Sistem memiliki peran dan wawasan fundamental sebagai berikut:

- #strong[Sebagai Lingkungan Validasi Terkontrol:] Domain Sistem (S) berfokus pada perancangan arsitektur sistem terintegrasi (seperti kendaraan cerdas utuh atau platform perangkat lunak) yang mewadahi teknologi inti. Sebelum sebuah sistem diserahkan kepada manusia (pemangku kepentingan) di Domain Aplikasi, sistem baru (Intervensi / I(S)) dan sistem lama (Kontrol / C(S)) harus diuji dan dikomparasikan di dalam lingkungan eksperimental yang presisi. #emph[Testbeds], #emph[datasets], dan lingkungan simulasi inilah yang bertindak sebagai "subjek uji" atau populasi tempat evaluasi operasional itu berlangsung.

- #strong[Wujud Nyata dalam Rekayasa Perangkat Lunak:] Dalam contoh perancangan platform perangkat lunak terintegrasi seperti Prolog-Python, wujud dari populasi P(S) ini adalah model-model rekayasa, kumpulan dataset yang diolah, serta berbagai kondisi sistem (#emph[system states]). Sistem baru diuji dengan cara memberikan berbagai skenario dari dataset tersebut untuk melihat seberapa tangguh arsitektur sistem dalam menangani tugas inferensi logis dan komputasi numerik secara bersamaan.

- #strong[Fondasi bagi Pengukuran Performa (Outcome):] Penetapan spesifikasi #emph[testbeds] atau #emph[datasets] (P(S)) sangat krusial karena ia menjadi landasan tempat metrik keberhasilan sistem (O(S)) akan diukur. Keberhasilan sistem tidak diukur dari persepsi pengguna pada tahap ini, melainkan dari metrik objektif dan kuantitatif seperti akurasi pemrosesan dataset, kecepatan komputasi (#emph[throughput] atau #emph[latency]), pemanfaatan sumber daya, hingga tingkat keandalan simulasi. Penjelasan rincian tentang #emph[testbeds] dan #emph[datasets] di dalam metodologi memastikan bahwa pengujian sistem tersebut bersifat objektif dan dapat direproduksi (#emph[reproducible]) oleh insinyur lain.

Singkatnya, di dalam kerangka kerja #emph[Smart Engineering], #strong[P:] #strong[Testbeds/Dataset] bertindak sebagai laboratorium pengujian. Evaluasi teknis yang sukses di atas #emph[testbed] atau dataset simulasi ini akan menghasilkan bukti peningkatan performa sistem yang sahih, yang pada gilirannya merupakan prasyarat mutlak sebelum solusi tersebut diklaim mampu memberikan manfaat nyata bagi manusia di dunia nyata.

== I: Arsitektur Sistem Cerdas
<i-arsitektur-sistem-cerdas>
Dalam metodologi pelaporan PICOC yang diterapkan pada Domain Sistem (PICOC-S), komponen #strong[I (Intervensi)] secara spesifik merujuk pada #strong[Arsitektur Sistem Cerdas (Proposed System)] yang diusulkan oleh insinyur.

Berikut adalah peran, karakteristik, dan posisi dari komponen #strong[I: Arsitektur Sistem Cerdas] di dalam ekosistem Domain Sistem (S):

#strong[Definisi dan Fungsi Utama] I(S) merepresentasikan sistem baru yang dirancang secara terintegrasi dengan menggabungkan berbagai teknologi kunci (#emph[Key Technologies]). Dalam penjabaran metodologinya, I(S) harus merinci arsitektur sistem secara keseluruhan, komponen-komponen penyusunnya, algoritma yang digunakan, serta bagaimana teknologi dasar diintegrasikan menjadi satu kesatuan yang fungsional. Sistem cerdas ini dirancang khusus untuk memenuhi spesifikasi kebutuhan (#emph[requirements]) yang telah ditetapkan demi menghadirkan solusi yang lebih baik di lapisan aplikasi.

#strong[Wujud I(S) dalam Rekayasa Perangkat Lunak] Dalam studi kasus perancangan perangkat lunak #emph[Smart Engineering], wujud konkret dari I(S) adalah #strong[Platform Terintegrasi Prolog-Python]. Arsitektur sistem cerdas ini dirancang dengan menggabungkan dua lingkungan yang berbeda:

- Mesin inferensi Prolog yang bertugas menangani penalaran simbolik, logika konseptual, dan manajemen pengetahuan.- Lingkungan #emph[interpreter] Python beserta ekosistem #emph[library]-nya yang bertugas menangani pemrosesan data numerik algoritmik, antarmuka pengguna, dan orkestrasi alur kerja.- Arsitektur ini disatukan oleh sebuah #emph[bridge library] (seperti PySWIP atau Janus) yang memfasilitasi komunikasi antar-proses dan pertukaran data antara kedua bahasa tersebut.

#strong[Wujud I(S) dalam Metafora Transportasi] Dalam contoh simulasi transportasi lintas domain, I(S) direpresentasikan oleh #strong[kendaraan sebagai sebuah entitas cerdas yang utuh], seperti halnya rancangan kendaraan otonom. Kendaraan (sistem) ini dirancang untuk secara aktif menjalankan siklus kecerdasannya (PUDAL) guna menavigasi lingkungan operasionalnya sembari mengelola energi produk (bahan bakar) yang dimilikinya secara efisien.

#strong[Posisi sebagai Jembatan Lintas Domain] Di dalam hierarki pelaporan multi-domain, Arsitektur Sistem Cerdas (I(S)) menduduki posisi sentral yang menghubungkan lapisan bawah dan atasnya:

- Sistem terintegrasi ini (I(S)) baru bisa berfungsi dengan optimal jika didukung oleh penemuan atau efisiensi mesin cerdas/instrumen teknologi yang kuat di lapisan bawahnya, yaitu Intervensi Teknologi (I(T)).- Sebaliknya, keberadaan arsitektur sistem operasional (I(S)) yang utuh ini merupakan prasyarat mutlak atau penyokong utama (#emph[enabler]) agar Solusi Baru yang bermanfaat (I(A)) dapat benar-benar diwujudkan dan diserahkan kepada manusia (pemangku kepentingan) di lapisan Aplikasi.

= Domain Teknologi (T)
<domain-teknologi-t>
Dalam kerangka kerja metodologi pelaporan PICOC multi-domain, #strong[Domain Teknologi (T)] beroperasi pada lapisan krusial yang menjembatani antara penelitian prinsip-prinsip dasar di Domain Fundamental (F) dan integrasi operasional operasional di Domain Sistem (S).

Fokus utama dari Domain Teknologi adalah #strong[menemukan, mengembangkan, atau memperbaiki Teknologi Kunci (Key Technology)---yang umumnya berupa mesin atau modul khusus---agar mampu mengeksekusi tugas-tugas krusial, seperti komputasi yang kompleks atau konversi energi, secara jauh lebih efektif berdasarkan prinsip sains dan rekayasa].

Penerapan kelima komponen PICOC secara spesifik pada Domain Teknologi (PICOC-T) dijabarkan sebagai berikut:

- #strong[P(T) - Populasi (Population):] Dalam domain ini, populasi yang menjadi subjek perlakuan atau pemrosesan bukanlah manusia atau sistem utuh, melainkan #strong[energi sumber, nilai input, data mentah, atau material] yang akan diproses oleh mesin tersebut.

- #strong[I(T) - Intervensi (Intervention):] Merepresentasikan #strong[Mesin atau Modul Teknologi (Technological Engine/Module) dengan instrumen atau metode baru yang diusulkan]. Dalam paradigma #emph[Smart Engineering], intervensi teknologi ini kerap kali diabstraksikan sebagai #emph[Smart Engine] yang mengadopsi siklus kecerdasan PUDAL untuk terus mengoptimalkan konversi energi di dalamnya.

- #strong[C(T) - Kontrol (Control):] Merupakan #strong[mesin, modul teknologi, instrumen, atau metode lama yang saat ini eksis], yang digunakan sebagai garis dasar (#emph[baseline]) pembanding untuk menguji efisiensi inovasi baru.

- #strong[O(T) - Hasil (Outcome):] Mengukur secara objektif #strong[peningkatan performa di dalam menjalankan tugas konversi atau komputasi spesifik tersebut]. Metrik pada level ini meliputi efisiensi konversi yang lebih tinggi, peningkatan presisi, kecepatan pemrosesan (#emph[faster processing]), hingga rasio sinyal terhadap gangguan (#emph[signal-to-noise ratio]) yang lebih baik.

- #strong[Cx(T) - Konteks (Context):] Mendefinisikan #strong[tantangan spesifik teknis, sasaran, maupun batasan] dalam mencari instrumen yang tepat untuk menjalankan proses konversi energi/tugas komputasi dengan baik.

#strong[Posisi Domain Teknologi (T) dalam Hierarki Lintas Domain] Di dalam struktur rekayasa yang komprehensif, keberhasilan pengujian pada Domain Teknologi (T) memiliki keterikatan logis yang tak terpisahkan dengan domain di atas dan di bawahnya:

- #strong[Penyokong Utama Kinerja Sistem (S):] Hasil peningkatan performa pada mesin atau modul teknologi (O(T)) menjadi #strong[prasyarat mutlak atau faktor pemungkin (enabler) bagi beroperasinya arsitektur sistem secara keseluruhan di Domain Sistem (O(S))]. Sebuah sistem cerdas hanya dapat memproses alur kerja dengan optimal apabila komponen mesin penggeraknya memiliki konversi energi yang berefisiensi tinggi.

- #strong[Berlandaskan Lapisan Fundamental (F):] Inovasi instrumen mesin atau metode pada level ini (I(T)) tidak diciptakan dari ruang hampa, melainkan dibangun dan disokong oleh divalidasinya prinsip, penemuan efek baru, atau teori ilmiah yang diuji pada lapisan Riset Fundamental (O(F)).

#strong[Contoh Wujud Nyata dalam Rekayasa]

- #strong[Pada Metafora Transportasi:] Di tingkat teknologi, masalah diartikan sebagai cara menemukan atau mendesain teknologi konversi mesin (M) yang sanggup menghasilkan, menyimpan, dan mengubah energi sumber alamiah (E) menjadi energi kerja mekanik (U) untuk kendaraan tersebut. Contoh radikalnya adalah penemuan instrumen #emph[Electromagnetic (EM) machine] yang diusulkan untuk mengonversi medan elektromagnetik antar-galaksi menjadi tenaga pendorong wahana antariksa.

- #strong[Pada Rekayasa Perangkat Lunak Cerdas:] Dalam perancangan arsitektur terintegrasi, perwujudan dari intervensi teknologi (I(T)) adalah pengembangan #strong[library jembatan atau] #strong[bridge libraries] (seperti PySWIP atau Janus). Teknologi modul ini secara khusus memiliki tugas krusial mengubah, mengelola pertukaran tipe data, dan memfasilitasi komunikasi komunikasi antar-proses yang berbeda, yakni antara mesin inferensi simbolik (Prolog) dengan komputasi numerik (Python). Peningkatan di ranah ini diukur (O(T)) dari seberapa kecil beban kinerja (#emph[overhead]) komunikasi yang terjadi serta kemulusan aliran datanya.

== P: Energi Sumber/Data Mentah
<p-energi-sumberdata-mentah>
Dalam metodologi pelaporan PICOC yang diterapkan pada tingkat Domain Teknologi (PICOC-T), komponen #strong[P (Populasi) tidak merujuk pada manusia, pemangku kepentingan, ataupun sistem yang sudah utuh. Sebaliknya, komponen ini direpresentasikan secara spesifik sebagai Energi Sumber (Source Energy), Nilai Input, Data Mentah (Raw Data), Fenomena, atau Material dasar].

Berikut adalah peran dan posisi #strong[P: Energi Sumber/Data Mentah] di dalam ekosistem perancangan Domain Teknologi (T):

- #strong[Sebagai Objek yang Diproses atau Dikonversi:] Fokus utama dari Domain Teknologi adalah mencari, mengembangkan, atau memperbaiki Teknologi Kunci (#emph[Key Technology])---biasanya berupa mesin atau modul instrumen tertentu---agar dapat mengeksekusi tugas-tugas konversi atau komputasi yang krusial. Di dalam domain ini, #strong[P(T) adalah bahan baku mentah yang akan dikenai tindakan atau diproses secara langsung oleh teknologi penggerak tersebut].

- #strong[Wujud dalam Metafora Transportasi (Fisik):] Jika merujuk pada desain mesin kendaraan, wujud dari populasi (P(T)) ini adalah #strong[energi sumber (source energy] #strong[\/ E) yang diperoleh atau ditangkap dari lingkungan (environment] #strong[\/ W)]. Tantangan utamanya adalah bagaimana mesin tersebut mampu menyimpan dan mengubah energi sumber yang mentah ini menjadi energi kerja mekanis (#emph[work energy] / U) secara maksimal untuk menggerakkan kendaraan.

- #strong[Wujud dalam Rekayasa Perangkat Lunak (Informasional):] Dalam contoh perancangan platform terintegrasi seperti Prolog-Python, wujud P(T) bergeser dari entitas fisik menjadi data logis. Populasi di sini mengambil bentuk #strong[kueri-kueri logika, struktur data, nilai-nilai input, basis pengetahuan, maupun tugas-tugas komputasi numerik mentah]. Teknologi atau modul yang dirancang (seperti pustaka #emph[bridge] PySWIP atau Janus) bertugas memproses data-data mentah ini untuk memastikan konversi tipe data lintas bahasa pemrograman berjalan lancar tanpa hambatan komunikasi.

- #strong[Faktor Penentu Evaluasi Efisiensi (Outcome):] Pendefinisian spesifikasi Energi Sumber atau Data Mentah (P(T)) sangat penting karena ia menjadi patokan awal untuk mengevaluasi performa teknologi (O(T)). Keberhasilan inovasi mesin atau algoritma di tingkat ini dinilai secara objektif dari #strong[seberapa tinggi efisiensi konversinya, seberapa cepat waktu pemrosesannya, dan seberapa besar kepresisian yang dicapai saat teknologi tersebut mengolah kumpulan material atau data mentah ini].

Singkatnya, pemosisian Energi Sumber atau Data Mentah sebagai "Populasi" di Domain Teknologi menegaskan bahwa pada lapisan rekayasa ini, fokus para insinyur bukan lagi pada pengguna akhir, melainkan murni #strong[berkonsentrasi untuk mengoptimalkan bagaimana bahan baku paling dasar---baik berupa aliran energi fisik maupun lalu lintas data komputasional---dapat dikonversi secara efisien oleh instrumen mesin menjadi bentuk energi yang fungsional bagi sebuah sistem].

== I: Engine/Modul Teknologi
<i-enginemodul-teknologi>
Dalam metodologi pelaporan PICOC yang diterapkan pada Domain Teknologi (PICOC-T), komponen #strong[I (Intervensi)] secara spesifik merujuk pada #strong[Mesin Teknologi (Technological Engine) atau Modul dengan instrumen maupun metode yang baru].

Berikut adalah peran, karakteristik, dan posisi #strong[I: Engine/Modul Teknologi] di dalam ekosistem Domain Teknologi (T):

- #strong[Fungsi Utama sebagai Pengeksekusi Tugas Krusial:] Fokus dari I(T) adalah menghadirkan teknologi penentu (#emph[Key Technology]) yang dirancang untuk mengeksekusi tugas-tugas inti secara efektif yang didasarkan pada prinsip-prinsip fundamental. Tugas-tugas ini umumnya mencakup proses konversi energi, komputasi yang sangat kompleks, atau eksekusi fungsi-fungsi spesifik lainnya. Pada saat merumuskan I(T), insinyur diwajibkan untuk mendeskripsikan secara rinci prinsip kerja dari mesin atau metode baru tersebut.

- #strong[Wujud sebagai] #strong[Smart Engine] #strong[\(Dalam Metafora Fisik):] Di dalam kerangka #emph[Smart Engineering], mesin teknologi ini kerap dikonseptualisasikan menggunakan model #emph[Smart Engine Abstraction] (SEA). Sebagai sebuah #emph[Smart Engine], mesin (M) ini memanfaatkan siklus kecerdasan PUDAL untuk mengoptimalkan konversi energi---misalnya mengubah Energi Produk (bahan bakar) menjadi energi kerja mekanis (U)---sambil mengintegrasikan algoritma dan kecerdasan buatan (#emph[Knowledge Energy]) di dalamnya. Sebuah contoh fiktif namun radikal di literatur adalah usulan #emph[Electromagnetic (EM) Machine] yang bertindak sebagai I(T) untuk mengonversi tenaga medan elektromagnetik murni menjadi gaya dorong bagi wahana antariksa.

- #strong[Wujud Modul Perangkat Lunak (Dalam Domain Informasional):] Apabila menilik pada perancangan platform perangkat lunak terintegrasi, wujud I(T) bukanlah mesin fisik, melainkan teknologi peranti lunak inti. Dalam kasus integrasi Python dan Prolog, komponen intervensi (I(T)) direpresentasikan oleh mesin inferensi Prolog, #emph[interpreter] Python, dan secara krusial #strong[pustaka penghubung (bridge libraries) seperti PySWIP atau Janus]. Modul jembatan ini bekerja sebagai pengeksekusi konversi data mentah (P(T)), di mana modul ini bertugas menangani kerumitan konversi tipe data antara bahasa Python dan term Prolog, serta mengelola konvensi eksekusi fungsi secara lintas bahasa.

- #strong[Fondasi Kinerja Sistem:] Engine atau modul teknologi (I(T)) memproses bahan baku berupa data mentah atau energi sumber (P(T)). Intervensi inovatif pada lapisan teknologi ini sangat esensial karena efisiensi, presisi, atau kecepatan (#emph[Outcome] / O(T)) yang berhasil dicapai oleh mesin penukar energi atau modul kodenya ini akan menjadi tumpuan utama yang memungkinkan beroperasinya arsitektur sistem operasional (I(S)) secara utuh pada lapisan Domain Sistem.

= Domain Riset Fundamental (F)
<domain-riset-fundamental-f>
Dalam metodologi pelaporan PICOC lintas domain (#emph[multi-domain]), #strong[Domain Riset Fundamental (F)] menempati lapisan paling dasar dan esensial di dalam kerangka kerja desain rekayasa. Fokus utama dari Domain Fundamental bukanlah menciptakan produk akhir untuk pengguna, melainkan #strong[menambah kumpulan pengetahuan (Body of Knowledge) tentang realitas, menemukan prinsip-prinsip sains atau rekayasa baru, dan memvalidasi teori-teori dasar].

Penerapan kelima komponen PICOC secara spesifik pada Domain Riset Fundamental (PICOC-F) dijabarkan sebagai berikut:

- #strong[P(F) - Populasi (Population):] Subjek yang diteliti pada level ini sangat abstrak, yakni berupa #strong[fenomena alam atau konseptual, entitas-entitas fundamental, serta nilai atau energi sumber yang sedang diinvestigasi].

- #strong[I(F) - Intervensi (Intervention):] Merepresentasikan gagasan fundamental yang baru, yang dapat berupa #strong[proses, teori, kerangka pemodelan (model), maupun pendekatan eksperimental baru] yang diusulkan oleh peneliti.

- #strong[C(F) - Kontrol (Control):] Merupakan #strong[teori, model, pendekatan, atau proses eksisting (lama)] yang digunakan sebagai landasan pembanding untuk menguji keabsahan teori baru tersebut.

- #strong[O(F) - Hasil (Outcome):] Keberhasilan di level ini tidak diukur dari uang atau kecepatan komputasi, melainkan dari #strong[terciptanya pengetahuan baru yang diinginkan, pemahaman mekanisme yang jauh lebih dalam, tervalidasinya prinsip-prinsip sains/logika, atau penemuan efek dan nilai yang sebelumnya belum diketahui].

- #strong[Cx(F) - Konteks (Context):] Merupakan latar belakang akademis yang memotivasi riset, yakni #strong[kebutuhan akan pengetahuan baru, keinginan untuk memahami mekanisme fundamental, atau eksplorasi terhadap wilayah teoretis atau saintifik yang belum dipetakan], yang nantinya akan relevan untuk mendukung domain di lapisan atasnya.

#strong[Posisi Fundamental (F) dalam Hierarki Lintas Domain] Di dalam struktur rekayasa yang komprehensif, Domain Riset Fundamental bertindak sebagai "akar" yang menyokong seluruh pohon inovasi. Keberhasilan dalam memvalidasi prinsip atau teori di lapisan Fundamental (O(F)) menjadi #strong[fondasi absolut yang menyokong dan memungkinkan penciptaan instrumen mesin atau metode di Domain Teknologi (O(T))]. Tanpa adanya teori yang sahih di level F, inovasi teknologi (T), arsitektur sistem (S), dan penyelesaian masalah di masyarakat (A) tidak akan memiliki pijakan keilmuan yang kuat.

#strong[Contoh Wujud Nyata dalam Rekayasa]

- #strong[Dalam Paradigma] #strong[Smart Engineering] #strong[& Konversi Energi:] Di tingkat fundamental, riset difokuskan pada upaya #strong[memahami dan merekayasa prinsip konversi transaksional antara berbagai dimensi energi PSKVE]. Contoh yang lebih radikal pada metafora transportasi antargalaksi adalah penemuan prinsip dasar (F) tentang bagaimana mengonversi Energi Elektromagnetik menjadi kerja mekanis murni.

- #strong[Dalam Rekayasa Perangkat Lunak Terintegrasi:] Pada pengembangan platform cerdas Prolog-Python, intervensi fundamental (I(F)) mencakup penerapan prinsip #strong[logika formal (seperti klausa Horn di Prolog), metodologi representasi pengetahuan (seperti desain ontologi), serta teknik penalaran tingkat tinggi (seperti unifikasi dan] #strong[backtracking)]. Pembuktian bahwa konsep ontologis (seperti Kelas, Individu, dan Properti) dapat dipetakan secara matematis ke dalam logika predikat merupakan keberhasilan di tingkat O(F) yang memungkinkan terbangunnya teknologi jembatan lintas-bahasa pemrograman.

== P: Fenomena/Prinsip Sains
<p-fenomenaprinsip-sains>
Dalam kerangka metodologi pelaporan PICOC lintas domain, #strong[Domain Riset Fundamental (F)] adalah lapisan paling dasar yang murni berfokus pada perluasan kumpulan pengetahuan (#emph[Body of Knowledge]) tentang realitas, penemuan prinsip baru, serta validasi teori. Pada lapisan abstrak ini, komponen #strong[P (Populasi) tidak lagi merujuk pada pemangku kepentingan (manusia), sistem utuh, ataupun bahan baku fisik, melainkan direpresentasikan secara spesifik sebagai Fenomena, Entitas Fundamental, atau Energi/Nilai Sumber yang sedang diinvestigasi].

Peran dan posisi #strong[P: Fenomena/Entitas Fundamental (P(F))] di dalam ekosistem riset fundamental dijabarkan sebagai berikut:

- #strong[Sebagai Subjek Utama Investigasi Sains dan Logika:] Populasi di tingkat ini merupakan entitas yang menjadi fokus pengamatan teoretis. Bentuk dari P(F) bisa mencakup fenomena alam yang abstrak atau entitas mendasar dari sebuah sistem nilai. Dalam konteks ilmu komputer seperti pengembangan sistem rekayasa perangkat lunak terintegrasi (misalnya ontologi Prolog), wujud populasi (P(F)) ini mengambil bentuk #strong[proposisi logis, konsep-konsep abstrak, relasi antar-entitas, hingga titik data fundamental].

- #strong[Target Evaluasi dari Teori atau Model Baru:] Tantangan utama (#emph[Context] / Cx(F)) di domain ini adalah menjawab pertanyaan mendasar tentang mekanisme dari populasi (P(F)) tersebut karena adanya celah pengetahuan (#emph[knowledge gap]). Untuk menjelaskan fenomena tersebut, peneliti mengusulkan sebuah Intervensi (I(F)) yang dapat berupa teori, kerangka pemodelan, atau pendekatan eksperimental yang sama sekali baru.

- #strong[Contoh Eksplorasi pada Fenomena Energi:] Dalam metafora inovasi kendaraan lintas galaksi, entitas yang menjadi "populasi" penelitian (P(F)) adalah #strong[fenomena medan energi elektromagnetik murni]. Riset fundamental akan meneliti fenomena ini untuk menemukan keahlian (#emph[know-how]) dan prinsip sains baru tentang bagaimana mengonversi energi elektromagnetik teoretis tersebut menjadi sebuah gaya kerja mekanis yang nyata.

- #strong[Batu Loncatan bagi Seluruh Hierarki Rekayasa:] Keberhasilan riset pada tingkat ini diukur dari seberapa dalam pemahaman baru yang didapat atau tervalidasinya prinsip-prinsip yang mengatur fenomena tersebut (#emph[Outcome] / O(F)). Evaluasi yang sukses pada fenomena dasar (P(F)) ini akan menciptakan teori yang kokoh, yang mana teori ini #strong[menjadi penyokong dan fondasi mutlak yang memungkinkan lahirnya instrumen di tingkat Teknologi (T), arsitektur operasional di tingkat Sistem (S), dan solusi inovatif di tingkat Aplikasi (A)].

Singkatnya, pemosisian #strong[Fenomena atau Entitas Fundamental sebagai "Populasi"] menegaskan bahwa tujuan utama Domain Fundamental adalah menginterogasi realitas alam, hukum-hukum konversi energi, atau struktur logika dasar. Penyelidikan mendalam terhadap "populasi" abstrak inilah yang akan menghasilkan kebenaran saintifik untuk menopang seluruh piramida inovasi di dalam #emph[Smart Engineering].

== I: Teori/Model Baru
<i-teorimodel-baru>
Dalam kerangka kerja pelaporan multi-domain PICOC, komponen #strong[I (Intervensi)] pada Domain Riset Fundamental (PICOC-F) secara spesifik direpresentasikan sebagai #strong[Teori, Model, Proses, atau Pendekatan Eksperimental Baru].

Berikut adalah peran, posisi, dan wujud #strong[I: Teori/Model Baru (I(F))] di dalam ekosistem Domain Riset Fundamental:

#strong[\1. Sebagai Jawaban atas Kesenjangan Pengetahuan (Knowledge Gap)] Domain Fundamental tidak ditujukan untuk merancang produk komersial, melainkan didorong oleh kebutuhan untuk memahami mekanisme dasar alam atau realitas yang belum dipetakan (Cx(F)). Oleh karena itu, Teori atau Model Baru (I(F)) yang diusulkan oleh peneliti berfungsi sebagai kerangka pikir atau hipotesis yang diuji untuk memvalidasi entitas fundamental atau fenomena yang sedang diteliti (P(F)).

#strong[\2. Fondasi Absolut bagi Seluruh Lapisan Rekayasa] Dalam struktur hierarkis #emph[Smart Engineering], Teori atau Model Baru (I(F)) bertindak sebagai "akar" pemikiran. Keberhasilan dalam memvalidasi prinsip atau model baru ini menjadi pengetahuan atau pemahaman baru (O(F)) yang secara langsung #strong[menyokong dan memungkinkan penciptaan instrumen mesin di lapisan Teknologi (O(T)), arsitektur operasional di lapisan Sistem (O(S)), dan pada akhirnya menghasilkan solusi nyata di lapisan Aplikasi (O(A))]. Tanpa adanya teori yang sahih (I(F)), keseluruhan inovasi di lapisan atasnya tidak akan memiliki landasan sains atau logika yang kuat.

#strong[\3. Wujud I(F) dalam Rekayasa Perangkat Lunak dan Kecerdasan Buatan] Dalam konteks pengembangan platform #emph[Smart Engineering] yang terintegrasi, wujud nyata dari intervensi fundamental (I(F)) ini meliputi penerapan prinsip-prinsip sains komputer dasar, seperti:

- #strong[Penerapan logika formal], misalnya penggunaan #emph[Horn clauses] (klausa Horn) yang menjadi basis dari bahasa Prolog.

- #strong[Metodologi representasi pengetahuan], seperti pemodelan desain Ontologi yang memanfaatkan Kelas, Individu, Properti, dan Relasi. Model teoretis ini dirancang untuk memastikan bahwa representasi konseptual manusia atas suatu domain teknik dapat diterjemahkan menjadi struktur data yang dapat dinalar secara presisi oleh mesin (#emph[machine-understandable model]).

#strong[\4. Wujud I(F) dalam Metafora Fisik dan Konversi Energi] Jika merujuk pada metafora desain transportasi dan energi, Teori atau Model Baru (I(F)) mempresentasikan penemuan prinsip-prinsip sains (#emph[know-how]) terkait cara memanipulasi energi.

- Contoh teoretis ekstrem yang disebutkan dalam sumber adalah riset fundamental yang menemukan model cara #strong[mengonversi tenaga Medan Elektromagnetik (EM) antar-galaksi menjadi gaya kerja mekanis murni] bagi sebuah wahana antariksa.- Dalam konteks energi yang lebih luas di kerangka #emph[Smart Engineering], I(F) berwujud pencarian dan pemodelan prinsip-prinsip #strong[Konversi Transaksional (Transactional Conversion)], yakni teori yang menjelaskan bagaimana dimensi energi PSKVE (seperti Energi Pengetahuan atau Energi Lingkungan) dapat dipertukarkan satu sama lain secara optimal.

Singkatnya, #strong[I: Teori/Model Baru (I(F))] adalah pijakan awal dari keseluruhan siklus inovasi rekayasa. Ia adalah gagasan teoretis murni yang, apabila tervalidasi kebenarannya, akan bertransformasi menjadi hukum sains atau pola desain yang memandu para insinyur dalam membangun teknologi (T) dan sistem (S) yang lebih cerdas.

#heading(level: 1, numbering: none)[Bagian 3: Integrasi Teknologi]
<bagian-3-integrasi-teknologi>
Dalam kerangka #emph[Smart Engineering], #strong[integrasi teknologi] bukan sekadar upaya teknis untuk menggabungkan dua perangkat lunak, melainkan merupakan pergeseran paradigma untuk memadukan sistem kecerdasan alami dan kecerdasan buatan ke dalam seluruh siklus rekayasa. Tujuan utamanya adalah untuk menjembatani kesenjangan antara model konseptual (cara manusia memahami masalah) dengan data atau logika yang dapat diinterpretasikan dan diproses oleh mesin.

#strong[Domain Sistem (S) sebagai Pusat Integrasi] Di dalam metodologi pelaporan multi-domain PICOC, proses integrasi ini berpusat pada #strong[Domain Sistem (S)]. Di lapisan inilah sebuah Arsitektur Sistem Cerdas (direpresentasikan sebagai Intervensi Sistem / I(S)) dirancang secara spesifik untuk mewadahi dan menggabungkan berbagai #strong["Teknologi Kunci" (Key Technologies)]. Sistem terintegrasi ini dirancang agar mampu memproses alur kerja dari komputasi matematis hingga penalaran logika secara bersamaan.

#strong[Wujud Utama Integrasi: Platform Prolog-Python] Sumber-sumber yang diberikan menyoroti rancangan #strong[Platform Terintegrasi Prolog-Python] sebagai contoh utama dan paling radikal dari integrasi teknologi di dalam #emph[Smart Engineering]. Integrasi ini menyatukan dua kekuatan paradigma pemrograman yang sangat berbeda namun saling melengkapi:

- #strong[Python (Kekuatan Algoritmik):] Berperan sebagai pengelola utama aplikasi yang menangani interaksi pengguna (UI), pemrosesan data numerik, pembelajaran mesin, dan orkestrasi alur kerja secara keseluruhan.

- #strong[Prolog (Kekuatan Penalaran Simbolik):] Didelegasikan sebagai mesin penalaran khusus (#emph[reasoning engine]) di latar belakang. Prolog menggunakan logika formal (seperti ontologi) untuk mengeksekusi inferensi logis, menjaga kepatuhan terhadap aturan sistem, dan menemukan kesimpulan tersembunyi dari relasi data yang kompleks.

#strong[Peran Modul Penghubung (Bridge Libraries) di Domain Teknologi (T)] Agar sistem gabungan ini dapat beroperasi secara mulus, integrasi membutuhkan intervensi spesifik di lapisan bawahnya, yakni #strong[Domain Teknologi (T)]. Wujud intervensi teknologi (I(T)) ini adalah penggunaan pustaka jembatan komunikasi (#emph[bridge libraries]) seperti #strong[PySWIP] atau #strong[Janus].

Teknologi kunci ini sangat vital karena ia bertugas menangani kerumitan komunikasi antar-proses dan #strong[konversi tipe data (data marshalling) secara mulus]. Sebagai contoh, pustaka ini secara otomatis mengubah struktur #emph[list] atau #emph[string] dari lingkungan Python menjadi #emph[term] atau #emph[atom] yang dapat dipahami oleh Prolog, lalu mengubah kembali hasil kueri logis dari Prolog ke dalam bentuk #emph[dictionary] di Python.

#strong[Manfaat dan Dampak Keberhasilan Integrasi (Outcomes)] Keberhasilan integrasi teknologi ini memberikan manfaat sistemik (#emph[System Outcome] / O(S)) yang sangat besar bagi praktik #emph[Smart Engineering], di antaranya:

- #strong[Modularitas Arsitektur:] Integrasi ini menciptakan arsitektur sistem yang fleksibel, di mana bahasa komputasi terbaik digunakan secara eksklusif untuk tugas yang paling tepat. Logika aturan tetap terisolasi dengan rapi di Prolog, sementara pengolahan data murni diurus oleh Python.

- #strong[Simulasi Dinamis dan Interaktif:] Integrasi ini memungkinkan Python untuk memanipulasi basis pengetahuan Prolog secara dinamis saat sistem berjalan (#emph[runtime]), misalnya dengan menambahkan fakta baru (#NormalTok("assertz");) atau menghapusnya (#NormalTok("retract");) berdasarkan interaksi pengguna. Kemampuan ini sangat penting untuk membangun sistem yang sadar-konteks (#emph[knowledge-aware]) yang mampu beradaptasi terhadap perubahan kondisi di dunia nyata.

Secara keseluruhan, integrasi teknologi dalam #emph[Smart Engineering] memberdayakan para insinyur untuk tidak hanya melakukan perhitungan matematis, tetapi juga menyematkan "pengetahuan dan logika" eksplisit ke dalam desain rekayasa. Hasil akhirnya adalah penyelesaian masalah pemangku kepentingan (Domain Aplikasi) yang jauh lebih cerdas, otomatis, dan dapat diverifikasi jalan penalarannya.

= Prolog (Penalaran Simbolik)
<prolog-penalaran-simbolik>
Prolog (#emph[Programming in Logic]) adalah bahasa pemrograman tingkat tinggi yang dibangun di atas fondasi logika formal, secara spesifik menggunakan subset kalkulus predikat orde pertama yang dikenal sebagai klausa Horn. Dalam ranah #emph[Smart Engineering], #strong[Prolog diandalkan sebagai mesin penalaran simbolik yang beroperasi secara deklaratif], di mana insinyur cukup mendefinisikan #emph[apa] kebenaran yang ada melalui "fakta" dan #emph[apa] hubungan bersyarat di antaranya melalui "aturan", tanpa perlu menyusun langkah-langkah prosedural tentang #emph[bagaimana] cara menghitungnya.

#strong[Kebutuhan akan Integrasi Teknologi] Meskipun sangat kuat dalam penalaran logis, Prolog memiliki keterbatasan jika digunakan secara mandiri untuk rekayasa modern. Alat rekayasa tradisional (seperti skrip Python standar atau basis data relasional) sangat unggul dalam komputasi numerik, pemrosesan data dalam jumlah masif, dan pembangunan antarmuka, tetapi mereka sering kali kewalahan saat harus menangani manipulasi simbolik, deduksi logis yang kompleks, atau kepatuhan terhadap aturan-aturan domain (#emph[constraints]). Oleh karena itu, diperlukan #strong[Integrasi Teknologi] yang menggabungkan kehebatan algoritmik dari ekosistem seperti Python dengan kemampuan penalaran simbolik dan representasi pengetahuan ontologis dari Prolog.

#strong[Wujud Integrasi pada Domain Teknologi (T)] Di dalam lapisan Teknologi (I(T)), integrasi dua paradigma yang berbeda ini dimungkinkan oleh inovasi berupa #strong[pustaka penghubung (bridge libraries) seperti PySWIP atau Janus]. Modul teknologi ini bertugas melakukan "penerjemahan" tingkat rendah yang krusial, seperti mengonversi atom dan struktur list di Prolog menjadi #emph[string] dan struktur data bawaan di Python, dan begitu pula sebaliknya. Pustaka inilah yang memastikan komunikasi antar-proses dan pertukaran data antara domain komputasi numerik dan domain penalaran simbolik berjalan tanpa hambatan dan dengan latensi yang sangat minim.

#strong[Alur Kerja Dinamis pada Domain Sistem (S)] Pada tingkat arsitektur sistem terintegrasi (I(S)), kolaborasi Prolog dan Python menghasilkan alur kerja simulasi atau aplikasi yang sangat cerdas dan dinamis:

- #strong[Orkestrasi dan Manajemen State:] Python bertindak sebagai orkestrator yang menginisialisasi mesin Prolog, memuat basis pengetahuan dasar, serta menangani antarmuka pengguna dan komputasi matematis.

- #strong[Penyuntikan Fakta Dinamis (Dynamic Assertion):] Selama aplikasi atau simulasi berjalan, Python dapat terus-menerus memperbarui kondisi dunia nyata dengan menyuntikkan (meng-#emph[assert]) fakta-fakta baru secara dinamis ke dalam basis pengetahuan Prolog, atau menariknya kembali (#emph[retract]) saat statusnya berubah.

- #strong[Delegasi Penalaran:] Saat sistem perlu mengevaluasi aturan yang rumit---misalnya memastikan apakah desain struktur telah mematuhi aturan standar tertentu, atau apakah komponen sistem memenuhi syarat kelayakan logis---Python akan mengirimkan kueri ke Prolog. Mesin inferensi Prolog (menggunakan metode resolusi dan #emph[backtracking]) akan mencari kebenaran logis dari kueri tersebut dan mengembalikan jawabannya kepada Python untuk divisualisasikan atau diproses lebih lanjut.

#strong[Dampak Integrasi (Outcome / O(S) & O(T))] Hasil dari integrasi teknologi ini adalah #strong[arsitektur perangkat lunak yang sangat modular di mana setiap bahasa digunakan untuk tugas paling optimalnya]. Prolog difokuskan murni untuk mengorkestrasi logika kompleks dan pencarian pemenuhan kendala, sementara Python mengelola pemrosesan numerik dan interaksi sistem. Pada akhirnya, penyatuan penalaran simbolik ini dengan komputasi modern membuka jalan untuk menciptakan perangkat lunak #emph[Smart Engineering] yang tidak hanya mampu "menghitung", tetapi juga mampu "memahami" model konseptual dari sistem yang dirancang.

== Representasi Fakta & Aturan
<representasi-fakta-aturan>
Dalam konteks penalaran simbolik menggunakan Prolog, #strong[Representasi Fakta dan Aturan] merupakan fondasi utama untuk membangun basis pengetahuan (#emph[knowledge base]) yang bersandar pada logika formal (khususnya subset kalkulus predikat yang dikenal sebagai klausa Horn). Berbeda dengan bahasa pemrograman algoritmik yang prosedural, Prolog beroperasi secara deklaratif: insinyur hanya perlu mendefinisikan #emph[apa] yang secara logis benar dan #emph[bagaimana] hubungannya, tanpa perlu memprogram langkah komputasinya.

#strong[Representasi Fakta (Facts)] Fakta adalah #strong[pernyataan deklaratif yang menegaskan kebenaran tanpa syarat (kebenaran absolut) tentang objek di dalam domain masalah]. Dalam pemodelan ontologi rekayasa cerdas, fakta digunakan untuk mendeklarasikan entitas-entitas dasar beserta atributnya:

- #strong[Kelas dan Individu:] Diwakili oleh predikat #emph[unary] (satu argumen). Contohnya, #NormalTok("student(alice)."); secara eksplisit menyatakan sebuah fakta bahwa 'alice' (individu) adalah bagian dari kelas 'mahasiswa'.

- #strong[Properti dan Atribut:] Dinyatakan melalui predikat biner atau terner. Misalnya, fakta #NormalTok("has_age(alice, 20)."); menegaskan nilai atribut umur bagi individu tersebut.

- #strong[Relasi Dasar:] Digunakan untuk menyatakan tautan langsung antar-entitas, seperti #NormalTok("prerequisite(cs202, cs101)."); yang berarti mata kuliah CS101 adalah prasyarat bagi CS202.

#strong[Representasi Aturan (Rules)] Sementara fakta memberikan data mentah, aturan berfungsi untuk #strong[mendefinisikan kebenaran kondisional dan membangun hubungan deduktif di antara fakta-fakta tersebut]. Aturan ditulis dalam format #NormalTok("Head :- Body.");, yang secara logis diinterpretasikan sebagai "Head bernilai benar #emph[jika] semua syarat di dalam Body bernilai benar".Fungsionalitas aturan ini sangat luas:

- #strong[Menemukan Relasi Implisit:] Aturan memungkinkan sistem mendeduksi hubungan yang tidak dinyatakan secara tertulis. Sebagai contoh, #NormalTok("friends(X,Y) :- likes(X,Y), likes(Y,X)."); akan menyimpulkan bahwa X dan Y adalah teman jika mereka terbukti memiliki fakta saling menyukai.

- #strong[Mewujudkan Hierarki dan Pewarisan (Inheritance):] Aturan digunakan untuk memetakan hierarki kelas. Aturan #NormalTok("mammal(X) :- cat(X)."); menetapkan logika bahwa siapa pun (X) yang berstatus sebagai kucing, secara otomatis mewarisi identitas sebagai mamalia.

- #strong[Mengevaluasi Batasan dan Syarat Logis:] Dalam kasus sistem terintegrasi, aturan digunakan untuk penalaran kompleks. Contohnya, aturan #NormalTok("can_enroll(Student, Course)"); pada simulasi sistem universitas tidak sekadar mengecek fakta pendaftaran, tetapi secara dinamis memverifikasi apakah mahasiswa eksis, apakah ia belum mengambil kelas tersebut, dan mendeduksi apakah ia memenuhi daftar prasyaratnya berdasarkan fakta yang ada.

#strong[Sinergi dalam Skenario Integrasi Teknologi] Penggabungan antara basis fakta yang solid dengan logika aturan inilah yang menjadi bahan bakar bagi kecerdasan penalaran Prolog. Saat diintegrasikan dengan Python, Python dapat menyuntikkan (meng-#emph[assert]) fakta-fakta baru ke dalam Prolog yang merepresentasikan kondisi dunia nyata saat ini. Selanjutnya, saat sistem dihadapkan pada pertanyaan yang rumit, #strong[Prolog akan secara otomatis menggunakan mesin inferensinya (melalui metode] #strong[unification] #strong[dan] #strong[backtracking) untuk menelusuri fakta, mengevaluasi aturan secara rekursif, dan memberikan kesimpulan logis yang valid]. Pada akhirnya, arsitektur yang digerakkan oleh relasi simbolik ini melahirkan platform rekayasa yang sanggup "memahami" model desain secara konseptual.

== Mesin Inferensi Logika
<mesin-inferensi-logika>
Di dalam bahasa pemrograman Prolog, #strong[Mesin Inferensi Logika (Inference Engine) adalah komponen penggerak utama yang memungkinkan sistem untuk melakukan penalaran simbolik secara otomatis]. Berbeda dengan bahasa pemrograman algoritmik tradisional yang mengharuskan insinyur memprogram "bagaimana" (#emph[how]) cara menghitung suatu masalah secara prosedural, Prolog beroperasi secara deklaratif dengan mengandalkan mesin inferensi bawaan ini untuk mendeduksi jawaban dari "apa" (#emph[what]) yang sudah dideklarasikan dalam bentuk fakta dan aturan.

#strong[Mekanisme Kerja Mesin Inferensi] Mesin inferensi Prolog dirancang untuk memproses logika formal, khususnya subset dari kalkulus predikat orde pertama yang dikenal sebagai klausa Horn. Dalam menjalankan evaluasi logis, mesin ini menggunakan beberapa mekanisme inti:

- #strong[Pembuktian Teorema Resolusi (Resolution Theorem Prover):] Saat pengguna atau sistem mengajukan kueri (pertanyaan), mesin inferensi berfungsi sebagai pembukti teorema otomatis yang mencari tahu apakah pernyataan tersebut benar berdasarkan basis pengetahuan yang tersedia.

- #strong[Pencarian Mendalam dengan Runut-Balik (Depth-First Search with Backtracking):] Untuk menjawab kueri, mesin mencari solusi dengan menelusuri fakta dan aturan secara mendalam (#emph[depth-first]). Jika sebuah jalur evaluasi menemui jalan buntu (kondisi tidak terpenuhi), mesin akan secara otomatis melakukan #emph[backtracking] (runut-balik) untuk mengeksplorasi cabang alternatif atau kombinasi variabel lain hingga menemukan solusi logis yang valid.

- #strong[Unifikasi (Unification):] Mekanisme ini merupakan fondasi di mana mesin secara otomatis mencocokkan pola variabel dalam kueri dengan struktur fakta atau aturan yang ada di dalam ontologi.

#strong[Beroperasi dengan Asumsi Dunia Tertutup (Closed World Assumption)] Karakteristik fundamental dari mesin inferensi Prolog adalah ia beroperasi di bawah prinsip #emph[Closed World Assumption] (CWA). Prinsip ini menetapkan bahwa #strong[jika mesin inferensi tidak dapat membuktikan suatu pernyataan bernilai benar dari fakta dan aturan yang ada, maka pernyataan tersebut diasumsikan mutlak salah] (juga dikenal sebagai #emph[Negation as Failure]). Walaupun sangat efisien untuk batas domain yang pasti, sifat CWA ini menjadi tantangan tersendiri ketika Prolog digunakan untuk merancang sistem yang menghadapi informasi yang tidak lengkap dari dunia nyata.

#strong[Peran Sentral dalam Integrasi Sistem Rekayasa (Smart Engineering)] Di dalam perancangan platform #emph[Smart Engineering] modern, kekuatan mesin inferensi ini diisolasi untuk fokus pada hal yang paling ia kuasai, lalu diintegrasikan dengan bahasa multiguna seperti Python.

Dalam arsitektur terintegrasi tersebut:

- Python mendelegasikan tugas-tugas yang membutuhkan penyelesaian kendala (#emph[constraint satisfaction]), deduksi yang rumit, pencarian rute berbasis aturan, atau pengecekan kepatuhan desain #strong[secara eksklusif kepada mesin inferensi Prolog].- Karena mesin inferensi ini bersifat #emph[built-in] (bawaan), insinyur perangkat lunak tidak perlu lagi memprogram ulang logika pencarian atau deduksi kompleks dari nol. Begitu ontologi dan aturan didefinisikan, kemampuan penalaran tingkat tinggi sudah secara inheren tersedia untuk menjawab kueri rumit yang dikirimkan oleh Python.

Singkatnya, #strong[Mesin Inferensi Logika adalah "otak" deduktif di balik Prolog]. Mesin inilah yang mengubah kumpulan fakta mentah dan aturan hierarkis menjadi sebuah sistem dinamis yang sanggup menalar, mencari kesimpulan tersembunyi, dan memastikan konsistensi konseptual dari sebuah sistem rekayasa.

== Pemetaan Komponen Ontologi
<pemetaan-komponen-ontologi>
Dalam ranah penalaran simbolik menggunakan Prolog, #strong[Pemetaan Komponen Ontologi (Ontology Component Mapping) adalah proses sistematis menerjemahkan model konseptual dari suatu domain (seperti kelas, atribut, dan relasi) ke dalam struktur logika formal Prolog, yakni dalam wujud fakta dan aturan]. Pemetaan ini bertindak sebagai jembatan krusial yang mengubah pemahaman konseptual manusia menjadi representasi data logis yang dapat dipahami dan dinalar secara otomatis oleh mesin komputasi.

Secara spesifik, komponen-komponen inti ontologi dipetakan ke dalam konstruksi bahasa Prolog melalui pendekatan berikut:

- #strong[Pemetaan Kelas (Classes) dan Individu (Individuals):] Kelas direpresentasikan menggunakan predikat #emph[unary] (satu argumen), di mana nama predikat merepresentasikan nama kelas, dan argumennya adalah individu di dalamnya. Individu itu sendiri ditulis sebagai #emph[atom] atau konstanta. Sebagai contoh, pernyataan #NormalTok("student(alice)."); secara langsung memetakan individu berwujud atom 'alice' sebagai anggota dari kelas 'student'. Relasi keanggotaan kelas yang eksplisit juga dapat dituliskan dengan predikat biner, seperti #NormalTok("isa(louis, man).");.

- #strong[Pemetaan Properti dan Atribut (Properties/Attributes):] Atribut fisik maupun abstrak yang dimiliki oleh suatu entitas dipetakan menjadi fakta Prolog, umumnya menggunakan predikat biner atau terner. Struktur standarnya adalah #NormalTok("attribute(ObjectID, AttributeName, Value)");, contohnya #NormalTok("property(human, legs, two)."); atau pemetaan spesifik individu seperti #NormalTok("has_age(alice, 20).");. Keunggulan pemetaan ini di Prolog adalah #strong[nilai properti tidak hanya terbatas pada deklarasi fakta mutlak, tetapi juga bisa diturunkan secara dinamis melalui aturan (deduksi) logis].

- #strong[Pemetaan Relasi (Relationships):] Keterkaitan makna antar-individu atau antar-kelas diekspresikan secara alami menggunakan predikat biner atau #emph[N-ary]. Relasi bisa berwujud koneksi langsung (misalnya #NormalTok("father_of(joe, paul).");), atau direpresentasikan sebagai #strong[relasi kompleks turunan (derived relationships) yang dirumuskan melalui logika aturan]. Contohnya adalah aturan #NormalTok("friends(X,Y) :- likes(X,Y), likes(Y,X)."); yang memetakan bahwa sistem dapat secara mandiri menyimpulkan relasi pertemanan antara X dan Y apabila keduanya terbukti memiliki fakta saling menyukai.

- #strong[Pemetaan Hierarki Kelas dan Pewarisan (Class Hierarchies & Inheritance):] Hierarki ontologi sangat efektif dipetakan menggunakan aturan (#emph[rules]) Prolog.Hubungan #emph[subclass] (atau #emph[a\_kind\_of]) didefinisikan dengan aturan seperti #NormalTok("mammal(X) :- cat(X).");, yang menegaskan bahwa secara logis setiap instans dari kelas kucing juga mewarisi identitas kelas mamalia. Lebih lanjut, #strong[pemetaan aturan hierarkis ini secara otomatis mengaktifkan mekanisme pewarisan sifat (property inheritance)]. Properti yang dimiliki oleh superkelas akan dieksplorasi secara rekursif sehingga diwariskan ke subkelas di bawahnya. Prolog juga memiliki kemampuan mendefinisikan aturan pengecualian (#emph[property overriding]), di mana sistem akan memprioritaskan pengecekan nilai atribut lokal yang spesifik terlebih dahulu sebelum menggunakan nilai bawaan yang diwariskan.

#strong[Signifikansi dalam Konteks yang Lebih Luas (Smart Engineering)] Di dalam kerangka kerja multi-domain #emph[Smart Engineering], proses pemetaan ontologi ke konstruksi Prolog menduduki posisi sentral pada Domain Riset Fundamental (I(F)).

Dengan memetakan komponen ontologi menjadi sekumpulan klausa Horn (fakta dan aturan logis), para insinyur tidak sekadar membuat pangkalan data statis, melainkan #strong[menciptakan model pengetahuan deklaratif yang "hidup"]. Pemetaan langsung ini memastikan bahwa mesin inferensi Prolog (#emph[built-in inference engine]) dapat menggunakan algoritma unifikasi dan penelusuran runut-balik (#emph[backtracking]) untuk mengeksekusi penalaran simbolik tingkat tinggi. Pada akhirnya, hal ini memungkinkan sistem cerdas untuk mencari kesimpulan tersembunyi, menjawab kueri yang sangat kompleks, dan memverifikasi aturan-aturan rekayasa yang dinamis.

= Python (Algoritma & Aplikasi)
<python-algoritma-aplikasi>
Dalam kerangka Integrasi Teknologi untuk platform #emph[Smart Engineering], #strong[Python beroperasi sebagai pilar utama untuk eksekusi algoritma prosedural, komputasi numerik, dan pengembangan aplikasi]. Sementara Prolog secara khusus digunakan sebagai mesin penalaran simbolik, Python melengkapinya dengan keserbagunaan dan ekosistem pustakanya (#emph[libraries]) yang sangat luas yang mencakup sains data, komputasi matematis, dan pembuatan antarmuka pengguna (UI).

Di dalam arsitektur sistem terintegrasi (berada pada lapisan Domain Sistem / I(S)), Python memiliki peran dan alur kerja spesifik sebagai berikut:

#strong[\1. Python sebagai Orkestrator dan Pengendali Alur Kerja] Dalam integrasi ini, Python bertindak sebagai "pengendali utama" yang mengatur interaksi pengguna, melakukan pemrosesan data awal (#emph[preprocessing]), dan mengelola alur kerja aplikasi secara keseluruhan. Python difokuskan untuk menangani tugas-tugas prosedural dan algoritmik murni yang merupakan keunggulannya, sementara tugas deduksi logika, evaluasi kendala (#emph[constraints]), dan kueri berbasis pengetahuan "didelegasikan" secara eksklusif ke mesin Prolog di latar belakang.

#strong[\2. Membangun Simulasi yang Dinamis (Dynamic Interaction)] Kekuatan komputasi Python memungkinkan arsitektur ini untuk menjalankan simulasi rekayasa yang sangat dinamis. Alur kerja integrasi ini berjalan secara berkesinambungan:

- #strong[Inisialisasi:] Skrip Python bertugas menginisialisasi sesi Prolog dan memuat berkas basis pengetahuan ontologis (misalnya #NormalTok(". Pl");) ke dalam memori.

- #strong[Manipulasi Fakta Dinamis:] Python dapat secara dinamis memodifikasi basis pengetahuan Prolog saat aplikasi atau simulasi sedang berjalan (#emph[runtime]). Menggunakan fungsi antarmuka, Python bisa menyuntikkan fakta baru (melalui #NormalTok("assertz");) yang merepresentasikan status sistem atau input lingkungan terkini, serta menariknya kembali (#NormalTok("retract");) saat status tersebut sudah tidak relevan.

- #strong[Eksekusi dan Visualisasi:] Python menyusun kueri logika berupa #emph[string] untuk dikirimkan ke Prolog. Setelah Prolog melakukan penalaran, Python bertugas mengekstraksi solusi tersebut, memprosesnya dengan algoritma numerik lanjutan, dan menampilkannya melalui visualisasi atau antarmuka aplikasi.

#strong[\3. Konversi Data secara Mulus di Tingkat Teknologi (T)] Agar kemampuan aplikasi Python dan penalaran Prolog bisa menyatu, integrasi ini sangat bergantung pada keberadaan teknologi jembatan (#emph[bridge libraries] / I(T)) seperti #strong[PySWIP] atau #strong[Janus]. Pustaka inilah yang memungkinkan program Python berinteraksi dengan mulus melalui #strong[manajemen konversi tipe data (data marshalling)]. Sebagai contoh, pustaka ini secara otomatis mengubah struktur #emph[string], #emph[integer], atau #emph[list] di dalam algoritma Python menjadi bentuk #emph[atom] atau #emph[term] yang valid bagi Prolog, dan sebaliknya mengubah variabel hasil deduksi Prolog menjadi struktur #emph[dictionary] di Python.

Secara keseluruhan, pendelegasian arsitektural yang menempatkan Python sebagai mesin aplikasi algoritma dan Prolog sebagai mesin logika menghasilkan landasan yang kokoh bagi #emph[Smart Engineering]. Sinergi ini (#emph[Outcome] / O(S) & O(T)) memungkinkan insinyur untuk merancang simulasi dan perangkat lunak yang bukan hanya unggul dalam komputasi matematis (#emph[number-crunching]), tetapi juga memiliki pemahaman terkomputasi yang adaptif dan "sadar-konteks" terhadap model konseptual dunia nyata.

== Pemrosesan Data
<pemrosesan-data>
Dalam arsitektur terintegrasi Prolog-Python untuk #emph[Smart Engineering], #strong[Python beroperasi sebagai pilar utama untuk eksekusi algoritma prosedural, komputasi numerik, dan pengembangan aplikasi]. Sementara Prolog difokuskan pada penalaran simbolis dan deduksi logika, Python mengambil alih seluruh beban kerja yang berkaitan dengan #strong[pemrosesan data (data processing/handling)].

Peran dan alur kerja pemrosesan data oleh Python di dalam ekosistem ini mencakup beberapa aspek utama:

#strong[\1. Pra-pemrosesan Data dan Orkestrasi Alur Kerja] Python bertindak sebagai pengatur utama (#emph[orchestrator]) di lapisan aplikasi dan sistem. Tugas utamanya mencakup #strong[mengelola interaksi pengguna, menangani input/output data (I/O), serta melakukan pra-pemrosesan data (data preprocessing)] sebelum mendelegasikan tugas-tugas penalaran atau kueri pengetahuan yang kompleks kepada mesin Prolog.

#strong[\2. Komputasi Numerik dan Analisis Data] Berbeda dengan Prolog yang unggul dalam logika deklaratif, Python mewakili pendekatan algoritmik tradisional yang #strong[sangat unggul dalam komputasi numerik dan pemrosesan data bervolume besar]. Dengan memanfaatkan ekosistem pustakanya (#emph[libraries]) yang luas di bidang sains data, Python mengeksekusi perhitungan matematis, pemrosesan prosedural, dan analisis data numerik yang tidak ideal untuk diselesaikan oleh mesin inferensi logika.

#strong[\3. Pertukaran dan Konversi Tipe Data (Data Marshalling)] Salah satu tantangan terbesar dalam pemrosesan data lintas bahasa adalah mengelola aliran data antara domain komputasi (Python) dan domain simbolis (Prolog). Integrasi ini bergantung pada modul jembatan (#emph[bridge libraries] seperti PySWIP atau Janus) yang memfasilitasi komunikasi data secara transparan. Pustaka ini #strong[bertanggung jawab secara otomatis mengonversi struktur data Python (seperti] #strong[string,] #strong[integer,] #strong[float,] #strong[list, dan] #strong[dictionary) menjadi tipe data Prolog (atom,] #strong[number,] #strong[term,] #strong[list)], dan begitu pula sebaliknya saat menerima hasil evaluasi dari Prolog. Konversi yang mulus ini membebaskan insinyur dari kerumitan melakukan serialisasi data secara manual.

#strong[\4. Pemrosesan Hasil Inferensi dan Visualisasi] Setelah Prolog selesai mengevaluasi sebuah fakta atau mendeduksi aturan logis, hasil atau solusi tersebut dikembalikan kepada Python. #strong[Python bertugas mengambil hasil kueri ini, lalu memprosesnya lebih lanjut menggunakan algoritma numerik, memanfaatkannya untuk pengambilan keputusan aplikasi, atau menampilkannya kepada pengguna melalui visualisasi data dan antarmuka pengguna (UI)].

Secara keseluruhan, pemosisian Python khusus untuk pemrosesan data dan komputasi matematis menciptakan arsitektur perangkat lunak rekayasa yang sangat modular. Sinergi ini memastikan bahwa sistem dapat #strong[menghitung secara presisi sekaligus menalar secara konseptual], menghasilkan perangkat lunak yang jauh lebih cerdas, adaptif, dan mampu mengorkestrasi alur kerja rekayasa dunia nyata.

== Antarmuka Pengguna
<antarmuka-pengguna>
Dalam arsitektur terintegrasi Prolog-Python untuk platform #emph[Smart Engineering], #strong[Python secara eksklusif mengemban tanggung jawab pada lapisan aplikasi, yang salah satu fokus utamanya adalah pengembangan Antarmuka Pengguna (User Interface] #strong[\/ UI) serta interaksi pengguna].

Sementara Prolog bekerja di latar belakang sebagai mesin penalaran simbolis dan basis pengetahuan, Python bertindak sebagai "wajah" dari sistem yang berhadapan langsung dengan manusia. Posisi dan peran antarmuka pengguna ini dijabarkan sebagai berikut:

- #strong[Pengelola Interaksi dan Alur Kerja Utama:] Aplikasi yang dibangun dengan Python bertugas untuk #strong[mengelola seluruh interaksi pengguna, mengumpulkan input atau parameter awal, dan mengatur alur kendali (control flow)]. Ketika pengguna memberikan perintah melalui antarmuka Python, aplikasi akan meneruskan data tersebut kepada mesin Prolog untuk dievaluasi logika atau kendalanya (#emph[constraints]), untuk kemudian ditarik kembali hasil inferensinya.

- #strong[Visualisasi dan Presentasi Hasil:] Setelah mesin Prolog menyelesaikan evaluasi logisnya, kode Python akan mengambil solusi tersebut untuk diekstrak dan diproses lebih lanjut. Tugas akhir dari antarmuka pengguna Python adalah #strong[menyajikan kembali hasil deduksi dan komputasi tersebut kepada pengguna dalam format antarmuka visual yang mudah dipahami].

- #strong[Pemanfaatan Ekosistem Pustaka (Libraries) yang Kaya:] Fleksibilitas Python menjadikannya pilihan ideal untuk pengembangan aplikasi karena ia didukung oleh ekosistem pustaka yang sangat luas yang mencakup pengembangan web, visualisasi data, dan Antarmuka Pengguna Grafis (GUI).

- #strong[Pengembangan Simulasi yang Interaktif:] Dalam studi kasus pembuatan alat simulasi rekayasa yang lebih canggih, antarmuka pengguna grafis (GUI) dapat dibangun #strong[menggunakan pustaka Python spesifik seperti Dash, Plotly, atau Streamlit]. Keberadaan UI yang interaktif ini #strong[sangat memudahkan insinyur atau pengguna dalam memasukkan parameter skenario, memilih berbagai alternatif solusi, serta memvisualisasikan hasil simulasi secara dinamis].

Secara keseluruhan, pendelegasian pengembangan antarmuka pengguna kepada Python memastikan bahwa kerumitan ontologi dan logika formal di dalam Prolog dapat disembunyikan, lalu diubah menjadi perangkat lunak rekayasa yang interaktif, visual, dan ramah pengguna di dunia nyata.

== Orkestrasi Simulasi
<orkestrasi-simulasi>
Dalam ekosistem platform #emph[Smart Engineering] yang terintegrasi, #strong[Python mengambil peran sentral sebagai orkestrator yang mengendalikan dan menjalankan keseluruhan alur simulasi]. Sementara Prolog beroperasi murni sebagai fondasi basis pengetahuan dan mesin penalaran logis, Python menyediakan aliran kendali imperatif (#emph[imperative control flow]) serta kemampuan komputasi numerik yang mutlak dibutuhkan untuk "menghidupkan" ontologi tersebut menjadi sebuah simulasi yang berjalan.

Berdasarkan sumber-sumber yang ada, proses orkestrasi simulasi oleh Python mencakup beberapa tahapan dan fungsi krusial:

- #strong[Inisialisasi dan Persiapan Skenario:] Skrip Python bertindak sebagai pengelola utama yang memulai alur kerja dengan menginisialisasi sesi Prolog dan memuat berkas ontologi (misalnya file #NormalTok(". Pl");) ke dalam memori mesin. Pada tahap ini, Python juga bertugas mendefinisikan parameter-parameter skenario. Sebagai contoh, dalam studi kasus simulasi transportasi koridor Bandung-Jakarta 2030, Python digunakan untuk merumuskan beban skenario seperti rute sepanjang 150 km, tahun proyeksi 2030, dan permintaan jumlah penumpang sebesar 100 orang.

- #strong[Penggerak Simulasi Dinamis (Dynamic State Modification):] Sebuah simulasi yang sesungguhnya harus mampu merepresentasikan perubahan status seiring berjalannya waktu. Python mengorkestrasi dinamika ini dengan #strong[secara aktif menyuntikkan (meng-assert) fakta-fakta baru ke dalam basis pengetahuan Prolog saat simulasi sedang berjalan (runtime), serta menariknya kembali (retract) ketika status tersebut sudah tidak relevan]. Kemampuan manipulasi interaktif inilah yang memungkinkan status dari model Prolog untuk terus berevolusi merespons peristiwa dan data skenario tanpa harus memodifikasi kode dasar Prolog untuk setiap skenario yang berbeda.

- #strong[Berperan sebagai Mesin Kalkulasi (Calculation Engine):] Sebagai orkestrator, Python mendelegasikan pengambilan data logis ke Prolog, lalu menarik hasil kuerinya untuk diproses menggunakan komputasi algoritmik. Dalam simulasi transportasi, kelas-kelas pada Python mengambil data properti kendaraan dan energi secara langsung dari Prolog (melalui pustaka #emph[bridge] PySWIP). Setelah data logis didapatkan, algoritma Python menghitung secara matematis jumlah unit armada yang dibutuhkan, total estimasi biaya per penumpang, serta proyeksi emisi CO2 berdasarkan konsumsi energi dan jarak tempuh.

- #strong[Eksplorasi Skenario Lanjutan dan Optimasi:] Keunggulan algoritma Python memungkinkan orkestrasi skenario yang jauh lebih kompleks. Sumber menyarankan bahwa melalui Python, simulasi dapat diperluas untuk memasukkan #strong[pemodelan ketidakpastian (seperti simulasi] #strong[Monte Carlo), analisis sensitivitas, hingga algoritma optimasi (seperti algoritma genetik)] guna menemukan konfigurasi sistem transportasi yang paling ideal berdasarkan kriteria keberhasilan (energi PSKVE) yang diharapkan.

Secara keseluruhan, pemisahan arsitektur yang jelas---di mana representasi pengetahuan dan aturan logika diisolasi di Prolog, sementara logika simulasi, komputasi, dan kontrol alur diorkestrasi sepenuhnya oleh Python---menghasilkan #strong[peningkatan modularitas dan kemudahan pemeliharaan (maintainability) dari perangkat lunak rekayasa]. Pendekatan hibrida ini sangat ideal untuk memodelkan sistem #emph[Smart Engineering] yang kompleks karena menggabungkan kecerdasan komputasi matematis dengan kesadaran logis (#emph[knowledge-aware]).

= Bridge Libraries
<bridge-libraries>
Dalam kerangka Integrasi Teknologi untuk platform #emph[Smart Engineering], #strong[Pustaka Penghubung (Bridge Libraries) merupakan instrumen teknologi kunci (I(T)) yang beroperasi pada Domain Teknologi untuk menyatukan dua paradigma pemrograman yang bertolak belakang: penalaran simbolik di Prolog dan komputasi algoritmik di Python]. Pustaka ini secara khusus memfasilitasi komunikasi dan pertukaran data antar-bahasa, sekaligus mengabstraksi kerumitan pemanggilan fungsi lintas-proses tingkat rendah.

Peran, fungsionalitas, dan posisi #emph[bridge libraries] di dalam integrasi ini dijabarkan sebagai berikut:

#strong[\1. Manajemen Konversi Tipe Data yang Transparan (Data Marshalling)] Komunikasi yang efektif antara Python dan Prolog sangat bergantung pada kemampuan untuk mengonversi tipe data secara mulus.#emph[Bridge libraries] memikul tanggung jawab krusial ini dengan memetakan struktur data secara otomatis tanpa mengharuskan insinyur melakukan serialisasi data secara manual. Sebagai contoh, pustaka ini secara otomatis mengubah #emph[string], #emph[integer], #emph[float], dan #emph[list] dari Python menjadi bentuk #emph[atom], #emph[number], dan #emph[term] yang dipahami Prolog, lalu mengonversi kembali variabel hasil deduksi Prolog menjadi struktur seperti #emph[dictionary] di dalam Python.

#strong[\2. Menjembatani Orkestrasi Alur Kerja (Calling Conventions)] Pustaka ini menyediakan antarmuka teknis yang mengizinkan Python untuk sepenuhnya mengendalikan dan berinteraksi dengan mesin Prolog. Melalui pustaka ini, skrip Python dapat memulai sesi Prolog, memuat berkas ontologi (#NormalTok(". Pl");), secara dinamis menyuntikkan atau menarik fakta saat simulasi berjalan (seperti #NormalTok("assertz"); atau #NormalTok("retract");), serta mengirimkan rangkaian kueri logika untuk dievaluasi oleh mesin inferensi Prolog.

#strong[Wujud Nyata] #strong[Bridge Libraries] Sumber-sumber yang ada menyoroti beberapa pustaka penghubung yang paling menonjol:

- #strong[PySWIP:] Pustaka yang sangat populer untuk menghubungkan Python dengan SWI-Prolog dengan memanfaatkan pustaka fungsi eksternal #emph[ctypes] milik Python. PySWIP memberikan antarmuka bergaya #emph[Pythonic] yang memudahkan programer melakukan kueri dan mengelola hasil deduksi berupa #emph[list] dari #emph[dictionary].

- #strong[Janus:] Pustaka yang dirancang khusus untuk memberikan antarmuka komunikasi dua arah (#emph[bi-directional]) yang berkinerja sangat tinggi untuk SWI-Prolog, XSB, dan Ciao Prolog. Dibangun di atas API bahasa C tingkat rendah, Janus menawarkan latensi komunikasi hanya sekitar satu mikrodetik dan mendukung iterasi non-deterministik antar-bahasa.

- #strong[Langchain-Prolog & prologmqi:] Pustaka lanjutan di mana Langchain-Prolog mengintegrasikan penalaran logis SWI-Prolog ke dalam aplikasi Kecerdasan Buatan Generatif (LLM), sementara #emph[prologmqi] memfasilitasi komunikasi berbasis antrean pesan (#emph[message queue]) dengan pertukaran data format JSON.

#strong[Dampak Sistemik (Outcome] #strong[\/ O(T))] Kehadiran pustaka jembatan ini secara signifikan menurunkan hambatan teknis bagi insinyur untuk memadukan kecerdasan logis ke dalam aplikasi perangkat lunak mereka. Pustaka ini memastikan aliran komunikasi yang sangat efisien dan meminimalkan beban komputasi (#emph[overhead]) saat menerjemahkan struktur data antar-bahasa. Pada akhirnya, inovasi yang terjadi di lapisan Domain Teknologi inilah yang menjadi fondasi penentu sehingga platform sistem integrasi multi-domain---yang menyatukan kehebatan komputasi numerik Python dengan pemahaman basis pengetahuan Prolog---dapat benar-benar diwujudkan.

== PySWIP
<pyswip>
Dalam kerangka Integrasi Teknologi, Pustaka Penghubung (#emph[Bridge Libraries]) berperan sebagai instrumen teknologi kunci di Domain Teknologi (I(T)) yang bertugas menyatukan komputasi algoritmik Python dengan penalaran simbolik Prolog. Di antara berbagai opsi pustaka yang ada, #strong[PySWIP] merupakan salah satu pustaka penghubung yang paling populer dan secara luas diandalkan.

Berikut adalah penjabaran mengenai posisi dan kemampuan PySWIP di dalam ekosistem integrasi teknologi ini:

#strong[\1. Menjembatani Python secara Khusus dengan SWI-Prolog] PySWIP dirancang secara spesifik untuk menghubungkan aplikasi Python dengan #strong[SWI-Prolog], yakni salah satu implementasi Prolog sumber terbuka (#emph[open-source]) yang paling tangguh dan banyak digunakan. Secara teknis, PySWIP beroperasi dengan cara menjadikan SWI-Prolog sebagai pustaka bersama (#emph[shared library]). Python kemudian mengakses pustaka tersebut dengan memanfaatkan modul eksternalnya, yaitu #NormalTok("ctypes"); (#emph[foreign function library]).

#strong[\2. Menyediakan Antarmuka Bergaya] #strong[Pythonic] Fungsi utama dari PySWIP adalah menyembunyikan kerumitan komunikasi antar-proses (#emph[inter-process communication]) dan memberikan antarmuka bergaya #emph[Pythonic] kepada pengembang. Dengan menggunakan PySWIP, skrip Python dapat secara mandiri mengontrol mesin Prolog melalui perintah-perintah langsung, seperti:

- #strong[Inisialisasi:] Membuat instansiasi mesin Prolog dari dalam Python (misalnya #NormalTok("prolog = Prolog()");).

- #strong[Pemuatan Berkas:] Memuat berkas ontologi atau basis pengetahuan berekstensi #NormalTok(". Pl"); ke dalam memori mesin logika menggunakan perintah seperti #NormalTok("prolog. Consult()");.

#strong[\3. Pertukaran Data yang Transparan (Data Marshalling)] Sebagai #emph[bridge library], PySWIP memegang peranan vital dalam mengatur pertukaran tipe data. Saat Python mengirimkan kueri dan Prolog berhasil menemukan solusinya, PySWIP secara otomatis mengonversi variabel-variabel temuan Prolog tersebut menjadi #strong[sebuah struktur] #strong[list] #strong[\(daftar) yang berisi] #strong[dictionary] #strong[\(kamus) di dalam lingkungan Python]. Pada struktur #emph[dictionary] ini, kuncinya (#emph[keys]) merepresentasikan nama variabel dalam kueri Prolog, sementara nilainya (#emph[values]) berisi temuan logis yang saling terikat. Konversi data yang transparan ini sangat krusial karena ia memungkinkan algoritma numerik Python langsung memproses hasil deduksi logika tersebut.

#strong[\4. Penggerak Simulasi Rekayasa yang Dinamis] Dalam konteks pengembangan aplikasi atau simulasi rekayasa yang dinamis (#emph[Smart Engineering]), PySWIP adalah alat yang memungkinkan Python bertindak sebagai orkestrator yang mengubah status "dunia" di dalam Prolog secara #emph[real-time] :

- #strong[Penyuntikan dan Penarikan Fakta:] Melalui fungsi seperti #NormalTok("prolog. Assertz()");, Python dapat menyuntikkan data baru ke dalam Prolog untuk merepresentasikan kejadian atau status baru. Setelah evaluasi selesai, Python juga dapat mencabut fakta tersebut menggunakan #NormalTok("prolog. Retract()"); agar basis pengetahuan kembali bersih.

- #strong[Simulasi Multi-Domain:] Dalam studi kasus simulasi moda transportasi koridor Bandung-Jakarta 2030, kelas-kelas kalkulasi di dalam Python memanfaatkan antarmuka PySWIP untuk mengkueri properti kendaraan yang tersimpan di ontologi Prolog (misalnya atribut #NormalTok("vehicleproperty(...)");). Data ontologis yang telah diikat ini kemudian digunakan oleh Python untuk menghitung kebutuhan biaya transportasi dan emisi gas buang secara matematis.

Singkatnya, #strong[PySWIP adalah instrumen teknologi inti yang mewujudkan arsitektur integrasi multi-paradigma]. Ia menjadi jembatan eksekusi yang memungkinkan insinyur membangun aplikasi Python yang sangat fleksibel, interaktif, dan komputasional, yang ditenagai oleh "otak" pemahaman deduktif tingkat tinggi dari mesin SWI-Prolog di latar belakang.

== Janus (SWI-Prolog)
<janus-swi-prolog>
Dalam kerangka Integrasi Teknologi, Pustaka Penghubung (#emph[Bridge Libraries]) berfungsi sebagai instrumen teknologi vital yang mengabstraksi kerumitan pemanggilan fungsi lintas-bahasa untuk menyatukan komputasi algoritmik Python dengan penalaran simbolik Prolog. Di dalam ekosistem pustaka penghubung ini, #strong[Janus menonjol sebagai antarmuka komunikasi tingkat lanjut yang dirancang secara khusus untuk memfasilitasi interaksi dua arah (bi-directional) dengan kinerja yang sangat tinggi].

Berikut adalah karakteristik dan peran spesifik Janus di dalam konteks pustaka penghubung:

- #strong[Komunikasi Dua Arah Berkecepatan Tinggi:] Janus dibangun langsung di atas antarmuka pemrograman aplikasi (API) tingkat rendah dari bahasa C untuk kedua lingkungan pemrograman. Pendekatan arsitektur ini menghasilkan jalur komunikasi yang sangat efisien, dengan #strong[latensi yang dilaporkan mencapai sekitar satu mikrodetik].

- #strong[Dukungan Multi-Implementasi:] Tidak hanya dirancang untuk SWI-Prolog, antarmuka Janus juga memperluas kompatibilitasnya untuk dapat diintegrasikan dengan implementasi Prolog yang tangguh lainnya, seperti XSB Prolog dan Ciao Prolog.

- #strong[Fungsionalitas Pemanggilan Timbal Balik:] Janus memberikan fleksibilitas penuh di mana kedua bahasa dapat saling mengendalikan satu sama lain:

- #strong[Dari Python ke Prolog:] Python dapat menggunakan fungsi seperti #NormalTok("janus. Query_once()"); dan #NormalTok("janus. Apply_once()"); untuk mengeksekusi kueri deterministik (solusi tunggal). Untuk predikat non-deterministik yang dapat menghasilkan banyak solusi, Janus menyediakan antarmuka iterator seperti #NormalTok("janus. Query()"); dan #NormalTok("janus. Apply()");.

- #strong[Dari Prolog ke Python:] Sebaliknya, Prolog dapat menggunakan predikat seperti #NormalTok("py_call/2"); untuk memanggil dan mengeksekusi fungsi Python secara langsung, serta menggunakan #NormalTok("py_iter/2"); untuk menelusuri data dari iterator Python.

- #strong[Manajemen Konversi Data (Data Marshalling) yang Sangat Rinci:] Keberhasilan integrasi sistem sangat bergantung pada kemulusan konversi tipe data. Janus menyembunyikan kerumitan serialisasi dengan menyediakan peta terjemahan tipe data transparan yang komprehensif :

  - Nilai numerik (#emph[integer] dan #emph[float]) di Prolog secara langsung menjadi tipe data #NormalTok("int"); (termasuk #emph[big integers]) dan #NormalTok("float"); di Python.- #emph[Atom] Prolog dapat dikonversi secara fleksibel menjadi #emph[string] standar atau instansiasi #emph[class] #NormalTok("enum. Enum"); di Python.- Struktur #emph[list] dan #emph[dict] (khusus di SWI-Prolog) diubah secara otomatis menjadi struktur #emph[list] dan #emph[dictionary] milik Python.- Janus menangani atom khusus di Prolog seperti #NormalTok("@(true)");, #NormalTok("@(false)");, dan #NormalTok("@(none)"); dan memetakannya secara persis menjadi objek boolean #NormalTok("True");, #NormalTok("False");, dan #NormalTok("None"); di Python.

- #strong[Fondasi bagi Aplikasi Kecerdasan Buatan (LLM):] Keandalan Janus menjadikannya sebagai fondasi teknologi bagi pengembangan pustaka tingkat tinggi seperti #strong[Langchain-Prolog]. Pustaka lanjutan ini memanfaatkan Janus untuk mengintegrasikan mesin penalaran SWI-Prolog ke dalam LangChain, sebuah kerangka kerja untuk membangun aplikasi berbasis Kecerdasan Buatan Generatif (#emph[Large Language Models]). Hal ini memungkinkan mesin AI untuk memadukan penalaran logis terstruktur dengan kapabilitas bahasa generatif.

Secara keseluruhan, kehadiran Janus meningkatkan standar #emph[bridge libraries] di dalam praktik #emph[Smart Engineering]. Dengan mengotomatisasi konversi tipe data yang rumit dan menyediakan latensi komunikasi yang sangat rendah, #strong[Janus memastikan bahwa penalaran logika Prolog dan algoritma prosedural Python benar-benar terintegrasi sebagai sebuah mesin komputasi tunggal yang kohesif].

== PrologMQI
<prologmqi>
Dalam kerangka Integrasi Teknologi, #strong[prologmqi] beroperasi di tingkat Domain Teknologi (I(T)) sebagai salah satu alternatif Pustaka Penghubung (#emph[Bridge Libraries]) untuk mengintegrasikan mesin komputasi Python dengan mesin penalaran SWI-Prolog.

Meskipun memiliki tujuan yang sama dengan pustaka penghubung lain seperti PySWIP atau Janus, prologmqi menawarkan pendekatan arsitektur yang sangat berbeda di dalam ekosistem integrasi ini:

#strong[\1. Pendekatan Berbasis Antrean Pesan (Message Queue)] Alih-alih menghubungkan Python dan Prolog pada tingkat memori yang sama (seperti menggunakan API bahasa C pada Janus), prologmqi memanfaatkan antarmuka kueri mesin (#emph[machine query interface]) dengan pendekatan #strong[antrean pesan (message queue)]. Dalam mekanisme ini, aplikasi Python mengeksekusi kueri SWI-Prolog dengan cara mengirimkan instruksi tersebut dalam bentuk #emph[string] murni.

#strong[\2. Pertukaran Data Menggunakan JSON] Untuk menangani tantangan konversi tipe data lintas bahasa (#emph[data marshalling]), prologmqi tidak melakukan pemetaan objek secara langsung di memori, melainkan #strong[mengembalikan respons atau hasil deduksi dari Prolog dalam format JSON]. Penggunaan JSON ini mengabstraksi kerumitan penerjemahan data karena JSON merupakan standar pertukaran data yang sangat umum dan mudah diproses ulang oleh algoritma Python.

#strong[\3. Keunggulan untuk Sistem Terdistribusi] Di dalam konteks yang lebih luas mengenai bagaimana para insinyur merancang arsitektur sistem (#emph[Smart Engineering]), pemilihan pustaka penghubung bergantung pada kebutuhan desain. Sementara pustaka seperti Janus dioptimalkan untuk komunikasi internal dua arah dengan latensi sangat rendah, karakteristik prologmqi (berbasis pesan dan JSON) #strong[menjadikannya sangat cocok dan ideal untuk membangun arsitektur sistem yang terdistribusi (distributed architectures) atau sistem yang digabungkan secara longgar (loosely coupled architectures)].

Dengan kata lain, prologmqi memungkinkan pengembang untuk menjalankan mesin logika Prolog dan mesin aplikasi Python pada server, wadah (#emph[container]), atau proses yang sepenuhnya terpisah, di mana keduanya saling berkomunikasi secara asinkron sebagai layanan yang independen.

#heading(level: 1, numbering: none)[Bagian 4: Studi Kasus]
<bagian-4-studi-kasus>
= Studi Kasus: Transportasi 2030
<studi-kasus-transportasi-2030>
Studi Kasus Transportasi koridor Bandung-Jakarta 2030 adalah sebuah simulasi praktis yang dirancang secara khusus untuk mendemonstrasikan kegunaan kerangka kerja ontologis #emph[Smart Engineering] dalam menyelesaikan masalah rekayasa multi-domain yang kompleks.

Dalam konteks yang lebih luas dari #emph[Smart Engineering], studi kasus ini menyoroti beberapa penerapan prinsip fundamental:

#strong[\1. Implementasi Nyata Integrasi Prolog-Python] Simulasi ini menjadi bukti nyata dari penerapan arsitektur sistem (Domain Sistem) yang memadukan komputasi algoritmik dan penalaran simbolis.

- #strong[Prolog sebagai Basis Pengetahuan:] Model ontologi terkait konsep komponen tahun 2030---seperti spesifikasi #emph[Electric Sedan], bus #emph[biodiesel], kereta cepat, kapasitas penumpang, biaya jaringan listrik, hingga intensitas CO2---didefinisikan secara deklaratif di dalam basis pengetahuan Prolog.

- #strong[Python sebagai Orkestrator dan Mesin Kalkulasi:] Python bertugas menjalankan logika skenario (misalnya target membawa 100 penumpang). Melalui pustaka penghubung seperti #NormalTok("pyswip");, #emph[class] di Python menarik data properti kendaraan dari Prolog, lalu menggunakan algoritma matematisnya untuk menghitung jumlah armada yang dibutuhkan, mengalkulasi biaya total operasional, dan menghitung emisi secara keseluruhan. Pemisahan yang jelas antara representasi pengetahuan (Prolog) dan logika simulasi (Python) ini terbukti sangat berharga untuk meningkatkan modularitas dan kemudahan pemeliharaan sistem perangkat lunak.

#strong[\2. Pergeseran Metrik Evaluasi menuju Dimensi Energi PSKVE] Alih-alih sekadar membandingkan spesifikasi teknis mesin fisik, #emph[Smart Engineering] memandang solusi rekayasa dari lensa multi-dimensi PSKVE (Produk, Layanan, Pengetahuan, Nilai, Lingkungan). Kinerja ketiga alternatif solusi transportasi dalam studi kasus ini dievaluasi melalui matriks energi tersebut:

- #strong[Energi Layanan (Service Energy):] Direpresentasikan secara objektif melalui efisiensi waktu atau estimasi waktu tempuh perjalanan, di mana Kereta Cepat menunjukkan performa Energi Layanan terbaik.

- #strong[Energi Nilai (Value Energy):] Diukur melalui total biaya yang harus dikeluarkan per penumpang. Parameter algoritmik di Python mengakumulasikan biaya ini berdasarkan harga energi, tarif tol, nilai tiket, hingga pro-rata biaya pemeliharaan mesin.

- #strong[Energi Ruang Lingkungan (Environmental Space Energy):] Mewakili jejak ekologis dari teknologi tersebut, yang dalam simulasi ini dikalkulasi sebagai jumlah gram emisi CO2 ekuivalen per penumpang.

#strong[\3. Mengilustrasikan Prinsip Konversi Transaksional] Studi kasus ini juga memperlihatkan cara kerja Konversi Transaksional (#emph[Transactional Conversion]) di dunia nyata. Sistem transportasi ini memodelkan bagaimana pemangku kepentingan (penumpang) melakukan transaksi energi dimensi silang: #strong[mereka menukarkan Energi Nilai yang mereka miliki (berupa uang/biaya tiket) untuk mendapatkan Energi Layanan (akses transportasi yang efisien) serta memanfaatkan konversi Energi Produk (pengoperasian mekanis kendaraan)].

#strong[\4. Menggambarkan Interaksi Multi-Domain yang Rumit] Dengan mengevaluasi kendaraan yang berbeda (armada mobil listrik pribadi, bus diesel, dan kereta cepat), simulasi ini mendemonstrasikan kompleksitas interaksi dari berbagai "wares" (perangkat keras kendaraan, perangkat lunak sistem otonom, hingga infrastruktur jaringan energi). Sebagai contoh, simulasi ini membuktikan bahwa #strong[Energi Pengetahuan (Knowledge Energy)] yang disematkan dalam teknologi baterai #emph[Electric Vehicle] (EV) atau manajemen jaringan listrik cerdas akan secara langsung mendikte seberapa efisien konsumsi #strong[Energi Produk] kendaraan tersebut, dan pada akhirnya menentukan besaran #strong[Energi Ruang Lingkungan] (emisi) yang dihasilkannya.

Secara keseluruhan, simulasi rute Bandung-Jakarta 2030 ini bukan sekadar studi kasus transportasi biasa, melainkan cetak biru (#emph[blueprint]) tentang bagaimana kerangka kerja #emph[Smart Engineering] memberdayakan para insinyur untuk merancang, membandingkan, dan mengoptimalkan sistem masa depan secara holistik dengan memadukan basis pengetahuan kecerdasan buatan, perhitungan matematis algoritmik, dan valuasi multi-dimensi PSKVE.

== Skenario Bandung-Jakarta
<skenario-bandung-jakarta>
Dalam kerangka Studi Kasus Transportasi 2030, #strong[Skenario Bandung-Jakarta] merupakan sebuah model simulasi praktis yang dirancang untuk mendemonstrasikan bagaimana kerangka kerja ontologis #emph[Smart Engineering] dapat diimplementasikan untuk mengevaluasi alternatif solusi sistem rekayasa multi-domain.

Berikut adalah rincian dari Skenario Bandung-Jakarta dan signifikansinya di dalam konteks studi kasus yang lebih luas:

#strong[\1. Batasan dan Parameter Skenario] Untuk menjalankan simulasi yang terukur, skenario ini menetapkan tiga parameter operasional utama:

- #strong[Rute Perjalanan:] Koridor dari Bandung menuju Jakarta dengan estimasi jarak tempuh 150 km.

- #strong[Tahun Proyeksi:] Kondisi teknologi, harga energi, dan infrastruktur disimulasikan untuk tahun 2030.

- #strong[Beban Permintaan (Passenger Demand):] Skenario ini menargetkan pengangkutan sebuah kelompok yang terdiri dari #strong[100 orang penumpang] secara bersamaan.

#strong[\2. Alternatif Transportasi yang Dievaluasi] Skenario ini membandingkan tiga jenis teknologi kendaraan massal dan pribadi (yang datanya tersimpan di dalam basis pengetahuan Prolog) untuk memenuhi permintaan 100 penumpang tersebut:

- #strong[Armada Sedan Listrik (Electric Sedan):] Memiliki kapasitas 4 penumpang per unit, sehingga skenario ini membutuhkan kalkulasi pengoperasian 25 unit mobil listrik.

- #strong[Armada Bus Diesel Euro 6 (Biodiesel):] Memiliki kapasitas 40 penumpang per unit, sehingga skenario ini membutuhkan pengoperasian 3 unit bus.

- #strong[Kereta Cepat Listrik (High-Speed Train):] Memiliki kapasitas masif sebesar 500 penumpang per rangkaian, sehingga cukup menggunakan satu layanan untuk mengangkut seluruh kelompok.

#strong[\3. Evaluasi Berdasarkan Metrik Energi PSKVE] Alih-alih membandingkan spesifikasi mesin secara mentah, skenario Bandung-Jakarta mengevaluasi kinerja ketiga solusi tersebut menggunakan lensa multi-dimensi Energi PSKVE:

- #strong[Energi Layanan (Service Energy):] Direpresentasikan melalui estimasi waktu tempuh. Kereta Cepat menawarkan efisiensi energi layanan terbaik (sekitar 1 hingga 1,5 jam) dibandingkan opsi jalan raya.

- #strong[Energi Nilai (Value Energy):] Direpresentasikan melalui total biaya operasional per penumpang. Dalam simulasi algoritma Python, biaya ini diakumulasikan dari harga energi/bahan bakar, tarif tol, hingga prorata biaya pemeliharaan. Hasil ilustratif menunjukkan Bus Diesel memiliki potensi biaya per penumpang termurah, diikuti oleh armada Sedan EV, sedangkan Kereta Cepat memiliki biaya langsung tertinggi melalui harga tiket.

- #strong[Energi Ruang Lingkungan (Environmental Space Energy):] Direpresentasikan dari total emisi ekuivalen CO2 per penumpang. Kereta Cepat menghasilkan jejak karbon terendah, sementara emisi Sedan EV sangat bergantung pada intensitas karbon jaringan listrik PLN di tahun 2030, dan Bus Diesel mencatatkan hasil polusi tertinggi.

#strong[\4. Signifikansi dalam Konteks] #strong[Smart Engineering] Skenario Bandung-Jakarta ini berfungsi sebagai pembuktian konsep (#emph[proof of concept]) dari dua prinsip utama #emph[Smart Engineering]:

- #strong[Pembuktian Integrasi Python-Prolog:] Simulasi ini memvalidasi kegunaan pemisahan arsitektur sistem. Data sifat kendaraan (seperti kapasitas dan konsumsi energi) diisolasi secara rapi di dalam pangkalan pengetahuan Prolog, sementara skrip Python secara dinamis menarik data tersebut untuk mengeksekusi kalkulasi matematis (seperti menghitung jumlah armada yang dibutuhkan untuk 100 penumpang dan total biaya gabungan).

- #strong[Pembuktian Konversi Transaksional:] Skenario ini mengilustrasikan secara konkret bagaimana pengguna (penumpang) melakukan pertukaran energi lintas-dimensi di dunia nyata: mereka menukarkan Energi Nilai (uang/biaya) untuk mendapatkan Energi Layanan (waktu perjalanan yang efisien) dengan mempekerjakan Energi Produk mekanis kendaraan.

== Evaluasi Fleet EV vs Bus vs Kereta Cepat
<evaluasi-fleet-ev-vs-bus-vs-kereta-cepat>
Dalam kerangka Studi Kasus Transportasi 2030, evaluasi antara #strong[Armada Sedan EV (Electric Vehicle)], #strong[Armada Bus Diesel], dan #strong[Kereta Cepat] merupakan model simulasi yang krusial untuk mendemonstrasikan bagaimana kerangka kerja ontologis #emph[Smart Engineering] membandingkan berbagai alternatif solusi secara holistik. Skenario ini membandingkan ketiga moda tersebut untuk memenuhi permintaan pengangkutan 100 orang penumpang di koridor rute Bandung-Jakarta (150 km).

Berikut adalah perbandingan dan evaluasi komprehensif dari ketiga solusi transportasi tersebut menggunakan lensa dimensi energi PSKVE (Produk, Layanan, Pengetahuan, Nilai, Lingkungan):

#strong[\1. Konfigurasi Kebutuhan Armada (Domain Sistem)] Untuk mengangkut kelompok berisi 100 penumpang, algoritma komputasi Python menarik data properti fisik kendaraan dari ontologi Prolog dan menghitung kebutuhan kapasitas masing-masing solusi:

- #strong[Armada Sedan EV:] Karena setiap mobil berkapasitas 4 orang, skenario ini harus menyimulasikan operasi #strong[25 unit mobil listrik] secara bersamaan.

- #strong[Armada Bus Diesel:] Memiliki kapasitas 40 orang per unit, sehingga skenario ini cukup mengevaluasi #strong[3 unit bus] (yang diasumsikan menggunakan bahan bakar biodiesel B30).

- #strong[Kereta Cepat Elektrik:] Memiliki kapasitas masif sebesar 500 penumpang per rangkaian, sehingga pengoperasian #strong[1 layanan rangkaian] sudah lebih dari cukup untuk memenuhi permintaan target.

#strong[\2. Evaluasi Energi Layanan (Service Energy)] Metrik ini mengukur kinerja layanan berdasarkan efisiensi waktu tempuh perjalanan. Dalam dimensi ini, #strong[Kereta Cepat menawarkan performa yang paling superior], dengan estimasi waktu tempuh hanya 1,0 hingga 1,5 jam. Sebaliknya, alternatif yang menggunakan infrastruktur jalan raya jauh lebih lambat; Armada Sedan EV membutuhkan waktu sekitar 2,5 hingga 3,5 jam, dan Armada Bus Diesel menjadi opsi paling lambat dengan estimasi 3,0 hingga 4,0 jam perjalanan.

#strong[\3. Evaluasi Energi Nilai (Value Energy)] Metrik ini mengevaluasi pengorbanan finansial melalui akumulasi total biaya per penumpang. Pada simulasi armada berbasis jalan raya, biaya ini dikalkulasi dengan menjumlahkan tarif energi/bahan bakar, tarif tol, serta pembagian prorata biaya pemeliharaan tahunan.

- #strong[Armada Bus Diesel terbukti sebagai solusi paling ekonomis secara biaya operasional langsung], yang diestimasikan sekitar Rp76.381 per penumpang.

- #strong[Armada Sedan EV] menyusul di posisi kedua dengan beban biaya operasional sekitar Rp107.750 per penumpang.

- #strong[Kereta Cepat] merupakan opsi transportasi paling mahal bagi pengguna langsung, yang direpresentasikan oleh harga pembelian tiket sebesar Rp150.000 per penumpang. Meski angka tersebut tampak definitif, sumber mencatat bahwa evaluasi Energi Nilai akan jauh lebih komprehensif jika simulasi ini turut memperhitungkan biaya siklus hidup (#emph[lifecycle cost]), termasuk pengeluaran modal infrastruktur secara penuh.

#strong[\4. Evaluasi Energi Ruang Lingkungan (Environmental Space Energy)] Evaluasi jejak karbon diukur dari besaran emisi ekuivalen CO2 yang dihasilkan untuk memindahkan satu orang penumpang.

- #strong[Kereta Cepat merupakan solusi yang paling ramah lingkungan], menghasilkan emisi terendah (sekitar 840 gram CO2eq per penumpang) dengan asumsi suplai dari jaringan listrik yang lebih bersih di tahun 2030.

- #strong[Armada Sedan EV] berada di posisi kedua (sekitar 1.575 gram CO2eq per penumpang). Evaluasi menekankan bahwa seberapa bersih performa lingkungan mobil listrik sangat bergantung pada intensitas karbon dari jaringan listrik utama (PLN) yang menyuplainya. Hal ini mencontohkan bagaimana Energi Pengetahuan (misalnya, kecerdasan dalam sistem #emph[smart grid]) sangat mendikte dampak pencemaran dari sistem tersebut.

- #strong[Armada Bus Diesel] mencatatkan dampak lingkungan terburuk dengan emisi tertinggi (sekitar 3.234 gram CO2eq per penumpang), sekalipun sudah dihipotesiskan menggunakan bahan bakar biofuel.

#strong[Signifikansi Evaluasi Komparatif] Evaluasi antara EV, Bus, dan Kereta Cepat ini secara nyata memvalidasi prinsip #strong[Konversi Transaksional]. Simulasi ini mengilustrasikan sebuah ekosistem #emph[Smart Engineering] di mana penumpang menukarkan Energi Nilai (berupa uang tiket atau biaya tol) untuk mendapatkan Energi Layanan (efisiensi waktu yang tinggi pada kereta cepat, atau akses pada bus murah) dengan mempekerjakan Energi Produk dari operasi mekanis ketiga kendaraan tersebut. Pada akhirnya, simulasi ini membuktikan kemampuan arsitektur hibrida untuk membantu insinyur menimbang ragam kompromi (#emph[trade-offs]) sistem multi-domain secara objektif dan matematis.

== Metrik: Waktu, Biaya, Emisi CO2
<metrik-waktu-biaya-emisi-co2>
Dalam Studi Kasus Transportasi koridor Bandung-Jakarta 2030, metrik #strong[Waktu, Biaya, dan Emisi CO2] tidak sekadar dipandang sebagai ukuran teknis tradisional, melainkan digunakan sebagai wujud kuantitatif dari dimensi #strong[Energi PSKVE (Produk, Layanan, Pengetahuan, Nilai, Lingkungan)] di dalam kerangka #emph[Smart Engineering].

Algoritma komputasi Python secara dinamis mengekstraksi data spesifikasi kendaraan dari ontologi Prolog, lalu menghitung ketiga metrik tersebut untuk mengevaluasi skenario pemenuhan target 100 penumpang melintasi jarak 150 km. Berikut adalah penjabaran ketiga metrik tersebut dalam simulasi ini:

#strong[\1. Metrik Waktu Tempuh: Representasi Energi Layanan (Service Energy)] Waktu tempuh dievaluasi untuk mengukur efisiensi layanan dari sebuah sistem transportasi.

- #strong[Kereta Cepat Elektrik] menawarkan efisiensi Energi Layanan yang paling superior dengan perkiraan waktu tempuh hanya 1,0 hingga 1,5 jam.- Opsi berbasis infrastruktur jalan raya jauh lebih lambat, di mana #strong[Armada Sedan EV] membutuhkan waktu 2,5 hingga 3,5 jam, dan #strong[Armada Bus Diesel] merupakan opsi paling lambat dengan waktu 3,0 hingga 4,0 jam.

#strong[\2. Metrik Biaya: Representasi Energi Nilai (Value Energy)] Metrik biaya mengukur total pengorbanan finansial per penumpang. Untuk armada jalan raya, kalkulator algoritma Python menyimulasikan biaya ini dengan menjumlahkan tarif energi/bahan bakar, tarif tol jalan, serta pembagian secara prorata untuk biaya pemeliharaan kendaraan per tahun. Sementara untuk kereta cepat, harga tiket digunakan sebagai indikator langsung.

- #strong[Armada Bus Diesel] menjadi solusi dengan Energi Nilai paling ekonomis secara langsung, yakni sekitar Rp76.381 per penumpang.

- #strong[Armada Sedan EV] menyusul dengan estimasi beban sekitar Rp107.750 per penumpang.

- #strong[Kereta Cepat] merupakan moda yang menuntut pengeluaran biaya langsung tertinggi sebesar Rp150.000 per penumpang. Sumber mencatat bahwa untuk mendapatkan gambaran Energi Nilai yang lebih utuh, perhitungan metrik biaya di masa depan idealnya turut menyertakan evaluasi biaya siklus hidup (#emph[lifecycle cost]) secara penuh, termasuk biaya modal pembangunan infrastruktur transportasi tersebut.

#strong[\3. Metrik Emisi CO2: Representasi Energi Ruang Lingkungan (Environmental Space Energy)] Metrik ini mengukur jejak karbon dalam wujud gram ekuivalen CO2 per penumpang untuk merepresentasikan dampak ekologis sistem transportasi.

- #strong[Kereta Cepat] kembali unggul dengan emisi terendah (sekitar 840 gram CO2eq per penumpang), diasumsikan didukung oleh jaringan listrik yang lebih bersih.

- #strong[Armada Sedan EV] menghasilkan sekitar 1.575 gram CO2eq per penumpang. Metrik emisi untuk kendaraan listrik ini sangat fluktuatif dan bergantung langsung pada tingkat kebersihan (intensitas karbon) dari jaringan listrik utama (PLN) di tahun 2030.

- #strong[Armada Bus Diesel] mencatatkan dampak lingkungan terburuk dengan memproduksi emisi tertinggi (sekitar 3.234 gram CO2eq per penumpang) meskipun telah menggunakan alternatif biofuel.

#strong[Signifikansi dalam Kerangka] #strong[Smart Engineering] Perhitungan ketiga metrik ini digunakan untuk memvalidasi prinsip #strong[Konversi Transaksional (Transactional Conversion)]. Melalui komparasi simulasi ini, sistem #emph[Smart Engineering] mengilustrasikan bagaimana seorang pengguna (penumpang) melakukan transaksi energi dimensi silang di dunia nyata: #strong[mereka menukarkan Energi Nilai (biaya operasional atau tiket) untuk mendapatkan Energi Layanan (efisiensi waktu tempuh) dengan mempekerjakan Energi Produk mekanis kendaraan, yang keseluruhannya meninggalkan jejak Energi Ruang Lingkungan (emisi CO2)].

Pada akhirnya, pendelegasian ontologi data ke Prolog dan eksekusi komputasi metrik oleh Python membuktikan bahwa arsitektur multi-domain ini mampu membantu insinyur menimbang berbagai kompromi (#emph[trade-offs]) sistem rekayasa secara objektif.

#bibliography(("references.bib"))

// IN AFTER !!!
