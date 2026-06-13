import re

with open('draft.tex', 'r') as f:
    content = f.read()

def process_table(match):
    cols = match.group(2)
    body = match.group(3)
    
    # Extract caption if exists
    caption_match = re.search(r'\\caption\{(.*?)\}\\tabularnewline\n', body, re.DOTALL)
    caption_str = ""
    if caption_match:
        caption_str = f"\\caption{{{caption_match.group(1)}}}\n"
        body = body.replace(caption_match.group(0), '')
        
    # Remove \endfirsthead block if exists
    body = re.sub(r'\\endfirsthead.*?\\endhead\n', '', body, flags=re.DOTALL)
    
    # Remove \endhead block if \endfirsthead wasn't there
    body = re.sub(r'\\endhead\n', '', body)
    
    # Remove \bottomrule\noalign{}\n\endlastfoot
    body = re.sub(r'\\bottomrule\\noalign\{\}\n\\endlastfoot\n', '', body)
    
    # Construct new table
    new_table = f"\\begin{{table*}}[!t]\n\\centering\n\\fontsize{{10}}{{12}}\\selectfont\n{caption_str}\\begin{{tabular}}{{{cols}}}\n" + body + "\\bottomrule\n\\end{tabular}\n\\end{table*}\n"
    
    return new_table

pattern = r'(\{\\def\\LTcaptype\{none\}\s*%\s*do not increment counter\n)?\\begin\{longtable\}\[\]\{(.*?)\}\n(.*?)\\end\{longtable\}(\n\})?'

content = re.sub(pattern, process_table, content, flags=re.DOTALL)

with open('draft.tex', 'w') as f:
    f.write(content)

print("Tables fixed.")
