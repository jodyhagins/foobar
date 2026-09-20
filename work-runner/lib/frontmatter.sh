# frontmatter.sh -- read and write the YAML header of a work item.  Sourced.
#
# A header is the block between a first line of `---` and the next line
# of `---`.  Only flat `key: value` pairs are understood; that is all a
# work item needs, and it keeps the implementation to a few lines of awk
# rather than a YAML library.  A value may be wrapped in double quotes,
# which are stripped on read.
#
#   fm_has  FILE          true when FILE starts with a header
#   fm_get  FILE KEY      print KEY's value, or nothing
#   fm_set  FILE KEY VAL  replace KEY's value in place, or add the key
#   fm_body FILE          print everything after the header

fm_has() {
    [ "$(head -n 1 "$1" 2>/dev/null)" = "---" ]
}

fm_get() {
    fm_has "$1" || return 0
    FM_KEY="$2" awk '
        NR == 1 { next }
        /^---$/ { exit }
        {
            i = index($0, ":")
            if (i > 0 && substr($0, 1, i - 1) == ENVIRON["FM_KEY"]) {
                v = substr($0, i + 1)
                sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
                if (length(v) >= 2 && substr(v, 1, 1) == "\"" && substr(v, length(v), 1) == "\"")
                    v = substr(v, 2, length(v) - 2)
                print v
                exit
            }
        }' "$1"
}

fm_set() {
    local file="$1" tmp="$1.fm.$$"
    if ! fm_has "$file"; then
        { printf -- '---\n%s: %s\n---\n' "$2" "$3"; cat "$file"; } > "$tmp"
        mv "$tmp" "$file"
        return 0
    fi
    FM_KEY="$2" FM_VAL="$3" awk '
        BEGIN { inhdr = 0; done = 0 }
        NR == 1 { inhdr = 1; print; next }
        inhdr && /^---$/ {
            if (!done) { print ENVIRON["FM_KEY"] ": " ENVIRON["FM_VAL"]; done = 1 }
            inhdr = 0; print; next
        }
        inhdr {
            i = index($0, ":")
            if (i > 0 && substr($0, 1, i - 1) == ENVIRON["FM_KEY"]) {
                if (!done) { print ENVIRON["FM_KEY"] ": " ENVIRON["FM_VAL"]; done = 1 }
                next
            }
        }
        { print }' "$file" > "$tmp"
    mv "$tmp" "$file"
}

fm_body() {
    awk '
        NR == 1 && $0 == "---" { inhdr = 1; next }
        inhdr { if ($0 == "---") inhdr = 0; next }
        { print }' "$1"
}
