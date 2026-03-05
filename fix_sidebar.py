import re

path = '/mnt/c/Users/chitr/Projects/orderlane_pro/web/components/layout/sidebar.tsx'
with open(path, 'r') as f:
    content = f.read()

# Add Wallet to imports
content = content.replace(
    '  Receipt,\n} from "lucide-react";',
    '  Receipt,\n  Wallet,\n} from "lucide-react";'
)

# Add Collections nav item after Sales Invoices
target = '"Sales Invoices",   icon: Receipt },'
if target in content:
    content = content.replace(
        target,
        '"Sales Invoices",   icon: Receipt },\n  { href: "/collections",             label: "Collections",     icon: Wallet },'
    )

with open(path, 'w') as f:
    f.write(content)

print('Sidebar updated')
