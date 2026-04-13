#import "@preview/bookly:2.1.1": *
// #import "../src/bookly.typ": *

#let config-colors = (
  primary: rgb("#1d90d0"),
  secondary: rgb("#dddddd").darken(15%),
)

#show: bookly.with(
  title: "Rekayasa Sistem Cerdas: Arsitektur dan Representasi Pengetahuan",
  author: "Author Name",
  fonts: (
    body: "Lato",
    math: "Lete Sans Math",
  ),
  // theme: custom,
  // theme: classic,
  // theme: fancy,
  // theme: modern,
  // theme: orly,
  // theme: pretty,
  // tufte: true,
  lang: "en",
  // colors: config-colors,
  title-page: book-title-page(
    series: "Typst book series",
    subtitle: "TISE",
    institution: "Typst community",
    // logo: image("images/typst-logo.svg"),
    //  cover: image("images/book-cover.jpg", width: 45%)
  ),
  config-options: (
    open-right: true,
  ),
)



#set page(paper: "iso-b5", margin: 2cm)
#set text(font: "EB Garamond", size: 12pt)
#set heading(numbering: "1.")


#states.isfrontmatter.update(true)

#tableofcontents

#listoffigures

#listoftables

#part("First part")


#part("Second part")


== Bab 1: Taksonomi Visual Rekayasa

Rekayasa sistem cerdas memerlukan panduan konseptual dan struktural untuk merangkum teori abstrak ke dalam representasi visual yang konkret[cite: 5, 6, 7]. Visualisasi ini berfungsi sebagai peta jalan bagi rekayasawan dalam merancang sistem yang kompleks.

#image("Smart_System_Blueprints.pdf", page: 1)
_Gambar 1.1: Taksonomi Visual Rekayasa Sistem Cerdas[cite: 4]._

== Bab 2: Evolusi Ko-Kreasi Manusia dan Mesin

Visi masa depan rekayasa adalah transisi dari simbiosis manusia-komputer sederhana menuju ko-kreasi naratif[cite: 12, 16]. Dalam model ini, terdapat kolaborasi setara antara manusia sebagai penentu tujuan (Goal-Setter) dan AI sebagai arsitektur kapabilitas (Capability Architecture)[cite: 13, 15, 16].

#image("Smart_System_Blueprints.pdf", page: 2)
_Gambar 2.1: Model Ko-Kreasi Goal-Setter dan Capability Architecture[cite: 13, 15]._

== Bab 3: Anatomi Ekosistem CPSS

Integrasi kecerdasan membentuk anatomi ekosistem Cyber-Physical-Social Systems (CPSS)[cite: 19, 22]. Ekosistem ini menggabungkan tiga pilar kecerdasan: Natural Intelligence, Artificial Intelligence, dan Cultural Intelligence yang berpusat pada sebuah Smart Artefact[cite: 20, 21, 23, 24].

#image("Smart_System_Blueprints.pdf", page: 3)
_Gambar 3.1: Konvergensi Triune Intelligence dalam CPSS[cite: 22, 25]._

= Bab 4: Struktur Kohesi Engine

Utilisasi artefak cerdas digerakkan oleh struktur kohesi yang terdiri dari tiga mesin utama: PUDAL Engine sebagai pusat kognitif, Core Engine sebagai pusat komputasional/mekanik, dan PSKVE Engine sebagai spektrum nilai[cite: 28, 31, 32, 33]. Feedback loop memastikan aliran informasi yang sinkron di antara ketiganya[cite: 29].

#image("Smart_System_Blueprints.pdf", page: 4)
_Gambar 4.1: Diagram Kohesi Smart Artefact[cite: 34]._

== Bab 5: Dualitas Kognisi dan Transaksi

Mesin cerdas memiliki dualitas fungsional: domain internal/kognitif yang fokus pada pembelajaran mandiri (Learn), dan domain eksternal/transaksional yang mengonversi utilitas menjadi nilai nyata seperti efisiensi dan finansial[cite: 40, 42, 44, 47, 49].

#image("Smart_System_Blueprints.pdf", page: 5)
_Gambar 5.1: Matriks Perbandingan PUDAL vs PSKVE Engine[cite: 38, 41, 46]._

#table(
  columns: (1fr, 1fr),
  inset: 10pt,
  [*PUDAL Engine*], [*PSKVE Engine*],
  [Domain: Internal / Kognitif [cite: 42]], [Domain: Eksternal / Transaksional [cite: 47]],
  [Fungsi: Memproses data menjadi keputusan [cite: 43]], [Fungsi: Mengonversi utilitas menjadi nilai [cite: 48]],
  [Output: Pembelajaran (Learn) [cite: 44]], [Output: Efisiensi & Finansial (Value) [cite: 49]],
  [Bentuk: Siklus rotasi tertutup [cite: 45]], [Bentuk: Jaringan topologi terbuka [cite: 50]],
)

