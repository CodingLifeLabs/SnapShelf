# Harness Workflow (포인터)

이 프로젝트는 **harness-workflow 스킬**(PLANNER → GENERATOR → EVALUATOR)을 따른다.

원본 절차: `~/.claude/skills/harness-workflow/SKILL.md`

## 네이티브 Swift 적응 (본 프로젝트 특화)

이 프로젝트는 웹(Next.js/Playwright)이 아닌 **네이티브 macOS Swift** 앱이므로,
게이트를 아래와 같이 적응한다.

| 단계 | 웹 기준(원본) | SnapShelf 적응 |
|------|--------------|----------------|
| Gate 1 의존성 | dependency-direction.js (TS import) | 동일 스크립트가 Swift `import SnapShelf*` 스캔 + 컴파일러(static framework) 이중 차단 |
| Gate 2 타입 | `tsc --noEmit` | `xcodebuild build`(컴파일) |
| Gate 3 품질 | ESLint | `swiftlint lint --strict` |
| Gate 4 커버리지 | Jest 80% | `xcodebuild test -enableCodeCoverage YES` ≥ 80% |
| Gate 5 빌드 | `npm run build` | `xcodebuild build` |
| EVALUATOR | Playwright (localhost) | 빌드 + `open` + `screencapture` (+선택 XCUITest) |

## 사이클

```
PLANNER  → docs/spec.md, docs/sprints/sprint-N.md
GENERATOR → 구현 + Gate1~5 자가검증 → 전부 PASS → commit
EVALUATOR → 빌드·실행·스크린샷 검증 → sprint-N-eval.md
   PASS → 다음 Sprint /  FAIL → GENERATOR 재작업(최대 2회 → 에스컬레이션)
```
