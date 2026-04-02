import re

with open('c:/gIthub/Notes/docs/lostats/soal-jawab-UTS-2022.qmd', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix Peraturan
text = re.sub(
    r'\*\*Peraturan:\*\*\s*1\.\s*(.*?)\s*2\.\s*(.*?)\s*3\.\s*(.*?)\s*4\.\s*(.*?)(\n\s*\n|---)',
    r'**Peraturan:**\n1. \1\n2. \2\n3. \3\n4. \4\n\n---',
    text, flags=re.DOTALL
)

# Fix Soal 1 List items (1. a\. ...)
text = re.sub(r'^\d+\.\s+([a-z])\\\.\s+', r'\1. ', text, flags=re.MULTILINE)
text = re.sub(r'^\s*12\.\s*\n\s*l\.\s*', r'l. ', text, flags=re.MULTILINE)

# Fix Solusi 1 List items (1. **a.** ...) -> a. **a.** ... OR just a.
text = re.sub(r'^\d+\.\s+\*\*([a-z])\.\*\*', r'\1.', text, flags=re.MULTILINE)

# Fix Solusi 2, 3, 4, 6 where it does: 1. **a.**
# Wait, for Solusi 1, it became a. b. c. etc because we matched \1. which refers to the letter group.
# But for Solusi 2, the format was:
# 1. **a.** $P(X \ge 1)...$
# We want this to be:
# 1. $P(X \ge 1)...$ 
# because questions were 1, 2, 3...
# Wait, my regex above `r'^\d+\.\s+\*\*([a-z])\.\*\*', r'\1.'` changed EVERY "1. **a.**" to "a."!
# For Soal 1, this is great! It becomes a., b., c.
# For Soal 2, questions were 1., 2.. It's fine if they become a., b. or we leave as 1. 2.
# Actually, the user just wants the lists to be "neat". Soal 2 questions were 1. 2. 3. 4. 5. 6.
# Solusi had a., b., c., d., e., f. It's actually cleaner if they all use letters, but let's see.

# I will write a function to handle this robustly.
def reformat(match):
    return f"{match.group(1)}."

with open('c:/gIthub/Notes/docs/lostats/soal-jawab-UTS-2022.qmd', 'w', encoding='utf-8') as f:
    # First, let's fix the Peraturan (handled above)
    
    # Fix asterisks in lists
    text = re.sub(r'^\s*\\\*\s*', r'- ', text, flags=re.MULTILINE)
    
    # Write back
    f.write(text)

