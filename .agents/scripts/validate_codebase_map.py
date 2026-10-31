#!/usr/bin/env python3
"""
Navigation Map Validator for MikroTik Quota Threshold Monitor

Purpose: Detect obvious navigation-document drift without automatically rewriting documentation.
Validates mapped repository paths referenced by the navigation layer.

Outputs:
  PASS - All mapped paths exist
  REVIEW REQUIRED - Some paths missing, check if renamed/deleted
  ERROR - Critical paths missing, system may be broken

Does NOT automatically rewrite documentation.
Does NOT require Git (degraded gracefully if not available).
"""

import os
import re
import sys
from pathlib import Path

# Repository root (where this script runs)
REPO_ROOT = Path.cwd()


def extract_mapped_paths_from_file(file_path):
    """
    Extract repository-relative file/directory paths from navigation documentation.

    Conservative by design: only accepts paths that actually look like repository
    paths. URL paths (/webhook/...), RouterOS script-name shorthand (isolate_wan1/2),
    container paths (/var/lib/grafana/...) and bare context-doc names are ignored
    to avoid false 'missing path' reports.
    """
    if not file_path.exists():
        return set()

    content = file_path.read_text(encoding='utf-8')
    paths = set()

    # Backticked tokens (most reliable signal in these docs)
    for token in re.findall(r'`([^`\n]+)`', content):
        paths.update(_classify_token(token))

    # Table first-column entries: | `path` | description |
    for match in re.findall(r'\|\s*`([^`\n]+)`\s*\|', content):
        paths.update(_classify_token(match))

    return paths


# Extensions that indicate a concrete repository file
FILE_EXTENSIONS = ('.sql', '.rsc', '.yml', '.yaml', '.json', '.md', '.py', '.js', '.conf')


def _classify_token(token):
    """Return {path} if the token is a plausible repository path, else empty set."""
    token = token.strip()

    # Skip absolute/URL/container paths — not repository paths
    if token.startswith(('/', 'http://', 'https://', 'C:\\', 'D:\\')):
        return set()

    # Skip bare context-doc names (they live under .agents/context/)
    if token in ('ARCHITECTURE.md', 'CODEBASE_MAP.md', 'DOMAIN_MAP.md',
                 'DATA_FLOW.md', 'README.md', 'AGENTS.md', 'DEPLOYMENT.md'):
        return set()

    # Skip RouterOS script-name shorthand and commands (isolate_wan1/2, etc.)
    if not any(ch in token for ch in ('.', '/')):
        return set()

    # Skip glob patterns (*.json, provisioning/dashboards/*.json)
    if '*' in token or '?' in token:
        return set()

    # Skip bare extension tokens (.rsc, .sql) — not real paths
    if token.startswith('.'):
        return set()

    # RouterOS path syntax (/ip firewall mangle) — skip
    if token.startswith('/ip') or token.startswith('/system') or token.startswith('/routing'):
        return set()

    # Must have a known file extension, or be a known directory
    if token.endswith(FILE_EXTENSIONS):
        return {token}

    if token.rstrip('/') in ('provisioning', '.agents', 'context', 'rules', 'scripts'):
        return {token}

    return set()


def check_path_exists(path_str):
    """
    Check if a path exists in the repository.

    Handles bare filenames (e.g. 'mikrotik-overview.json') by searching the tree
    for a unique match, so a valid mapping expressed without its full directory
    is not falsely reported as missing.
    """
    if (REPO_ROOT / path_str).exists():
        return True

    if '/' not in path_str and '\\' not in path_str:
        matches = [p for p in REPO_ROOT.rglob(path_str)
                   if p.is_file()
                   and not str(p.relative_to(REPO_ROOT)).startswith(('.agents/', '.git/'))]
        if len(matches) == 1:
            return True
        if len(matches) > 1:
            return None  # ambiguous — report separately rather than as missing

    return False


