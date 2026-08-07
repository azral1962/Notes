import re

with open('/home/armein/github/Notes/tise/buku2/isi.qmd', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix citations
ref_map = {
    r'Smart\\?_Engineering\\?_Framework\\?_v2b\.pdf': 'smart_engineering_framework',
    r'Ontology, Prolog, Python Integration': 'ontology_prolog_python',
    r'Prolog-Python Integration for Engineering Applications': 'prolog_python_integration',
    r'Generate a Guidline to write a paper using the fol\.\.\.': 'guideline_paper',
    r'Generate a Guideline to write a paper using the fol\.\.\.': 'guideline_paper', # just in case
}

for pattern, key in ref_map.items():
    # match optionally escaped brackets and the source string
    text = re.sub(r'\\?\[Source: \d+: ' + pattern + r'\\?\]', f'[@{key}]', text)

# Consolidate consecutive citations
prev = ""
while prev != text:
    prev = text
    text = re.sub(r'(\[@[^\]]+\])\s*(?:,\s*)?\s*(\[@[^\]]+\])', r'\1 \2', text)

text = re.sub(r'(\[@[^\]]+\])\s*\1', r'\1', text)
text = re.sub(r'(\[@[^\]]+\]) \1', r'\1', text)

# Fix lists - add newline before list items
text = re.sub(r'([^\n])\n(\*|\-)\s+\*\*', r'\1\n\n\2   **', text)
text = re.sub(r'([^\n])\s*-\s+\*\*', r'\1\n\n-   **', text)
text = re.sub(r'([^\n])\n-\s+\*\*', r'\1\n\n-   **', text)
text = re.sub(r'([^\n])\s*(\d+\.)\s+\*\*', r'\1\n\n\2  **', text)
text = re.sub(r'([^\n])\n(\d+\.)\s+\*\*', r'\1\n\n\2  **', text)

# Clean up multiple newlines greater than 2 to just 2 (except maybe between question and answer we want to keep some spacing but 2 is fine)
text = re.sub(r'\n{3,}', '\n\n', text)

# Clean up placeholders and escaping
text = text.replace('more_horiz', '')
text = text.replace('more\\_horiz', '')
text = text.replace('\\_', '_')

with open('/home/armein/github/Notes/tise/buku2/isi_fixed.qmd', 'w', encoding='utf-8') as f:
    f.write(text)

