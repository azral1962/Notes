import re

with open('/home/armein/github/Notes/tise/buku2/draft2_fixed.qmd', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix lists that have no blank line before them:
# Specifically looking for:
# "Some text.\n*   **" -> "Some text.\n\n*   **"
# "Some text.\n-   **" -> "Some text.\n\n-   **"

text = re.sub(r'([^\n])\n(\*|\-)\s+\*\*', r'\1\n\n\2   **', text)

with open('/home/armein/github/Notes/tise/buku2/draft2_fixed.qmd', 'w', encoding='utf-8') as f:
    f.write(text)

