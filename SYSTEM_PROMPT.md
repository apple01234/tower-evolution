# SYSTEM_PROMPT.md — Tower Evolution 개발 규칙

이 저장소에 기여하는 모든 AI 에이전트 및 개발자는 아래 규칙을 따른다.
근거: 마스터 AI 개발 지시서 사양서 (2026-10-19 적용).

## 0. 이 프로젝트의 예외 (명시적 허용)

지시서 기본값과 다른 부분을 **근거와 함께** 기록한다. 근거 없는 예외는 금지.

| 지시서 항목 | 이 프로젝트 적용 | 근거 |
|---|---|---|
| TypeScript strict | **Luau `--!strict`** | Roblox 런타임 언어. TS 불가 |
| Jest / Vitest | **Lune** | Roblox엔 Node 없음. Lune이 유일한 헤드리스 러너 |
| `any` 타입 금지 | `--!strict` + 명시적 타입 / 불가피 시 `any` 1줄 사유 주석 | Luau `any`는 런타임 안전망으로 허용 |
| camelCase | **PascalCase 파일**, camelCase 함수/변수 | Luau/Roblox 관례 |
| `.cursorrules` | 이 파일 + `AGENTS.md` | 환경별 규칙 파일 단일화 |

## 1. 파일 크기 제한 (SRP)

- **단일 소스 파일 250줄 초과 금지.**
- 초과 시 책임 단위로 분리한다. 분리 전 임의 삭제 금지.
- 검사: `./verify.sh` 의 규칙 검사 단계가 자동 판정한다.

## 2. 선 인터페이스, 후 구현

1. 데이터 구조(`export type`)와 함수 시그니처를 먼저 확정한다.
2. 로직을 채운다.
3. 순수 로직은 Roblox API를 `require` 하지 않는다 → Lune 테스트 가능.

## 3. 매직 넘버 금지

밸런스 수치·비용·배율은 `src/shared/Config.luau` 또는 각 도메인 모듈의 상단 정의에만 둔다.
`Lore.luau`, `TowerData.luau`, `Missions.DEFS`, `Progress.RESEARCH` 는 데이터 정의 파일로 간주한다.

## 4. 에러 처리

- `InsertService:LoadAsset`, `DataStore` 호출은 반드시 `pcall`.
- 실패 시 **폴백**을 두거나 명시적 반환값(`nil`/`false` + 사유 문자열)을 준다.
- `warn` 은 접두어 `[모듈명]` 필수.

## 5. 서버 권한 (최우선)

- RemoteEvent 핸들러는 **전부 공격자 제어 입력**으로 취급한다.
- 핸들러마다: (1) rate limit (2) 타입 검증 (3) 서버 재계산 (4) 검증/커밋 분리.
- 클라이언트가 보낸 재화·피해·보상 수치는 절대 신뢰하지 않는다.

## 6. 전역 오염 금지

`_G.*` 사용 금지. 모듈 간 참조는 명시적 `require` 또는 주입(`Save._events`)으로 한다.

## 7. 공식 문서 우선

- Roblox API는 `setup.rbxcdn.com/<version>-API-Dump.json` 으로 시그니처를 기계 검증한다.
- 문서 페이지: https://create.roblox.com/docs/reference/engine
- 폐기(deprecated) API를 쓰지 않는다. 예: `InsertService:GetFreeModelsAsync` 는 현행 덤프에 없음.

## 8. 검증 없이 "완료" 금지

다음을 모두 통과해야 보고 가능:
1. `./verify.sh` 전체 통과 (빌드 + 문법 + 규칙 + 단위 테스트)
2. 실제 게시(선택) 후 버전 번호 확인

**Studio 실플레이·UI 렌더링은 이 환경에서 검증 불가 → 항상 "미검증"으로 표기한다.**
