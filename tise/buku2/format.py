import re

with open('/home/armein/github/Notes/tise/buku2/draft2.qmd', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Remove questions
# Pattern: "Jelaskan apa yang dijelaskan sumber mengenai.*?"
text = re.sub(r'Jelaskan apa yang dijelaskan sumber mengenai.*?\n+', '', text)

# 2. Fix citations
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

# 3. Consolidate consecutive citations
# loop until no changes
prev = ""
while prev != text:
    prev = text
    text = re.sub(r'(\[@[^\]]+\])\s*(?:,\s*)?\s*(\[@[^\]]+\])', r'\1 \2', text)

text = re.sub(r'(\[@[^\]]+\])\s*\1', r'\1', text)
text = re.sub(r'(\[@[^\]]+\]) \1', r'\1', text)

# 4. Add blank lines before lists (both bullets and numbered)
# If a bullet "-   **" or number "1.  **" is not preceded by two newlines, add them.
# The issue is they are sometimes on the same line: "...akhir. -   **"
# Or just one newline.

# Replace bullet item on same line or preceded by spaces or non-newline characters
# Example: "] .-   **" -> "].\n\n-   **"
text = re.sub(r'([^\n])\s*-\s+\*\*', r'\1\n\n-   **', text)

# Replace bullet item separated by only one newline
text = re.sub(r'([^\n])\n-\s+\*\*', r'\1\n\n-   **', text)

# Same for numbered lists "1.  **"
text = re.sub(r'([^\n])\s*(\d+\.)\s+\*\*', r'\1\n\n\2  **', text)
text = re.sub(r'([^\n])\n(\d+\.)\s+\*\*', r'\1\n\n\2  **', text)

# Clean up multiple newlines greater than 2 to just 2
text = re.sub(r'\n{3,}', '\n\n', text)

# Also fix the more_horiz
text = text.replace('more_horiz', '')
text = text.replace('more\\_horiz', '')
text = text.replace('\\_', '_') # fix underscores since we removed backslash escaping

with open('draft2_fixed.qmd', 'w', encoding='utf-8') as f:
    f.write(text)

