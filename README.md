# Tower Evolution Simulator

이그드라실 세계관(9왕국) 기반 Roblox 타워 합성 · 디펜스 시뮬레이터.
SERTZ/CERTZ 원본에서 **세계관(지역명·보스명·스토리)만** 차용했고, 게임 구조는 완전히 별개다.

## 현재 상태

| 항목 | 상태 |
|---|---|
| Rojo 빌드 | PASS — `TowerEvolution.rbxlx` (54KB) |
| 스크립트 문법 | PASS — 11/11 |
| 핵심 로직 테스트 | PASS — 40/40 |
| 세계관 데이터 테스트 | PASS — 93/93 |
| Studio 실플레이 | **미검증** (이 환경에 Studio 없음) |
| 실제 게시 | **미완료** (API 키 필요) |

## 실행 / 검증

```bash
./verify.sh          # 빌드 + 문법 + 로직 + 세계관 전체 검증
```

개별 실행:
```bash
/root/workspace/.tools/rojo/rojo build -o TowerEvolution.rbxlx
/root/workspace/.tools/lune/lune run tests/logic.test.luau
/root/workspace/.tools/lune/lune run tests/lore.test.luau
/root/workspace/.tools/lune/lune run tests/syntax.test.luau TowerEvolution.rbxlx
```

## 구조

```
src/
  shared/          ReplicatedStorage.Shared
    Config.luau      중앙 밸런스 (수치는 전부 여기)
    TowerData.luau   타워 4단계 진화 트리
    Combat.luau      순수 전투 계산 (Roblox API 무의존)
    Inventory.luau   합성 규칙 · 원자성 보장
    Lore.luau        이그드라실 9왕국 · 보스 9종
    Net.luau         RemoteEvent 정의
  server/          ServerScriptService.Server
    init.server.luau 진입점
    Save.luau        DataStore 저장/로드
    Battle.luau      웨이브 · 적 · 타워 · 검증
    WorldSetup.luau  맵/경로 생성
  client/          StarterPlayerScripts.Client
    init.client.luau HUD · 인벤토리 · 합성 UI
tests/             Lune 헤드리스 테스트
```

## 설계 원칙

- **서버 권한**: 재화·피해·합성·보상 전부 서버 결정. 클라이언트는 요청만.
- **원자성**: `Inventory.fuse()`는 검증만, 상태 변경은 `commitFuse()`에서. 이중 커밋 차단.
- **중복 보상 차단**: 적 사망 시 `alive=false`를 즉시 내려 재타격 불가.
- **요청 제한**: `Config.RATE`로 액션별 초당 호출 제한.
- **데이터 격리**: 세계관(`Lore`)이 전투 밸런스에 영향 없음 (테스트로 검증).

## 타워 진화 트리 (MVP)

| 단계 | 이름 | DPS | 사거리 | 공격 방식 |
|---|---|---|---|---|
| 1 | 견습 포탑 | 10.0 | 14 | 단일 |
| 2 | 수정 포탑 | 31.2 | 16 | 관통 3 |
| 3 | 아케인 포병 | 55.8 | 19 | 연쇄 3 |
| 4 | 성운의 지배자 | 126.0 | 22 | 광역 9 |

## 이그드라실 9왕국

미드가르드(2) → 쿠소디아(3) → 알프헤임(4) → 무스펠헤임(5) → 니플헤임(6)
→ 스바르트알프헤임(7) → 니다벨리르(8) → 헬(9) → 세계수의 뿌리(10)

최종 보스: **종언의 마룡 아부디토스**

## 미구현 (다음 단계)

- 환생 · 영구 연구
- 진화 도감 UI
- 지역 이동 UI
- 일일/주간 미션
- 업그레이드 시스템 (현재 알림만)
- 실제 아트 에셋 (현재 파트 임시 모델)
- Studio 실플레이 검증
