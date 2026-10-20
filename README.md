# Tower Evolution Simulator

이그드라실 세계관(9왕국) 기반 Roblox 타워 합성 · 디펜스 시뮬레이터.

---

## Windows 에서 직접 제작하는 방법

이 저장소는 **Rojo 프로젝트**다. Studio 에서 열려면 둘 중 하나를 고른다.

### 방법 A — 완성된 플레이스 파일 열기 (가장 간단, 수정 불가)

1. **릴리즈에서 파일 받기**
   https://github.com/apple01234/tower-evolution/releases
   → 최신 `TowerEvolution-build-NN.rbxlx` 다운로드

2. **Roblox Studio 설치** (없을 때만)
   https://create.roblox.com → Download Studio

3. **파일 더블클릭** 또는 Studio 실행 후 `File > Open`

4. **Play (F5)**

> 이 방법은 열기만 된다. 스크립트를 고치면 Studio 안에서만 바뀌고
> 저장소에는 반영되지 않는다. 계속 개발하려면 방법 B.

---

### 방법 B — Rojo 로 실시간 동기화 (개발용, 권장)

Studio 와 저장소 폴더를 연결하면, **파일을 고치는 즉시 Studio 에 반영**된다.

#### 1. 필요한 프로그램 설치

| 프로그램 | 용도 | 다운로드 |
|---|---|---|
| **Roblox Studio** | 게임 편집/실행 | https://create.roblox.com |
| **Rojo** | 폴더 → Studio 동기화 | https://github.com/rojo-rbx/rojo/releases |
| **Git** | 저장소 받기 | https://git-scm.com/download/win |
| **VS Code** | 코드 편집 (권장) | https://code.visualstudio.com |