== Bab 6: Siklus Kognitif PUDAL

Siklus PUDAL memutar aliran data dan memori secara tanpa henti melalui lima tahap utama: Perceive (Menangkap), Understand (Memahami), Decision (Keputusan), Act (Tindakan), dan Learn (Belajar)[cite: 63, 69].

#image("Smart_System_Blueprints.pdf", page: 6)
_Gambar 6.1: Siklus Kognitif PUDAL[cite: 69]._

== Bab 7: Sirkuit Konversi PSKVE

Sirkuit PSKVE bertanggung jawab mengonversi layanan menjadi nilai lingkungan[cite: 75]. Proses ini melibatkan pertukaran energi yang berkelanjutan mulai dari modal finansial (Value), masuk ke otak komputasional (Knowledge), menjembatani sirkuit perangkat keras (Product), dan berakhir di ekosistem masyarakat (Environment)[cite: 83, 84, 85, 87, 78].

#image("Smart_System_Blueprints.pdf", page: 7)
_Gambar 7.1: Sirkuit Konversi Transaksional PSKVE[cite: 85]._

== Bab 8: Arsitektur ASTF dan Validasi PICOC

Ketahanan sistem dipastikan melalui arsitektur empat lapis ASTF (Application, System, Technology, Fundamental)[cite: 100, 108]. Setiap persimpangan pada metodologi berbentuk V ini divalidasi menggunakan poin PICOC untuk menjamin integritas desain[cite: 100, 107, 108].

#image("Smart_System_Blueprints.pdf", page: 8)
_Gambar 8.1: Metodologi V-Model dengan Validasi PICOC[cite: 108]._

== Bab 9: Sistem Janus dan AI Neuro-Simbolik

Sistem Janus berfungsi sebagai jembatan antara intuisi jaringan saraf (Deep Learning) dan logika simbolik (Prolog)[cite: 114, 125]. Integrasi ini memungkinkan sistem cerdas memiliki kemampuan pengenalan pola sekaligus penalaran logis yang transparan[cite: 121, 124, 125].

#image("Smart_System_Blueprints.pdf", page: 9)
_Gambar 9.1: Arsitektur Integrasi Neuro-Simbolik[cite: 125]._

= Bab 10: Etika Mesin dan Ekosistem Makro-Mikro

Etika mesin (Machine Ethics Forcefield) harus merantai seluruh skala ekosistem, mulai dari sensor IoT mikro dan monitor medis hingga jaringan transportasi otonom dan infrastruktur energi kota pintar makro[cite: 132, 140, 141].

#image("Smart_System_Blueprints.pdf", page: 10)
_Gambar 10.1: Lanskap Etika dalam Ekosistem Smart Engineering[cite: 141]._

== Bab 11: Rekayasa Instruksi untuk Presisi

Akurasi visual dalam sistem cerdas dicapai melalui anatomi prompt yang ketat, terdiri dari bingkai situasional, identifikasi elemen inti, lapisan spesifikasi, dan tata kelola estetika[cite: 149, 150, 151, 152, 158]. Parameter gaya dalam bahasa Inggris memastikan tingkat abstraksi intelektual yang terjaga[cite: 161].

#image("Smart_System_Blueprints.pdf", page: 11)
_Gambar 11.1: Anatomi Prompt untuk Presisi Visual Akademik[cite: 149]._

== Bab 12: Kesimpulan: Harmoni Niat dan Kapabilitas

Desain sistem cerdas pada akhirnya bertumpu pada kejelasan niat manusia dan kapabilitas mesin[cite: 171]. Rekayasa ini bukan sekadar merakit komponen, melainkan mendesain ko-kreasi yang seimbang antara parameter etika manusia dan kapasitas eksekusi mesin tanpa batas[cite: 185].

#image("Smart_System_Blueprints.pdf", page: 12)
_Gambar 12.1: Desain Sistem Berbasis Etika dan Kapasitas[cite: 183, 184, 188]._


#show: appendix

// #include "appendix/app_main.typ"

// #bibliography("bibliography/sample.yml")
#bibliography("sample.bib")

#let abstracts-fr-en = (
  (
    title: [#set text(lang: "fr"); Résumé :],
    text: [#lorem(100)],
  ),
  (
    title: [#set text(lang: "en", region: "gb"); Abstract:],
    text: [#lorem(100)],
  ),
)

