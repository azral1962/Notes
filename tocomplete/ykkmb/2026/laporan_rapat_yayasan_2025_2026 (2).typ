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
#import "@preview/fontawesome:0.5.0": *
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
  title: [Laporan Keuangan 2025 dan Draft Budget 2026],
  subtitle: [Bahan Rapat Yayasan],
  authors: (
    ( name: [Pengurus YKKMB],
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
Dokumen ini disusun sebagai bahan pembahasan rapat yayasan mengenai kinerja keuangan tahun 2025 dan draft budget tahun 2026. Fokus utama laporan ini adalah memberikan gambaran ringkas namun cukup lengkap mengenai posisi kas, hasil operasional, posisi keuangan pada akhir tahun, serta implikasinya terhadap rencana anggaran tahun berikutnya.

= Ringkasan eksekutif
<ringkasan-eksekutif>
Secara umum, kondisi keuangan yayasan pada tahun 2025 menunjukkan hasil yang #strong[positif dan sehat]. Selama tahun 2025, yayasan mencatat total penerimaan sebesar #strong[Rp187.750.000] dan total pengeluaran sebesar #strong[Rp95.809.100], sehingga menghasilkan surplus tahun berjalan sebesar #strong[Rp91.940.900].

Saldo kas/bank pada awal tahun sebesar #strong[Rp328.860.000] meningkat menjadi #strong[Rp420.800.900] pada akhir tahun 2025. Dengan demikian, terjadi kenaikan saldo kas sebesar #strong[Rp91.940.900] selama satu tahun buku.

#block[
#callout(
body: 
[
- Penerimaan yayasan tahun 2025 masih sangat ditopang oleh #strong[pendapatan sewa].
- Hasil operasional 2025 memberikan #strong[surplus yang kuat], sehingga likuiditas yayasan pada akhir tahun berada pada posisi baik.
- Draft budget 2026 disusun secara konservatif dengan asumsi:
  - pertumbuhan pendapatan #strong[3%]
  - pertumbuhan beban #strong[5%]
  - cadangan/contingency #strong[2% atas beban]
- Dengan demikian, #strong[kenaikan beban efektif dalam draft 2026 adalah 7%] dari realisasi 2025.

]
, 
title: 
[
Pokok-pokok yang perlu dicermati dalam rapat
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
= Ringkasan angka utama
<ringkasan-angka-utama>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Uraian], [Nilai],),
  table.hline(),
  [Saldo Awal 2025], [Rp328.860.000],
  [Total Penerimaan 2025], [Rp187.750.000],
  [Total Pengeluaran 2025], [Rp95.809.100],
  [Surplus Arus Kas / Surplus Tahun Berjalan], [Rp91.940.900],
  [Saldo Akhir 2025], [Rp420.800.900],
  [Draft Total Pendapatan 2026], [Rp193.382.500],
  [Draft Total Beban 2026], [Rp102.515.737],
  [Draft Surplus 2026], [Rp90.866.763],
)
= Laporan arus kas 2025
<laporan-arus-kas-2025>
Laporan arus kas menunjukkan bahwa yayasan menghasilkan arus kas bersih positif sebesar #strong[Rp91.940.900] sepanjang tahun 2025. Walaupun terdapat beberapa bulan dengan arus kas negatif, secara agregat kondisi kas tetap kuat dan mampu menutup seluruh kebutuhan operasional.

