#!/usr/bin/env bash
# 同步 game/ 开发目录的源码到仓库根目录（提交用）。
# 用法: ./sync.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== 同步 game/ -> 仓库根目录 =="

# Godot 项目源码（扁平化到根目录）
cp -r game/scenes/. scenes/
cp -r game/scripts/. scripts/
cp game/project.godot project.godot
cp game/icon.svg icon.svg 2>/dev/null || true
cp game/icon.svg.import icon.svg.import 2>/dev/null || true
cp game/CLAUDE.md CLAUDE.md 2>/dev/null || true

# 资源（贴图/音频等，如存在）
if [ -d game/assets ] && [ -n "$(ls -A game/assets 2>/dev/null)" ]; then
	mkdir -p assets
	cp -r game/assets/. assets/
fi

echo "完成。可用 git status 查看待提交变更。"
