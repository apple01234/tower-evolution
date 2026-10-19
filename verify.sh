#!/usr/bin/env bash
# 전체 검증 파이프라인: 빌드 → 문법 → 로직 → 세계관
# 사용: ./verify.sh
set -uo pipefail
cd "$(dirname "$0")"

LUNE=/root/workspace/.tools/lune/lune
ROJO=/root/workspace/.tools/rojo/rojo
FAIL=0

echo "=============================================="
echo " 1/4  Rojo 빌드"
echo "=============================================="
if $ROJO build -o TowerEvolution.rbxlx > /tmp/rojo.log 2>&1; then
	echo "PASS  빌드 성공 ($(stat -c%s TowerEvolution.rbxlx) bytes)"
else
	echo "FAIL  빌드 실패"; tail -20 /tmp/rojo.log; FAIL=1
fi

echo
echo "=============================================="
echo " 2/4  스크립트 문법 검증"
echo "=============================================="
if $LUNE run tests/syntax.test.luau TowerEvolution.rbxlx > /tmp/syntax.log 2>&1; then
	grep -E "=====" /tmp/syntax.log | sed 's/^/PASS  /'
else
	echo "FAIL  문법 오류"; grep -A3 "FAIL" /tmp/syntax.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 3/4  핵심 로직 테스트"
echo "=============================================="
if $LUNE run tests/logic.test.luau > /tmp/logic.log 2>&1; then
	grep -E "=====" /tmp/logic.log | sed 's/^/PASS  /'
else
	echo "FAIL  로직 테스트"; grep -B1 -A1 "FAIL" /tmp/logic.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 4/4  세계관 데이터 테스트"
echo "=============================================="
if $LUNE run tests/lore.test.luau > /tmp/lore.log 2>&1; then
	grep -E "=====" /tmp/lore.log | sed 's/^/PASS  /'
else
	echo "FAIL  세계관 테스트"; grep -B1 -A1 "FAIL" /tmp/lore.log | head -40; FAIL=1
fi

echo
if [ $FAIL -eq 0 ]; then
	echo "##############################################"
	echo "#  전체 검증 통과"
	echo "##############################################"
else
	echo "##############################################"
	echo "#  검증 실패 — 위 로그 확인"
	echo "##############################################"
fi
exit $FAIL