== Tabel arus kas bulanan 2025
<tabel-arus-kas-bulanan-2025>
#table(
  columns: (16.67%, 16.67%, 16.67%, 16.67%, 16.67%, 16.67%),
  align: (auto,auto,auto,auto,auto,auto,),
  table.header([Bulan], [Saldo Awal], [Penerimaan], [Pengeluaran], [Arus Kas Bersih], [Saldo Akhir],),
  table.hline(),
  [Jan], [Rp328.860.000], [Rp20.200.000], [Rp7.637.000], [Rp12.563.000], [Rp341.423.000],
  [Feb], [Rp341.423.000], [Rp11.150.000], [Rp11.439.400], [Rp-289.400], [Rp341.133.600],
  [Mar], [Rp341.133.600], [Rp21.900.000], [Rp16.933.900], [Rp4.966.100], [Rp346.099.700],
  [Apr], [Rp346.099.700], [Rp17.700.000], [Rp13.744.900], [Rp3.955.100], [Rp350.054.800],
  [Mei], [Rp350.054.800], [Rp8.700.000], [Rp7.760.800], [Rp939.200], [Rp350.994.000],
  [Jun], [Rp350.994.000], [Rp16.400.000], [Rp6.908.250], [Rp9.491.750], [Rp360.485.750],
  [Jul], [Rp360.485.750], [Rp14.500.000], [Rp4.591.900], [Rp9.908.100], [Rp370.393.850],
  [Agu], [Rp370.393.850], [Rp5.150.000], [Rp5.221.400], [Rp-71.400], [Rp370.322.450],
  [Sep], [Rp370.322.450], [Rp15.400.000], [Rp5.976.400], [Rp9.423.600], [Rp379.746.050],
  [Okt], [Rp379.746.050], [Rp41.500.000], [Rp4.419.000], [Rp37.081.000], [Rp416.827.050],
  [Nov], [Rp416.827.050], [Rp2.150.000], [Rp6.162.500], [Rp-4.012.500], [Rp412.814.550],
  [Des], [Rp412.814.550], [Rp13.000.000], [Rp5.013.650], [Rp7.986.350], [Rp420.800.900],
  [#strong[Total]], [#strong[Rp328.860.000]], [#strong[Rp187.750.000]], [#strong[Rp95.809.100]], [#strong[Rp91.940.900]], [#strong[Rp420.800.900]],
)
== Catatan arus kas
<catatan-arus-kas>
Beberapa hal penting dari arus kas 2025 adalah sebagai berikut:

- Bulan dengan penerimaan tertinggi adalah #strong[Oktober], yaitu sebesar #strong[Rp41.500.000].
- Bulan dengan arus kas bersih negatif terjadi pada #strong[Februari], #strong[Agustus], dan #strong[November].
- Defisit kas bulanan terbesar terjadi pada #strong[November] sebesar #strong[Rp-4.012.500].
- Meskipun terdapat fluktuasi bulanan, saldo akhir tetap meningkat secara signifikan dari awal tahun.

= Laporan aktivitas / income statement 2025
<laporan-aktivitas-income-statement-2025>
Laporan ini menunjukkan hasil operasional yayasan selama tahun 2025.

