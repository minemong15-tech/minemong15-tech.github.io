#!/usr/bin/env bash
# ZONE · M → GitHub Pages 배포 스크립트
# 저장소가 이미 존재할 때 실행: remote 설정 → push → Pages 확인/활성화 → URL 응답 확인
set -uo pipefail

OWNER="minemong15-tech"
REPO="minemong15-tech.github.io"
SITE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== 1. 저장소 확인 =="
if ! gh api "repos/$OWNER/$REPO" --jq '.full_name + " | private=" + (.private|tostring) + " | default=" + .default_branch' 2>/dev/null; then
  echo "FAIL: $OWNER/$REPO 저장소가 없습니다."
  exit 10
fi

echo "== 2. remote 설정 및 push =="
cd "$SITE_DIR"
git remote remove origin 2>/dev/null
git remote add origin "https://github.com/$OWNER/$REPO.git"
git push -u origin main 2>&1 | tail -5 || { echo "FAIL: push 실패"; exit 11; }

echo "== 3. Pages 상태 확인 =="
if gh api "repos/$OWNER/$REPO/pages" --jq '.status + " | " + .html_url' 2>/dev/null; then
  echo "Pages 이미 설정됨"
else
  echo "Pages 미설정 → 활성화 시도"
  gh api -X POST "repos/$OWNER/$REPO/pages" \
    -f 'source[branch]=main' -f 'source[path]=/' \
    --jq '.html_url' 2>&1 || echo "POST /pages 실패(권한) — .github.io 저장소는 자동 활성화될 수 있음"
fi

echo "== 4. 배포 대기 및 URL 확인 =="
for i in $(seq 1 30); do
  zo=$(curl -s -o /dev/null -w '%{http_code}' "https://$OWNER.github.io/zone/")
  m=$(curl -s -o /dev/null -w '%{http_code}' "https://$OWNER.github.io/m/")
  rt=$(curl -s -o /dev/null -w '%{http_code}' "https://$OWNER.github.io/")
  echo "[$i] /zone/=$zo /m/=$m /=$rt"
  if [ "$zo" = "200" ] && [ "$m" = "200" ] && [ "$rt" = "200" ]; then
    echo "OK: https://$OWNER.github.io/zone/  https://$OWNER.github.io/m/"
    exit 0
  fi
  sleep 10
done
echo "TIMEOUT: 아직 200 아님 (Pages 최초 빌드는 몇 분 걸릴 수 있음)"
exit 12
