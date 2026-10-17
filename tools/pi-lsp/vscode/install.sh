#!/usr/bin/env bash
set -euo pipefail

extension_id="rizu.rizu-pi-lsp-bridge-0.1.0"
extension_root="${HOME}/.vscode/extensions"
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${extension_root}/${extension_id}"

mkdir -p "${extension_root}"
rm -rf "${target_dir}"
mkdir -p "${target_dir}"
cp "${source_dir}/package.json" "${source_dir}/extension.js" "${target_dir}/"

printf 'Installed Pi LSP Bridge to %s\n' "${target_dir}"
printf 'In VS Code, run "Developer: Reload Window" once.\n'
