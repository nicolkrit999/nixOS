#!/usr/bin/env bash
# run-tests.sh - run all NixOS and Darwin tests locally.
# Run from anywhere; the script resolves the repo root automatically.
#
# Usage:
#   bash templates/tests/run-tests.sh [--parallel] [--fast]
#
#   --parallel   run all tests concurrently instead of sequentially (faster,
#                but if nicol-nas is offline, parallel nix processes will each
#                print "could not resolve nicol-nas" retry warnings - harmless,
#                but noisy; prefer sequential when the NAS is unreachable)
#   --fast       pass --fast to arch-compat, skipping specialisation batches

set -uo pipefail

PARALLEL=0
FAST=""
for arg in "$@"; do
  case "$arg" in
    --parallel) PARALLEL=1 ;;
    --fast)     FAST="--fast" ;;
  esac
done

# ══════════════════════════════════════════════════════════════════════════════
#  TEST REGISTRY  ← add / remove tests here, one line each
#
#  Format:  "Display label | command"
#  Commands are run from the repo root.
# ══════════════════════════════════════════════════════════════════════════════
# The nix-tests harness is an external flake whose own nixpkgs pin is older than
# the nixpkgs fix for crates.io's User-Agent block: crates.io now returns HTTP 403
# for curl-like UAs on `https://crates.io/api/v1/crates/<c>/<v>/download`, which is
# the URL that older `importCargoLock` used. Current nixpkgs fetches crates from
# `https://static.crates.io/crates` instead, so we force nix-tests to build against
# *our* locked nixpkgs. Without this, building the harness fails before any test runs.
NIX_TESTS="nix run github:danielefongo/nix-tests --inputs-from . --override-input nixpkgs nixpkgs --"

TESTS=(
  "NixOS  · minimal-defaults      | bash templates/tests/nixos/test-minimal-defaults/check-nixos-minimal-defaults.sh"
  "NixOS  · spec-contract         | bash templates/tests/nixos/test-spec-contract/check-nixos-spec-contract.sh"
  "NixOS  · conflicting-modules   | $NIX_TESTS templates/tests/nixos/conflicting-modules"
  "NixOS  · custom-shells         | $NIX_TESTS templates/tests/nixos/test-custom-shells"
  "NixOS  · arch-compat (aarch64) | bash templates/tests/nixos/test-arch-compat/check-nixos-aarch64-compat.sh${FAST:+ $FAST}"
  "NixOS  · wallpapers            | $NIX_TESTS templates/tests/nixos/test-nixos-wallpapers"
  "Darwin · minimal-defaults      | bash templates/tests/darwin/test-minimal-defaults/check-darwin-minimal-defaults.sh"
)
# ══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Result accumulators (populated by runners)
LABELS=()
STATUSES=()

# ─────────────────────────────────────────────────────────────────────────────
run_sequential() {
  for entry in "${TESTS[@]}"; do
    local label="${entry%%|*}"
    local cmd
    cmd="$(echo "${entry#*|}" | sed 's/^[[:space:]]*//')"
    LABELS+=("$label")

    echo -e "\n${BOLD}━━━ $label ━━━${NC}"
    local rc=0
    bash -c "$cmd" || rc=$?
    STATUSES+=("$rc")
    [[ $rc -eq 0 ]] && echo -e "${GREEN}✓ passed${NC}" || echo -e "${RED}✗ failed${NC}"
  done
}

# ─────────────────────────────────────────────────────────────────────────────
run_parallel() {
  local -a tmpfiles=() pids=()

  for entry in "${TESTS[@]}"; do
    local label="${entry%%|*}"
    local cmd
    cmd="$(echo "${entry#*|}" | sed 's/^[[:space:]]*//')"
    LABELS+=("$label")

    local tmp
    tmp="$(mktemp)"
    tmpfiles+=("$tmp")

    echo -e "${DIM}⏳  $label${NC}"
    bash -c "$cmd" >"$tmp" 2>&1 &
    pids+=("$!")
  done

  echo ""

  # Collect exit codes in submission order
  for i in "${!pids[@]}"; do
    local rc=0
    wait "${pids[$i]}" || rc=$?
    STATUSES+=("$rc")
  done

  # Replay buffered output in order
  for i in "${!LABELS[@]}"; do
    echo -e "\n${BOLD}━━━ ${LABELS[$i]} ━━━${NC}"
    cat "${tmpfiles[$i]}"
    rm -f "${tmpfiles[$i]}"
    [[ ${STATUSES[$i]} -eq 0 ]] \
      && echo -e "${GREEN}✓ passed${NC}" \
      || echo -e "${RED}✗ failed${NC}"
  done
}

# ─────────────────────────────────────────────────────────────────────────────
print_summary() {
  local pass=0 fail=0
  local -a failed_labels=()

  for i in "${!LABELS[@]}"; do
    if [[ ${STATUSES[$i]} -eq 0 ]]; then
      ((pass++)) || true
    else
      ((fail++)) || true
      failed_labels+=("${LABELS[$i]}")
    fi
  done

  local total=$(( pass + fail ))

  echo -e "\n${DIM}══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD} Results${NC}"
  echo -e "${DIM}──────────────────────────────────────────────────────────${NC}"
  for i in "${!LABELS[@]}"; do
    if [[ ${STATUSES[$i]} -eq 0 ]]; then
      echo -e "  ${GREEN}✓${NC}  ${LABELS[$i]}"
    else
      echo -e "  ${RED}✗${NC}  ${LABELS[$i]}"
    fi
  done
  echo -e "${DIM}──────────────────────────────────────────────────────────${NC}"

  if [[ $fail -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All $total tests passed.${NC}"
    echo -e "${DIM}══════════════════════════════════════════════════════════${NC}\n"
    return 0
  else
    echo -e "  ${RED}${BOLD}$fail of $total tests failed:${NC}"
    for l in "${failed_labels[@]}"; do
      echo -e "    ${RED}✗  $l${NC}"
    done
    echo -e "${DIM}══════════════════════════════════════════════════════════${NC}\n"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
mode="sequential"
[[ $PARALLEL -eq 1 ]] && mode="parallel"

echo -e "\n${BOLD}Running ${#TESTS[@]} tests ($mode)${NC}"
[[ -n "$FAST" ]] && echo -e "${DIM}arch-compat: --fast mode (specialisations skipped)${NC}"
echo ""

if [[ $PARALLEL -eq 1 ]]; then
  run_parallel
else
  run_sequential
fi

print_summary
