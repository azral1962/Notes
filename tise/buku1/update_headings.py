import re

with open('outline.md', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    m = re.match(r'^(\s*)-\s+(.*)', line)
    if m:
        indent = len(m.group(1))
        text = m.group(2).strip()
        if indent <= 2:
            new_lines.append(f"### {text}\n")
        else:
            new_lines.append(f"#### {text}\n")
    else:
        new_lines.append(line)

with open('outline.md', 'w') as f:
    f.writelines(new_lines)