def get_git_status():
    """Return Git status if available, empty dict otherwise."""
    try:
        import subprocess
        # Check if Git is available
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True, cwd=REPO_ROOT)
        if result.returncode == 0:
            changed_files = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            return {'available': True, 'changed': changed_files}
        else:
            return {'available': False, 'error': result.stderr}
    except Exception as e:
        return {'available': False, 'error': str(e)}


def validate_all_maps():
    """Validate all navigation maps against the current repository."""
    context_dir = REPO_ROOT / '.agents' / 'context'
    
    if not context_dir.exists():
        return {'status': 'ERROR', 'message': 'Navigation context directory missing'}
    
    # Files to check for mapped paths
    map_files = [
        context_dir / 'ARCHITECTURE.md',
        context_dir / 'CODEBASE_MAP.md', 
        context_dir / 'DOMAIN_MAP.md',
        context_dir / 'DATA_FLOW.md'
    ]
    
    all_mapped_paths = set()
    for map_file in map_files:
        if map_file.exists():
            mapped_paths = extract_mapped_paths_from_file(map_file)
            all_mapped_paths.update(mapped_paths)
    
    # Critical paths that must exist (core system)
    critical_paths = {
        'schema.sql',
        'docker-compose.monitoring.yml',
        'DEPLOYMENT.md',
        'hotspot_telemetry.rsc',
        'wan_quality.rsc',
        'wan_control_pbr.rsc',
        'wccp_control.rsc',
        'provisioning/datasources/datasource.yml',
        'provisioning/dashboards/dashboards.yml',
        'provisioning/dashboards/mikrotik-overview.json',
        '.agents/context/README.md'
    }
    
    # Important paths (should exist for system to function)
    important_paths = {
        'provisioning/dashboards/hotspot-overview.json',
        'MikroTik - Router Offline Monitor.json',
        'MikroTik - Hotspot Ingestion.json', 
        'MikroTik - WAN Quality Ingestion.json',
        'MikroTik - Telegram Interactive Bot.json'
    }
    
    # Check which paths exist
    missing_critical = []
    missing_important = []
    missing_other = []
    ambiguous = []

    for path_str in sorted(all_mapped_paths):
        exists = check_path_exists(path_str)
        if exists is None:
            ambiguous.append(path_str)
            continue
        if not exists:
            if path_str in critical_paths:
                missing_critical.append(path_str)
            elif path_str in important_paths:
                missing_important.append(path_str)
            else:
                missing_other.append(path_str)
    
    # Also check critical paths not mentioned in maps
    for path_str in critical_paths:
        if not check_path_exists(path_str) and path_str not in all_mapped_paths:
            missing_critical.append(path_str + ' (not in maps)')
    
    # Check Git status (if available)
    git_status = get_git_status()
    
    return {
        'status': 'PASS' if not missing_critical and not missing_important else 'REVIEW_REQUIRED',
        'mapped_paths_count': len(all_mapped_paths),
        'mapped_paths': all_mapped_paths,
        'missing_critical': missing_critical,
        'missing_important': missing_important,
        'missing_other': missing_other,
        'ambiguous': ambiguous,
        'git_available': git_status.get('available', False),
        'git_changed': git_status.get('changed', []) if git_status.get('available') else [],
        'git_error': git_status.get('error') if not git_status.get('available') else None
    }


def scan_for_unmapped_paths(documented_paths):
    """
    Find repository files that look architectural but are NOT mentioned anywhere in
    the navigation documentation.

    Only high-signal component types are considered (router scripts, SQL DDL,
    docker-compose, provisioning, n8n workflows). Python utilities are excluded
    because the repo intentionally groups them rather than listing every file.
    """
    candidates = []

    for pattern in ('*.rsc', 'docker-compose*.yml'):
        for path in REPO_ROOT.rglob(pattern):
            rel = str(path.relative_to(REPO_ROOT)).replace('\\', '/')
            if not rel.startswith(('.agents/', '.git/')):
                candidates.append(rel)

    # provisioning directory contents
    prov = REPO_ROOT / 'provisioning'
    if prov.exists():
        for path in prov.rglob('*'):
            if path.is_file():
                candidates.append(str(path.relative_to(REPO_ROOT)).replace('\\', '/'))

    # n8n workflow exports at root (name pattern)
    for path in REPO_ROOT.glob('*.json'):
        if path.name.startswith('MikroTik'):
            candidates.append(path.name)

    unmapped = []
    for rel in sorted(set(candidates)):
        if rel not in documented_paths:
            # also accept bare-filename mentions (e.g. "schema.sql" mentioned as "schema.sql")
            if Path(rel).name not in documented_paths:
                unmapped.append(rel)

    return unmapped