== Pendapatan 2025
<pendapatan-2025>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Pos], [Nilai],),
  table.hline(),
  [Pendapatan Sewa], [Rp135.000.000],
  [Donasi/Penerimaan], [Rp52.750.000],
  [#strong[Total Pendapatan]], [#strong[Rp187.750.000]],
)
== Beban operasional 2025
<beban-operasional-2025>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Pos], [Nilai],),
  table.hline(),
  [Gaji & Honor], [Rp53.700.000],
  [Utilitas & Internet], [Rp15.516.600],
  [Program/Kegiatan], [Rp13.795.500],
  [Perlengkapan & Perawatan], [Rp5.765.000],
  [Perbaikan], [Rp2.799.000],
  [Iuran Sampah], [Rp2.650.000],
  [Beban Lain-lain], [Rp1.218.000],
  [BBM & Transport], [Rp365.000],
  [#strong[Total Beban]], [#strong[Rp95.809.100]],
  [#strong[Surplus Tahun Berjalan]], [#strong[Rp91.940.900]],
)
== Analisis singkat income statement
<analisis-singkat-income-statement>
Struktur pendapatan menunjukkan bahwa sumber penerimaan terbesar berasal dari #strong[Pendapatan Sewa], yaitu #strong[Rp135.000.000], atau sekitar #strong[71,9%] dari total pendapatan. Sisanya berasal dari #strong[Donasi/Penerimaan] sebesar #strong[Rp52.750.000], atau sekitar #strong[28,1%] dari total pendapatan.

Di sisi beban, komponen terbesar adalah:

- #strong[Gaji & Honor]: #strong[Rp53.700.000]
- #strong[Utilitas & Internet]: #strong[Rp15.516.600]
- #strong[Program/Kegiatan]: #strong[Rp13.795.500]

Komposisi ini menunjukkan bahwa beban yayasan terutama bertumpu pada biaya SDM dan biaya penunjang operasional rutin. Dengan total pendapatan yang jauh lebih tinggi daripada total beban, yayasan membukukan surplus operasional yang memadai.

= Neraca per 31 Desember 2025
<neraca-per-31-desember-2025>
Neraca per 31 Desember 2025 menunjukkan bahwa posisi aset yayasan seluruhnya tercermin dalam kas/bank, dan pada saat penyusunan laporan ini tidak terdapat kewajiban yang dicatat.

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Pos], [Nilai],),
  table.hline(),
  [Kas/Bank], [Rp420.800.900],
  [#strong[Total Aset]], [#strong[Rp420.800.900]],
  [Kewajiban], [Rp0],
  [Ekuitas Awal], [Rp328.860.000],
  [Surplus Tahun Berjalan], [Rp91.940.900],
  [#strong[Total Ekuitas]], [#strong[Rp420.800.900]],
  [#strong[Total Kewajiban & Ekuitas]], [#strong[Rp420.800.900]],
)
== Makna posisi neraca
<makna-posisi-neraca>
Posisi neraca ini menunjukkan bahwa:

- yayasan memiliki likuiditas yang baik pada akhir tahun;
- tidak ada kewajiban yang tercatat dalam laporan;
- pertumbuhan ekuitas sepenuhnya didorong oleh surplus tahun berjalan 2025.

= Evaluasi umum kinerja keuangan 2025
<evaluasi-umum-kinerja-keuangan-2025>
Secara keseluruhan, laporan 2025 memperlihatkan kondisi yang sehat. Terdapat tiga indikator utama yang mendukung kesimpulan ini.

Pertama, yayasan membukukan #strong[surplus operasional] yang tinggi. Kedua, saldo kas akhir tahun meningkat secara nyata dibandingkan saldo awal. Ketiga, yayasan tidak mencatat kewajiban pada akhir tahun, sehingga struktur keuangannya relatif sederhana dan kuat.

Namun demikian, rapat yayasan tetap perlu memperhatikan beberapa risiko:

+ #strong[Konsentrasi pendapatan] pada satu sumber utama, yaitu pendapatan sewa.
+ #strong[Fluktuasi penerimaan bulanan], yang terlihat dari beberapa bulan dengan arus kas negatif.
+ Kebutuhan untuk menjaga keseimbangan antara surplus kas dan kualitas pelayanan/program yayasan.

= Asumsi draft budget 2026
<asumsi-draft-budget-2026>
Draft budget 2026 disusun berdasarkan asumsi yang tercantum dalam workbook, yaitu:

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Asumsi], [Nilai], [Catatan],),
  table.hline(),
  [Pertumbuhan pendapatan 2026 vs realisasi 2025], [3%], [default 3%],
  [Pertumbuhan beban 2026 vs realisasi 2025], [5%], [default 5%],
  [Cadangan/contingency atas beban], [2%], [default 2%],
)
Catatan penting: pada implementasi draft budget, komponen beban dihitung dengan #strong[growth efektif 7%], yaitu akumulasi pertumbuhan beban 5% ditambah contingency 2%.

