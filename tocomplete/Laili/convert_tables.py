import re

with open('healthy.qmd', 'r') as f:
    text = f.read()

# Table 1: Evidence Map
table1_match = re.search(r'\| \\# \| Paper \| Stream \| Aim \| Method \| Main finding \| Why it matters \|\n\|-.*?\|\n(.*?)\n\n', text, re.DOTALL)
if table1_match:
    lines = table1_match.group(1).strip().split('\n')
    new_text = ""
    for line in lines:
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) == 7:
            num, paper, stream, aim, method, finding, why = cols
            new_text += f"{num}. **{paper}**. *Stream:* {stream}. *Aim:* {aim}. *Method:* {method}. *Main finding:* {finding}. *Why it matters:* {why}.\n"
    
    text = text.replace(table1_match.group(0), new_text + "\n")

# Table 2: Simulation Experiment Design
table2_match = re.search(r'\| Component \| Specification \| Rationale \|\n\|-.*?\|\n(.*?)\n\n', text, re.DOTALL)
if table2_match:
    lines = table2_match.group(1).strip().split('\n')
    new_text = ""
    for line in lines:
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) == 3:
            comp, spec, rationale = cols
            new_text += f"- {comp}: {spec}. *Rationale:* {rationale}.\n"
    
    text = text.replace(table2_match.group(0), new_text + "\n")

# Table 3: Illustrative summary table
table3_match = re.search(r'\| Metric \| No recommender \| Consumer-only recommender \| Rule-based planning \| Full MSRS ecosystem \|\n\|-.*?\|\n(.*?)\n\n', text, re.DOTALL)
if table3_match:
    lines = table3_match.group(1).strip().split('\n')
    new_text = ""
    for line in lines:
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) == 5:
            metric, no_rec, cons_rec, rule, full = cols
            new_text += f"- **{metric}**: No recommender: {no_rec}; Consumer-only recommender: {cons_rec}; Rule-based planning: {rule}; Full MSRS ecosystem: {full}.\n"
            
    text = text.replace(table3_match.group(0), new_text + "\n")

with open('healthy.qmd', 'w') as f:
    f.write(text)

print("Tables converted to paragraphs successfully in healthy.qmd.")