Rojo 는 릴리즈에서 `rojo-<버전>-windows-x86_64.zip` 을 받아 압축을 풀고,
`rojo.exe` 를 `C:\tools\` 같은 폴더에 두면 된다.

#### 2. 저장소 받기

PowerShell 을 열고:

```powershell
cd $HOME\Desktop
git clone https://github.com/apple01234/tower-evolution.git
cd tower-evolution
```

#### 3. Rojo 플러그인 설치 (Studio 쪽)

Studio 실행 → 상단 **Plugins** 탭 → **Manage Plugins** →
**Find Plugins** → `Rojo` 검색 → Install

또는 Releases 의 `Rojo.rbxm` 을
`%LOCALAPPDATA%\Roblox\Plugins\` 에 넣고 Studio 재시작.

#### 4. 서버 켜기

저장소 폴더에서 PowerShell:

```powershell
C:\tools\rojo.exe serve
```

이 창은 **닫지 않는다.** 이렇게 뜨면 성공:
```
Rojo server listening on 127.0.0.1:34872
```

#### 5. Studio 에서 연결

1. Studio 실행 → **빈 Baseplate** 새로 만들기 (또는 아무 곳)
2. Plugins 탭 → **Rojo** 클릭
3. `localhost:34872` → **Connect**
4. Explorer 에 `Workspace`, `ReplicatedStorage`, `ServerScriptService` 등이 채워짐

이제 VS Code 에서 `.luau` 파일을 고치면 **Studio 에 즉시 반영**된다.

#### 6. 실행

**Play (F5)** → 서버/클라이언트 스크립트가 돌아간다.

---

## 폴더 구조

```
tower-evolution/
├─ default.project.json    Rojo 설정 (어디에 무엇을 넣을지)
├─ src/
│  ├─ shared/              ReplicatedStorage.Shared (공용, 17개)
│  │   Config.luau           모든 수치 (밸런스는 전부 여기)
│  │   TowerData.luau        진화 트리 (분기 포함 15종)
│  │   FamilyArcane.luau     아케인 계열 (102줄)
│  │   FamilyFrost.luau      서리 계열
│  │   FamilyInferno.luau    화염 계열
│  │   Combat.luau           순수 전투 계산 (Roblox 무의존)
│  │   Inventory.luau        합성 규칙 · 원자성
│  │   Lore.luau             9왕국 · 보스 9종
│  │   LoreData.luau         세계관 데이터
│  │   Missions.luau         일일/주간 미션 8종
│  │   Progress.luau         성장 기록
│  │   Net.luau              RemoteEvent 정의
│  │   Anim.luau             절차적 애니메이션
│  │   AssetCatalog.luau     에셋 ID 표
│  │   MapThemes.luau        지역별 테마
│  │   TowerDefs.luau        타워 정의 조립
│  │   CoopBoss.luau         협동 보스 규칙
│  ├─ server/              ServerScriptService.Server (16개)
│  │   init.server.luau      진입점 (Script)
│  │   Battle.luau           조립자
│  │   BattleState.luau      공유 상태
│  │   Waves.luau            웨이브 진행
│  │   EnemyManager.luau     적 생성/이동
│  │   TowerCombat.luau      타워 공격
│  │   TowerModel.luau       타워 모델 배치
│  │   AssetLoader.luau      에셋 로드 (구운 것 우선)
│  │   Save.luau             DataStore
│  │   Sanitize.luau         데이터 정규화
│  │   HandlersInventory.luau 소환/합성/배치 검증
│  │   HandlersGrowth.luau    환생/연구/지역
│  │   WorldSetup.luau       맵 생성
│  │   MapDecor.luau         장식 배치
│  │   CoopBossServer.luau   협동 보스
│  │   Diag.luau             진단 (화면에 서버 상태 표시)
│  └─ client/              StarterPlayerScripts.Client (9개)
│      init.client.luau      진입점 (LocalScript)
│      UiKit.luau            UI 공용 유틸
│      Hud.luau              골드/웨이브/기지
│      InventoryPanel.luau   보유 타워 패널
│      TowerCard.luau        타워 카드 1칸
│      GrowthPanel.luau      환생/연구 패널
│      MissionPanel.luau     미션 패널
│      CoopHud.luau          협동 보스 HUD
│      BranchDialog.luau     분기 선택 팝업
├─ assets_fresh/            마켓플레이스 원본 25개 (.rbxm)
├─ assets_fresh_clean/      스크립트 제거본 (Studio 에 들어가는 것)
├─ workspace_baked/         Workspace 에 구운 맵
├─ tests/                   Lune 테스트 14개
└─ tools/                   빌드 도구 (에셋 정리, 맵 굽기)
```

---

## 코드 고치는 곳

| 하고 싶은 것 | 고칠 파일 |
|---|---|
| **밸런스 조정** (골드, 체력, 속도) | `src/shared/Config.luau` |
| **타워 추가** | `src/shared/FamilyArcane.luau` 등 |
| **적 체력/속도** | `src/shared/Combat.luau` |
| **웨이브 수/보스 주기** | `src/shared/Config.luau` |
| **지역/보스 이름** | `src/shared/LoreData.luau` |
| **맵 모양** | `src/shared/Config.luau` 의 `PATH` + `tools/bake-workspace.luau` |
| **UI 색/크기** | `src/client/Hud.luau`, `InventoryPanel.luau` |
| **미션 내용** | `src/shared/Missions.luau` |

### 수치 바꾸는 예시

`src/shared/Config.luau`:

```lua
Config.START_GOLD = 500      -- 시작 골드
Config.SUMMON_COST = 50      -- 소환 비용
Config.BASE_HP = 100         -- 기지 체력
Config.WAVE_BREAK_SECONDS = 6 -- 웨이브 간격
Config.BOSS_EVERY = 5        -- 5웨이브마다 보스
```

파일 저장 → Studio 에 즉시 반영 → **Play** 로 확인.

---

## 검증 (선택)

Lune 이 있으면 Studio 없이 로직을 돌려볼 수 있다.

```powershell
# Lune 설치
winget install lune