= Draft budget 2026
<draft-budget-2026>
== Rencana pendapatan 2026
<rencana-pendapatan-2026>
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([Pos Pendapatan], [Basis 2025], [Growth], [Budget 2026],),
  table.hline(),
  [Pendapatan Sewa], [Rp135.000.000], [3%], [Rp139.050.000],
  [Donasi/Penerimaan], [Rp52.750.000], [3%], [Rp54.332.500],
  [#strong[Total Pendapatan]], [#strong[Rp187.750.000]], [], [#strong[Rp193.382.500]],
)
== Rencana beban 2026
<rencana-beban-2026>
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([Pos Beban], [Basis 2025], [Growth Efektif], [Budget 2026],),
  table.hline(),
  [Gaji & Honor], [Rp53.700.000], [7%], [Rp57.459.000],
  [Utilitas & Internet], [Rp15.516.600], [7%], [Rp16.602.762],
  [Program/Kegiatan], [Rp13.795.500], [7%], [Rp14.761.185],
  [Perlengkapan & Perawatan], [Rp5.765.000], [7%], [Rp6.168.550],
  [Perbaikan], [Rp2.799.000], [7%], [Rp2.994.930],
  [Iuran Sampah], [Rp2.650.000], [7%], [Rp2.835.500],
  [Beban Lain-lain], [Rp1.218.000], [7%], [Rp1.303.260],
  [BBM & Transport], [Rp365.000], [7%], [Rp390.550],
  [#strong[Total Beban]], [#strong[Rp95.809.100]], [], [#strong[Rp102.515.737]],
  [#strong[Surplus/(Defisit) Budget 2026]], [], [], [#strong[Rp90.866.763]],
)
== Interpretasi draft budget 2026
<interpretasi-draft-budget-2026>
Dengan asumsi pertumbuhan pendapatan yang relatif moderat, total pendapatan 2026 diproyeksikan menjadi #strong[Rp193.382.500]. Sementara itu, total beban diproyeksikan menjadi #strong[Rp102.515.737]. Berdasarkan proyeksi tersebut, yayasan masih diharapkan mencatat #strong[surplus anggaran 2026 sebesar Rp90.866.763].

Hal ini menunjukkan bahwa draft budget 2026 masih berada dalam koridor yang sehat. Meskipun demikian, ruang surplus sedikit lebih rendah dibandingkan capaian riil 2025, sehingga disiplin pelaksanaan anggaran tetap penting.

= Agenda pembahasan dan usul keputusan rapat
<agenda-pembahasan-dan-usul-keputusan-rapat>
Berikut beberapa butir yang dapat dijadikan agenda pembahasan dan dasar keputusan rapat yayasan:

+ #strong[Mengesahkan laporan keuangan tahun 2025] yang meliputi laporan arus kas, income statement, dan balance sheet.
+ #strong[Mengevaluasi struktur pendapatan yayasan], khususnya ketergantungan pada pendapatan sewa.
+ #strong[Menyetujui atau menyesuaikan asumsi budget 2026], terutama pada:
  - target pertumbuhan pendapatan;
  - laju kenaikan beban;
  - besaran contingency.
+ #strong[Menetapkan prioritas pengeluaran 2026], terutama untuk program, operasional rutin, dan pemeliharaan.
+ #strong[Menetapkan mekanisme monitoring bulanan], agar realisasi 2026 dapat dibandingkan secara berkala dengan budget.

= Rancangan rumusan keputusan rapat
<rancangan-rumusan-keputusan-rapat>
Berikut contoh rumusan singkat keputusan yang dapat digunakan atau disesuaikan:

#quote(block: true)[
Rapat Yayasan menyetujui Laporan Keuangan Tahun 2025 yang terdiri atas Laporan Arus Kas, Laporan Aktivitas/Income Statement, dan Neraca per 31 Desember 2025.

Rapat Yayasan juga menerima Draft Budget Tahun 2026 sebagai dasar pelaksanaan anggaran, dengan catatan bahwa pengurus dapat melakukan penyesuaian terbatas sesuai kebutuhan operasional dan keputusan rapat lanjutan.

Rapat meminta agar realisasi keuangan tahun 2026 dimonitor secara berkala dan dilaporkan secara periodik kepada pengurus yayasan.
]

= Penutup
<penutup>
Dokumen ini dimaksudkan sebagai bahan kerja untuk rapat yayasan. Angka-angka di dalamnya sudah konsisten dengan workbook laporan keuangan 2025 dan draft budget 2026 yang menjadi dasar penyusunan. Naskah ini masih dapat dilengkapi lebih lanjut dengan identitas yayasan, tanggal rapat, nama ketua/pengurus, serta lampiran-lampiran pendukung bila diperlukan.
