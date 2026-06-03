import os
import yaml

parts = [
    {
        "title": "Filosofi & Visi",
        "chapters": [
            "Man-Computer Symbiosis (Licklider 1960)",
            "Evolusi TISE 2.0 (Homo Narrans)",
            "Cyber-Physical-Social Systems (CPSS)"
        ]
    },
    {
        "title": "Smart Artefact",
        "chapters": [
            "Core Engine (Kekuatan Fisik/Komputasi)",
            "PUDAL Engine (Jantung Kognisi)",
            "PSKVE Engine (Konverter Nilai)"
        ]
    },
    {
        "title": "Siklus Kognitif PUDAL",
        "chapters": [
            "Perceive (Persepsi Sensorik)",
            "Understand (Pemahaman Kontekstual)",
            "Decision-making (Perencanaan Strategis)",
            "Act-Response (Eksekusi Tindakan)",
            "Learning-evaluating (Adaptasi & Evolusi)"
        ]
    },
    {
        "title": "Dimensi Energi PSKVE",
        "chapters": [
            "Product (Integritas Fisik)",
            "Service (Kepuasan Layanan)",
            "Knowledge (Kapasitas Intelektual)",
            "Value (Ekonomi & Sosial)",
            "Environment (Kelestarian Ekologis)"
        ]
    },
    {
        "title": "Metodologi Rekayasa",
        "chapters": [
            "Arsitektur ASTF (Application, System, Tech, Fund)",
            "Validasi PICOC (Evidence-based)",
            "V-Method (Siklus Hidup Terstruktur)"
        ]
    },
    {
        "title": "Alat Implementasi AI",
        "chapters": [
            "Ontologi (Basis Semantik)",
            "Prolog (Penalaran Logika)",
            "Python (Otot Algoritmik & ML)",
            "Sistem Janus (Integrasi Neuro-Simbolik)"
        ]
    },
    {
        "title": "Aplikasi & Tantangan",
        "chapters": [
            "Smart City & Transportasi Otonom",
            "Diagnosis Medis (DSS)",
            "Explainable AI (XAI)",
            "Etika & Tanggung Jawab Hukum (Liability)"
        ]
    }
]

# Generate new outline.md
with open('outline.md', 'w') as f:
    f.write("# Arsitektur dan Metodologi Rekayasa Sistem Cerdas Terintegrasi\n\n")
    for i, p in enumerate(parts):
        f.write(f"## {p['title']}\n")
        for c in p['chapters']:
            f.write(f"  - {c}\n")

# Generate directories and files
for i, p in enumerate(parts):
    dir_name = f"P{i+1}"
    os.makedirs(dir_name, exist_ok=True)
    with open(f"{dir_name}/{dir_name}.qmd", 'w') as f:
        f.write(f"# {p['title']}\n\n")
    for j, c in enumerate(p['chapters']):
        with open(f"{dir_name}/ch{j+1:02d}.qmd", 'w') as f:
            f.write(f"# {c}\n\n")

# Update _quarto.yml
import yaml as pyyaml
with open('_quarto.yml', 'r') as f:
    q_data = pyyaml.safe_load(f)

new_chapters = ['index.qmd', 'intro.qmd']
for i, p in enumerate(parts):
    dir_name = f"P{i+1}"
    part_entry = {
        'part': f"{dir_name}/{dir_name}.qmd",
        'chapters': [f"{dir_name}/ch{j+1:02d}.qmd" for j in range(len(p['chapters']))]
    }
    new_chapters.append(part_entry)

has_refs = False
for c in q_data.get('book', {}).get('chapters', []):
    if isinstance(c, str) and 'references.qmd' in c:
        has_refs = True

if has_refs:
    new_chapters.append('references.qmd')

q_data['book']['chapters'] = new_chapters

with open('_quarto.yml', 'w') as f:
    pyyaml.dump(q_data, f, sort_keys=False)

print("Done")
