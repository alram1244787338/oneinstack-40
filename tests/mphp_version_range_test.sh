#!/bin/bash
#
# Regression test for the multi-PHP (mphp) version-range management chain.
#
# It guards the consistency the management scripts must keep across:
#   - install.sh    (--mphp_ver validation: install additional PHP)
#   - vhost.sh      (--mphp_ver validation: add a site bound to additional PHP)
#   - uninstall.sh  (--mphp_ver validation: uninstall additional PHP)
#   - include/mphp.sh (dispatch: every accepted version must have a case branch)
#
# The supported range is authoritative in install.sh: 53-56, 70-74, 80-85.
# This test extracts the *real* regex from each script (not a hard-coded copy)
# so that a future drift in any script is caught here.
#
# It performs no installation and modifies nothing on the system.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Versions that MUST be accepted (old + the newly-wired 8.2-8.5).
ACCEPT=(53 54 55 56 70 71 72 73 74 80 81 82 83 84 85)
# Inputs that MUST be rejected (boundaries, single digit, 3 digits, junk, empty).
REJECT=(52 57 69 75 79 86 90 8 800 5 7 abc "")

pass=0
fail=0

ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "  FAIL: $1"; }

# Pull the regex used on the line that validates ${mphp_ver} via =~ .
extract_mphp_regex() {
  local file="$1" line
  line=$(grep -E 'mphp_ver.*=~' "$file" | head -n1)
  [ -z "${line}" ] && return 1
  line=${line#*=~ }       # drop everything up to and including "=~ "
  line=${line%% ]]*}      # drop the trailing " ]] ..."
  printf '%s' "${line}"
}

check_script_range() {
  local label="$1" file="$2" regex v
  regex=$(extract_mphp_regex "${file}") || { bad "${label}: could not find --mphp_ver validation regex in ${file}"; return; }

  for v in "${ACCEPT[@]}"; do
    if [[ "${v}" =~ ${regex} ]]; then ok; else bad "${label}: version '${v}' should be ACCEPTED but regex rejected it"; fi
  done
  for v in "${REJECT[@]}"; do
    if [[ "${v}" =~ ${regex} ]]; then bad "${label}: input '${v}' should be REJECTED but regex accepted it"; else ok; fi
  done
}

echo "== mphp version-range regression =="
echo "repo root: ${ROOT}"

# 1) Validation ranges agree across install / add-site / uninstall.
check_script_range "install.sh"   "${ROOT}/install.sh"
check_script_range "vhost.sh"     "${ROOT}/vhost.sh"
check_script_range "uninstall.sh" "${ROOT}/uninstall.sh"

# 2) Help text matches the real supported range (no stale prompt text).
if grep -qF -- '--mphp_ver [53~85]' "${ROOT}/vhost.sh"; then ok; else bad "vhost.sh help text does not advertise [53~85]"; fi
if grep -qF -- '--mphp_ver [53~85]' "${ROOT}/uninstall.sh"; then ok; else bad "uninstall.sh help text does not advertise [53~85]"; fi

# 3) Every accepted version has a dispatch branch in include/mphp.sh
#    (catches the previously-missing 85) case that blocked installing PHP 8.5).
for v in "${ACCEPT[@]}"; do
  if grep -qE "^[[:space:]]*${v}\)" "${ROOT}/include/mphp.sh"; then ok; else bad "include/mphp.sh has no '${v})' dispatch branch"; fi
done

echo "-----------------------------------"
echo "PASS: ${pass}   FAIL: ${fail}"
[ "${fail}" -eq 0 ] || exit 1
echo "All multi-PHP version-range checks passed."
