#!/usr/bin/env bash
# 전체 검증 파이프라인: 빌드 → 문법 → 로직 → 세계관
# 사용: ./verify.sh
set -uo pipefail
cd "$(dirname "$0")"

LUNE=/root/workspace/.tools/lune/lune
ROJO=/root/workspace/.tools/rojo/rojo
FAIL=0

echo "=============================================="
echo " 1/10  Rojo 빌드"
echo "=============================================="
if $ROJO build -o TowerEvolution.rbxlx > /tmp/rojo.log 2>&1; then
	echo "PASS  빌드 성공 ($(stat -c%s TowerEvolution.rbxlx) bytes)"
else
	echo "FAIL  빌드 실패"; tail -20 /tmp/rojo.log; FAIL=1
fi

echo
echo "=============================================="
echo " 2/10  스크립트 문법 검증"
echo "=============================================="
if $LUNE run tests/syntax.test.luau TowerEvolution.rbxlx > /tmp/syntax.log 2>&1; then
	grep -E "=====" /tmp/syntax.log | sed 's/^/PASS  /'
else
	echo "FAIL  문법 오류"; grep -A3 "FAIL" /tmp/syntax.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 3/10  핵심 로직 테스트"
echo "=============================================="
if $LUNE run tests/logic.test.luau > /tmp/logic.log 2>&1; then
	grep -E "=====" /tmp/logic.log | sed 's/^/PASS  /'
else
	echo "FAIL  로직 테스트"; grep -B1 -A1 "FAIL" /tmp/logic.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 4/10  세계관 데이터 테스트"
echo "=============================================="
if $LUNE run tests/lore.test.luau > /tmp/lore.log 2>&1; then
	grep -E "=====" /tmp/lore.log | sed 's/^/PASS  /'
else
	echo "FAIL  세계관 테스트"; grep -B1 -A1 "FAIL" /tmp/lore.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 5/10  성장 시스템 테스트 (환생/연구/도감/지역)"
echo "=============================================="
if $LUNE run tests/progress.test.luau > /tmp/progress.log 2>&1; then
	grep -E "=====" /tmp/progress.log | sed 's/^/PASS  /'
else
	echo "FAIL  성장 시스템 테스트"; grep -B1 -A1 "FAIL" /tmp/progress.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 6/10  미션 시스템 테스트 (일일/주간)"
echo "=============================================="
if $LUNE run tests/missions.test.luau > /tmp/missions.log 2>&1; then
	grep -E "=====" /tmp/missions.log | sed 's/^/PASS  /'
else
	echo "FAIL  미션 테스트"; grep -B1 -A1 "FAIL" /tmp/missions.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 7/10  3계열 확장 + 둔화 테스트"
echo "=============================================="
if $LUNE run tests/expansion.test.luau > /tmp/expansion.log 2>&1; then
	grep -E "=====" /tmp/expansion.log | sed 's/^/PASS  /'
else
	echo "FAIL  확장 테스트"; grep -B1 -A1 "FAIL" /tmp/expansion.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 8/10  분기 진화 테스트"
echo "=============================================="
if $LUNE run tests/branch.test.luau > /tmp/branch.log 2>&1; then
	grep -E "=====" /tmp/branch.log | sed 's/^/PASS  /'
else
	echo "FAIL  분기 테스트"; grep -B1 -A1 "FAIL" /tmp/branch.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 9/10  맵 테마 테스트 (9왕국)"
echo "=============================================="
if $LUNE run tests/map.test.luau > /tmp/map.log 2>&1; then
	grep -E "=====" /tmp/map.log | sed 's/^/PASS  /'
else
	echo "FAIL  맵 테스트"; grep -B1 -A1 "FAIL" /tmp/map.log | head -40; FAIL=1
fi

echo
echo "=============================================="
echo " 10/10  코드 규칙 검사 (SYSTEM_PROMPT.md)"
echo "=============================================="
if $LUNE run tests/rules.test.luau > /tmp/rules.log 2>&1; then
	grep -E "규칙 통과|규칙 검사 통과" /tmp/rules.log | sed 's/^/PASS  /'
else
	echo "FAIL  규칙 위반"
	grep -A20 "\[위반 목록\]" /tmp/rules.log | head -20
	FAIL=1
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
