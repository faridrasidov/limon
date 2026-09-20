#!/usr/bin/env bash
# Theme discovery, precedence, listing, and validation.
# SPDX-License-Identifier: GPL-3.0-or-later

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

USER_THEMES="$LIMON_CONF_DIR/themes"
mkdir -p "$USER_THEMES"

# --- shipped themes ---

it "finds every theme shipped in themes/"
missing=""
for f in "$LIMON_REPO_ROOT"/themes/*.theme; do
    name="$(basename "$f" .theme)"
    _limon_theme_exists "$name" || missing+=" $name"
done
assert_eq "" "$missing"

it "every shipped theme validates without warnings"
bad=""
for f in "$LIMON_REPO_ROOT"/themes/*.theme; do
    if ! _limon_validate_theme_file "$f" 2>/dev/null; then
        bad+=" $(basename "$f")"
    fi
done
assert_eq "" "$bad"

it "reports a missing theme as nonexistent"
assert_fail _limon_theme_exists "definitely-not-a-theme"

it "lists themes without duplicates"
count_all="$(_limon_list_themes | wc -l)"
count_uniq="$(_limon_list_themes | sort -u | wc -l)"
assert_eq "$count_all" "$count_uniq"

# --- precedence: the user directory wins over the repo directory ---

cat > "$USER_THEMES/default.theme" <<'EOF'
# user override of a shipped theme name
col_ok='\[\e[38;5;99m\]'
EOF

it "prefers a user theme over the shipped one of the same name"
assert_eq "$USER_THEMES/default.theme" "$(_limon_resolve_theme_file default)"

it "still finds shipped themes that the user has not overridden"
assert_eq "$LIMON_REPO_ROOT/themes/nord.theme" "$(_limon_resolve_theme_file nord)"

it "a user-only theme is discoverable"
cat > "$USER_THEMES/mine.theme" <<'EOF'
col_ok='\[\e[38;5;10m\]'
EOF
assert_ok _limon_theme_exists mine

it "a user-only theme appears in the listing"
assert_contains "$(_limon_list_themes)" "mine"

# --- validation ---

it "flags an unknown variable"
cat > "$USER_THEMES/bad_key.theme" <<'EOF'
col_ok='\[\e[38;5;10m\]'
col_bogus='\[\e[38;5;10m\]'
EOF
assert_contains "$(_limon_validate_theme_file "$USER_THEMES/bad_key.theme" 2>&1)" "unknown variable"

it "flags unbalanced \\[ \\] in a color"
cat > "$USER_THEMES/bad_brackets.theme" <<'EOF'
col_ok='\[\e[38;5;10m'
EOF
assert_contains "$(_limon_validate_theme_file "$USER_THEMES/bad_brackets.theme" 2>&1)" "unbalanced"

it "flags a line that is not a key=value assignment"
cat > "$USER_THEMES/bad_line.theme" <<'EOF'
this is not an assignment
EOF
assert_contains "$(_limon_validate_theme_file "$USER_THEMES/bad_line.theme" 2>&1)" "invalid line"

it "accepts comments and blank lines"
cat > "$USER_THEMES/clean.theme" <<'EOF'
# a comment

col_ok='\[\e[38;5;10m\]'

# another comment
theme_multiline=1
EOF
assert_ok _limon_validate_theme_file "$USER_THEMES/clean.theme"

it "accepts every documented theme key"
cat > "$USER_THEMES/allkeys.theme" <<'EOF'
col_ok='\[\e[38;5;1m\]'
col_err='\[\e[38;5;2m\]'
col_git='\[\e[38;5;3m\]'
col_dir='\[\e[38;5;4m\]'
col_host='\[\e[38;5;5m\]'
col_time='\[\e[38;5;6m\]'
theme_multiline=1
theme_separator=":"
theme_symbol_prefix=""
theme_max_path=40
EOF
assert_ok _limon_validate_theme_file "$USER_THEMES/allkeys.theme"

finish
