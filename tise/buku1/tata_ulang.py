import os
import re
import shutil
import yaml as pyyaml

# Clean up old directories
for i in range(1, 20):
    d = f"P{i}"
    if os.path.exists(d):
        shutil.rmtree(d)

with open('outline.md', 'r') as f:
    lines = f.readlines()

parts = []
current_part = None
current_chapter = None

part_idx = 0
global_ch_idx = 1

for line in lines:
    line = line.strip()
    if not line:
        continue
    
    m_part = re.match(r'^##\s+(.*)', line)
    if m_part:
        part_idx += 1
        current_part = {
            'title': m_part.group(1).strip(),
            'dir': f"P{part_idx}",
            'id': part_idx,
            'chapters': []
        }
        parts.append(current_part)
        current_chapter = None
        continue
        
    m_chap = re.match(r'^###\s+(.*)', line)
    if m_chap and current_part:
        ch_title = m_chap.group(1).strip()
        current_chapter = {
            'title': ch_title,
            'file': f"ch-{global_ch_idx:02d}.qmd",
            'sections': []
        }
        current_part['chapters'].append(current_chapter)
        global_ch_idx += 1
        continue
        
    m_sec = re.match(r'^####\s+(.*)', line)
    if m_sec and current_chapter:
        current_chapter['sections'].append(m_sec.group(1).strip())

for p in parts:
    os.makedirs(p['dir'], exist_ok=True)
    with open(f"{p['dir']}/{p['dir']}.qmd", 'w') as f:
        f.write(f"# Bagian {p['id']}: {p['title']}\n\n")
        
    for c in p['chapters']:
        with open(f"{p['dir']}/{c['file']}", 'w') as f:
            f.write(f"# {c['title']}\n\n")
            f.write("## Ringkasan\n\n")
            for sec in c['sections']:
                f.write(f"## {sec}\n\n")

# Update quarto.yml
with open('_quarto.yml', 'r') as f:
    q_data = pyyaml.safe_load(f)

new_chapters = ['index.qmd']
if 'intro.qmd' in [c if isinstance(c, str) else '' for c in q_data.get('book', {}).get('chapters', [])]:
    new_chapters.append('intro.qmd')

for p in parts:
    part_entry = {
        'part': f"{p['dir']}/{p['dir']}.qmd",
        'chapters': [f"{p['dir']}/{c['file']}" for c in p['chapters']]
    }
    new_chapters.append(part_entry)

# Add backmatter
backmatter_entry = {
    'part': 'backmatter.qmd',
    'chapters': ['references.qmd']
}
new_chapters.append(backmatter_entry)

q_data['book']['chapters'] = new_chapters

with open('_quarto.yml', 'w') as f:
    pyyaml.dump(q_data, f, sort_keys=False, allow_unicode=True)

print(f"Generated {len(parts)} parts and {global_ch_idx-1} chapters.")
