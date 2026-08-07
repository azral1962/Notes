# Buku DNA TISE level 5 - Proyek Quarto

Struktur proyek ini disusun agar monograf dapat diedit sebagai template DNA.

## File utama
- `_quarto.yml` : konfigurasi proyek buku Quarto
- `index.qmd` : halaman awal, prakata, abstrak, dan bab pendahuluan
- `chapters/` : bab-bab utama
- `appendices/` : lampiran teknis dan lampiran transformasi ke dokumen DNA/akademik
- `references.bib` : bibliografi

## Render
Untuk merender buku:
```bash
quarto render
```

Untuk merender hanya HTML:
```bash
quarto render --to html
```

Untuk merender hanya PDF:
```bash
quarto render --to pdf
```
