import os
import re
import yaml

def main():
    with open('outline.md', 'r') as f:
        lines = f.readlines()

    parts = []
    current_part = None
    current_chapter = None

    part_num = 0
    chap_num = 0

    for line in lines:
        stripped = line.rstrip()
        if not stripped:
            continue
        
        # Check for Part (Heading 1)
        m_part = re.match(r'^#\s+(.+)', stripped)
        if m_part:
            part_num += 1
            current_part = {
                'title': m_part.group(1),
                'dir': f'P{part_num}',
                'chapters': []
            }
            parts.append(current_part)
            chap_num = 0 # reset chapter number for new part
            continue

        # Check for alternative Part (Heading 2) if Part 1 wasn't found
        m_part2 = re.match(r'^##\s+(.+)', stripped)
        if m_part2 and current_part:
            # We can treat this as text for the part, or just a stray heading
            current_part['description'] = m_part2.group(1)
            continue
        
        # Check for Chapter (Indented list level 1: 2 spaces or bullet)
        m_chap = re.match(r'^ {0,2}-\s+(.+)', stripped)
        if m_chap and current_part:
            chap_num += 1
            current_chapter = {
                'title': m_chap.group(1),
                'file': f'ch{chap_num:02d}.qmd',
                'subchapters': []
            }
            current_part['chapters'].append(current_chapter)
            continue

        # Check for Sub-chapter (Indented list level 2: 4 spaces)
        m_sub = re.match(r'^ {3,4}-\s+(.+)', stripped)
        if m_sub and current_chapter:
            current_chapter['subchapters'].append(m_sub.group(1))

    # Now generate the files
    for p_idx, p in enumerate(parts):
        os.makedirs(p['dir'], exist_ok=True)
        # write Part file
        with open(f"{p['dir']}/{p['dir']}.qmd", 'w') as f:
            f.write(f"# {p['title']}\n\n")
            if 'description' in p:
                f.write(f"{p['description']}\n")

        for c_idx, c in enumerate(p['chapters']):
            with open(f"{p['dir']}/{c['file']}", 'w') as f:
                f.write(f"# {c['title']}\n\n")
                for sub in c['subchapters']:
                    f.write(f"## {sub}\n\n")

    print(f"Parsed {len(parts)} parts.")
    for p in parts:
        print(f"{p['dir']}: {len(p['chapters'])} chapters")

    # Now update _quarto.yml
    try:
        from ruamel.yaml import YAML
        yaml = YAML()
        yaml.preserve_quotes = True
        with open('_quarto.yml', 'r') as f:
            q_data = yaml.load(f)
    except:
        # Fallback if ruamel not available
        import yaml as pyyaml
        with open('_quarto.yml', 'r') as f:
            q_data = pyyaml.safe_load(f)
        yaml = pyyaml

    # Modify chapters in q_data['book']['chapters']
    new_chapters = ['index.qmd', 'intro.qmd']
    for p in parts:
        part_entry = {
            'part': f"{p['dir']}/{p['dir']}.qmd",
            'chapters': [f"{p['dir']}/{c['file']}" for c in p['chapters']]
        }
        new_chapters.append(part_entry)
    
    # Check if references exist
    has_refs = any('references.qmd' in str(c) for c in q_data.get('book', {}).get('chapters', []))
    if has_refs:
        new_chapters.append('references.qmd')

    q_data['book']['chapters'] = new_chapters

    # Write back
    try:
        with open('_quarto.yml', 'w') as f:
            yaml.dump(q_data, f)
        print("Updated _quarto.yml successfully.")
    except Exception as e:
        print(f"Error updating yaml: {e}")

if __name__ == '__main__':
    main()
