import re

with open('mobile/lib/core/router/app_router.dart', 'r') as f:
    content = f.read()

# Find the calendar routes
calendar_block = re.search(r'(          // ── Calendar \(Legacy System\) ──.*?)(?=        \],\n      \),\n    \],\n  \);)', content, re.DOTALL)

if calendar_block:
    extracted = calendar_block.group(1)
    # Remove from shell route
    new_content = content.replace(extracted, "")
    
    # Insert before ShellRoute:
    # search for ShellRoute
    shell_route_idx = new_content.find('      // ── Dashboard Shell (role-based) ──')
    
    final_content = new_content[:shell_route_idx] + extracted.replace('          // ── Calendar', '      // ── Calendar').replace('          GoRoute', '      GoRoute') + new_content[shell_route_idx:]
    
    with open('mobile/lib/core/router/app_router.dart', 'w') as f:
        f.write(final_content)
    print("Successfully moved calendar routes")
else:
    print("Failed to find calendar block")