# 전체 검증
winget install rojo
rojo build -o TowerEvolution.rbxlx
lune run tests/logic.test.luau
lune run tests/lore.test.luau
lune run tests/missions.test.luau
lune run tests/structure.test.luau .
lune run tests/world.test.luau .
lune run tests/assetclass.test.luau assets_fresh_clean
lune run tests/syntax.test.luau TowerEvolution.rbxlx
```

현재 통과 상태: 문법 42/42, 구조 5/5, 에셋클래스 25/25, 월드 7/7,
로직 772개, 규칙 42/42.

---

## 게시 (Roblox 에 올리기)

### Studio 에서 직접 (가장 쉬움)

1. **File → Publish to Roblox**
2. 이름/설명 입력 → **Create**
3. 이후 수정할 때마다 **File → Publish to Roblox** (Ctrl+Alt+P)

### API 로 자동 게시

GitHub Actions 에 이미 구성돼 있다. `.github/workflows/build.yml` 참고.
저장소 Settings → Secrets 에 `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`,
`ROBLOX_PLACE_ID` 를 넣으면 push 시 자동 빌드된다.

> 자동 게시는 `workflow_dispatch` + `publish=true` 로 수동 실행할 때만 돈다.

---

## 게임 구조 요약

### 타워 진화 (3계열 × 4단계 + 4단계 분기 2개 = 15종)

| 계열 | 1단계 | 2단계 | 3단계 | 4단계 (분기) |
|---|---|---|---|---|
| 아케인 | 견습 포탑 | 수정 포탑 | 아케인 포병 | 성운의 지배자 / 심판자 |
| 서리 | 서리 파편 | 빙하 첨탑 | 영구 동토 | 절대영도 / 서리 수호자 |
| 화염 | 불씨 포탑 | 화염 창 | 용암 대포 | 최후의 심판 / 화염 대장장이 |

### 9왕국 진행

미드가르드(2) → 쿠소디아(3) → 알프헤임(4) → 무스펠헤임(5) → 니플헤임(6)
→ 스바르트알프헤임(7) → 니다벨리르(8) → 헬(9) → 세계수의 뿌리(10)

최종 보스: **종언의 마룡 아부디토스**

### 핵심 시스템

- **합성**: 같은 타워 3개 → 다음 단계 1개. 서버가 검증.
- **분기**: 4단계에서 두 갈래 중 선택 (`BranchDialog`).
- **환생**: 조건 충족 시 초기화 + 영구 연구 포인트.
- **미션**: 일일/주간 8종, UTC 자정/월요일 리셋.
- **협동 보스**: 45초마다 등장, 전원 참여.

---

## 설계 원칙

- **서버 권한**: 재화·피해·합성·보상 전부 서버 결정. 클라이언트는 요청만.
- **원자성**: `Inventory.fuse()` 는 검증만, 상태 변경은 `commitFuse()`.
- **중복 보상 차단**: 적 사망 시 `alive=false` 를 즉시 내린다.
- **요청 제한**: `Config.RATE` 로 액션별 초당 호출 제한.
- **에셋 폴백**: 마켓플레이스 모델 로드 실패 시 파트로 대체. 게임이 멈추지 않는다.
- **에셋 보안**: 외부 모델의 `Script`/`RemoteEvent` 는 로드 전에 제거한다
  (`tools/sanitize-assets.luau`). 서드파티 코드 실행 차단.

---

## 문제 해결

| 증상 | 확인 |
|---|---|
| Studio 에 아무것도 안 보임 | Rojo Connect 했는지, `rojo serve` 창이 살아있는지 |
| `WaitForChild` 무한 대기 | 모듈이 제대로 복제됐는지 Explorer 확인 |
| 에셋이 회색/투명 | 원본 모델의 MeshId/TextureId 로드 실패 (인터넷 확인) |
| `ServerDiag` 파트에 FAIL | 그 줄이 원인. 서버 로그에도 같은 내용이 뜬다 |
| 웨이브가 0에서 안 올라감 | `ServerDiag` 의 `beat=` 값 확인. 안 올라가면 Heartbeat 정지 |

### 진단 도구

게임 실행 중 **Workspace > ServerDiag** 파트에 서버 상태가 실시간으로 뜬다:

```
OK   WorldSetup.build
OK   TowerArena (8 children)
OK   Waves.run 스폰됨
OK   Heartbeat 첫 프레임
beat=180 wave=1 enemies=4 towers=0
```

`FAIL` 이 있는 줄이 문제 지점이다.
