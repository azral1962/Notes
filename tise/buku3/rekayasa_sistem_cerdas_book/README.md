# Proyek Buku Quarto

Struktur ini disiapkan agar draft dapat dirender sebagai buku Quarto/Typst.

## File utama
- `_quarto.yml`: konfigurasi proyek buku
- `index.qmd`: halaman depan dan pengantar
- `*.qmd`: bab-bab buku
- `slide.pdf`: sumber gambar PDF yang dipanggil langsung oleh blok Typst
- `references.bib`: bibliografi

## Catatan
Pastikan render dijalankan dari folder proyek ini agar referensi relatif ke `slide.pdf` tetap valid.
