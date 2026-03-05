import sys

seeds_path = '/mnt/c/Users/chitr/Projects/orderlane_pro/backend/db/seeds.rb'
snippet_path = '/mnt/c/Users/chitr/Projects/orderlane_pro/backend/db/seeds_payments.rb'

with open(seeds_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

with open(snippet_path, 'r', encoding='utf-8') as f:
    snippet = f.read()

marker = "puts '  \u250c\u2500 Dev login credentials"

# Check if already inserted
already_inserted = any('Seeding sales invoices' in l for l in lines)
if already_inserted:
    print('Seed data already present in seeds.rb, skipping.')
    sys.exit(0)

insertion_idx = None
for i, line in enumerate(lines):
    if marker in line:
        # We want to insert before the blank puts '' line just before this
        # Look back for the blank puts '' line
        for j in range(i - 1, max(i - 5, 0), -1):
            if lines[j].strip() == "puts ''":
                insertion_idx = j
                break
        if insertion_idx is None:
            insertion_idx = i
        break

if insertion_idx is None:
    print(f'ERROR: Could not find marker: {marker!r}')
    sys.exit(1)

print(f'Inserting seed data before line {insertion_idx + 1}')

new_lines = lines[:insertion_idx] + [snippet + '\n'] + lines[insertion_idx:]

with open(seeds_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Done. seeds.rb updated successfully.')