def main():
    """Main validation function."""
    print("=== Navigation Map Validator ===")
    print(f"Repository: {REPO_ROOT}")
    print()
    
    # Check if repository appears to be the right one
    if not (REPO_ROOT / 'schema.sql').exists():
        print("⚠️  Warning: schema.sql not found - may not be correct repository")
        print()
    
    # Validate maps
    validation = validate_all_maps()
    
    print(f"Status: {validation['status']}")
    print(f"Mapped paths in documentation: {validation['mapped_paths_count']}")
    print()
    
    if validation['missing_critical']:
        print("❌ Missing Critical Paths:")
        for path in validation['missing_critical']:
            print(f"  - {path}")
        print()
    
    if validation['missing_important']:
        print("⚠️  Missing Important Paths:")
        for path in validation['missing_important']:
            print(f"  - {path}")
        print()
    
    if validation.get('ambiguous'):
        print("❔ Ambiguous Mapped Paths (multiple matches; use full path):")
        for path in validation['ambiguous']:
            print(f"  - {path}")
        print()

    if validation['missing_other']:
        print("⚠️  Other Missing Mapped Paths:")
        for path in validation['missing_other']:
            print(f"  - {path}")
        print()
    
    # Git status
    if validation['git_available']:
        print("📊 Git Status:")
        if validation['git_changed']:
            print(f"  {len(validation['git_changed'])} uncommitted changes")
            if len(validation['git_changed']) <= 10:
                for change in validation['git_changed']:
                    print(f"    {change}")
        else:
            print("  No uncommitted changes")
    else:
        print("ℹ️  Git not available or not initialized")
        if validation['git_error']:
            print(f"  Error: {validation['git_error']}")
    print()
    
    # Scan for architectural paths that are not mentioned in the maps
    print("🔍 Scanning for architectural paths not referenced in navigation docs...")
    unmapped = scan_for_unmapped_paths(validation['mapped_paths'])
    print()

    # Summary and recommendations
    print("=== Validation Summary ===")
    if validation['status'] == 'PASS':
        print("✅ PASS: All critical paths exist")
        print("   Maps appear consistent with repository")
    elif validation['status'] == 'REVIEW_REQUIRED':
        print("⚠️  REVIEW REQUIRED: Some critical or important paths missing")
        print("   Check if paths were renamed/moved, or maps need updating")
    else:
        print("❌ ERROR: Navigation system incomplete")

    # Recommendations
    if validation['missing_critical'] or validation['missing_important'] or validation['missing_other']:
        print()
        print("=== Stale mappings to review ===")
        for path in validation['missing_critical']:
            print(f"  [CRITICAL] {path}")
        for path in validation['missing_important']:
            print(f"  [IMPORTANT] {path}")
        for path in validation['missing_other']:
            print(f"  [minor]    {path}")

    if unmapped:
        print()
        print("=== Architectural paths not referenced in navigation docs ===")
        for path in unmapped:
            print(f"  - {path}")
        print("  Consider whether these need mapping entries.")

    if not validation['missing_critical'] and not validation['missing_important'] \
            and not validation['missing_other'] and not unmapped \
            and not validation.get('ambiguous'):
        print()
        print("   No drift detected. Navigation layer is consistent with the repository.")

    # Final status code
    return 0 if validation['status'] == 'PASS' else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nValidation interrupted")
        sys.exit(130)
    except Exception as e:
        print(f"Error during validation: {e}")
        sys.exit(2)