import re

with open('c:/gIthub/Notes/docs/lostats/soal-jawab-UTS-2023.qmd', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix asterisk lists to dash lists at start of line
text = re.sub(r'^\*\s+', r'- ', text, flags=re.MULTILINE)

# We want to change numbered lists for questions/answers into alphabetical lists.
def replace_numbering(match):
    num = int(match.group(1))
    # if num > 26 it'll be tricky, but max is 12 here.
    letter = chr(96 + num)
    return f"{letter}. " + match.group(2)

# But wait, Soal 1 process steps in the text: "(1) pengajuan pinjaman (aplikasi), (2) lolos..." -> keep as is.
# The numbered lists are at the start of the line like `1. Probabilitas...` or `11. P(0 default ...)`
# Let's write a regex that matches start of line, number, period, space
text = re.sub(r'(?m)^(\d+)\.\s+(.*)$', replace_numbering, text)

# There is a problem: what if there are multi-line list items? 
# In this file, all list items are single-line, EXCEPT Solusi Soal 3 and 4 where equations might be on the next line!
# Lines 87-98:
# 1. ABC \sim \text{Normal}...
#    $P(15000 < X < 20000)...$
# Our regex only replaces the "1. " part and leaves the next line unchanged. That's perfectly fine!

# Let's double check if any other line starts with "number. ". 
# No standard prose starts with "number. " except lists in this file.

with open('c:/gIthub/Notes/docs/lostats/soal-jawab-UTS-2023.qmd', 'w', encoding='utf-8') as f:
    f.write(text)
