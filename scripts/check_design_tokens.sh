#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
hits="$(grep -rEn 'Color\((red:|\.sRGB)' Sources/TextFlash --include='*.swift' --exclude='SoftTheme.swift' || true)"
if [[ -n "$hits" ]]; then
  echo "发现绕过 SoftTheme 的颜色字面量：" >&2
  echo "$hits" >&2
  exit 1
fi
echo "设计 token 检查通过：颜色字面量已收敛到 SoftTheme.swift。"
