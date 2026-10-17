# b1-2 — 시스템 장애 분석 및 이슈 리포트

제공된 Linux amd64 바이너리 `agent-leak-app-x86`으로 OOM·CPU·Deadlock을
재현하고, 관제 로그와 Before/After 비교를 GitHub Issue 형식으로 정리한다.

## 제출 자료

| 장애 | 리포트 | 변경 설정 |
| --- | --- | --- |
| OOM | [01-oom-memory-leak.md](reports/01-oom-memory-leak.md) | `MEMORY_LIMIT` 128 → 512 |
| CPU | [02-cpu-spike.md](reports/02-cpu-spike.md) | `CPU_MAX_OCCUPY` 90 → 40 |
| Deadlock | [03-deadlock.md](reports/03-deadlock.md) | `MULTI_THREAD_ENABLE` true → false |

[이슈 양식](reports/issue-template.md) · [검증 결과와 한계](reports/validation.md)

`evidence/`의 `oom_before`, `oom_after`, `cpu_before`, `cpu_after`,
`deadlock_before`, `deadlock_after`가 필수 6개 실행의 원본 증거다.
각 폴더에 앱 로그, `monitor.sh` 관제 로그, 실행 설정·종료 코드(`run.log`),
관측 만료 시 스레드 스냅샷이 있다. `validation/`에는 검증 명령의 실행 기록이 있다.

## macOS + OrbStack에서 실행

```bash
./orbstack-machine.sh demo
```

amd64 Ubuntu VM을 생성·시작하고 일반 사용자 `agent` 환경을 구성한 뒤,
필수 6개 실행 → 증거 검사 → 로컬 회수를 수행한다. VM 이름은 기본 `b1-2-agent`이며
`MACHINE_NAME`으로 변경할 수 있다. 실행에는 약 4~5분이 걸리며 최초 VM 설치 시간은 별도다.

```bash
./orbstack-machine.sh provision  # VM 시작 및 필수 계정·파일·환경 구성
./orbstack-machine.sh run-all    # 6개 Before/After 실행 및 검사
./orbstack-machine.sh verify     # 부팅 검사 로그·설정·장애/회피 증거 검사
./orbstack-machine.sh collect    # 6개 증거 폴더만 로컬로 회수
```

프로비저닝은 파일을 VM 내부로 전송해 실행한다. 전역 셸 프로필과 명령어 링크를
설치하지 않는다. 기존 키가 올바르면 유지하고, 잘못된 키는 덮어쓰지 않고 오류로 알린다.
증거 회수는 기존 파일을 갱신하므로 재실행 후 보고서 인용도 새 로그와 맞춰야 한다.

## Linux에서 직접 실행

제공 바이너리를 실행할 수 있는 amd64 Linux의 일반 계정에서:

```bash
export AGENT_HOME="$PWD/runtime"
./setup-agent-env.sh
source "$AGENT_HOME/.env"
SCENARIO_RUNNER="$PWD/run-scenario.sh" \
VERIFY_RUNNER="$PWD/verify-results.sh" \
EVIDENCE_ROOT="$PWD/evidence" ./run-all-scenarios.sh
```

환경 구성은 `AGENT_PORT=15034`, `$AGENT_HOME/upload_files`,
`$AGENT_HOME/api_keys/secret.key`(내용 `agent_api_key_test`), 쓰기 가능한 로그 경로를 생성한다.
각 시나리오는 `MEMORY_LIMIT`(50~512), `CPU_MAX_OCCUPY`(10~100),
`MULTI_THREAD_ENABLE`을 지정하고 실제 포트 바인딩·키·권한 검사는 앱 부팅 로그로 확인한다.

개별 실행:

```bash
EVIDENCE_ROOT="$PWD/evidence" ./run-scenario.sh oom_before 128 50 false 40
# 인자: 이름 MEMORY_LIMIT CPU_MAX_OCCUPY true|false 관측시간(초)
```

## 남긴 코드

| 파일 | 미션에서 필요한 역할 |
| --- | --- |
| `setup-agent-env.sh` | 필수 경로·고정 포트·테스트 키·환경 파일 구성 |
| `monitor.sh` | 프로세스 CPU 순간값·RSS·스레드 상태·WCHAN 수집 |
| `run-scenario.sh` | 실행·관제·로그·스레드 스냅샷·종료 코드 수집 및 대상 프로세스 정리 |
| `run-all-scenarios.sh` | 필수 6개 조합 실행 |
| `verify-results.sh` | 부팅 성공·설정·장애 로그·관측 후 생존/정리 구분 |
| `provision-orbstack.sh` | VM에 일반 계정과 필수 실행 파일 구성 |
| `orbstack-machine.sh` | macOS에서 위 흐름 실행 및 증거 회수 |

## 검증

```bash
bash tests/test_submission.sh
EVIDENCE_ROOT="$PWD/evidence" bash verify-results.sh
python3 tests/check_evidence.py
python3 tests/check_evidence.py --strict-cpu
```

마지막 명령은 OS 실측 CPU 50% 이상을 요구하는 추가 검사다. 현재 제출 증거는
앱 내부 부하 최고 55.65%와 달리 OS 실측 최고가 4.0%여서 이 검사는 실패한다.
보호 정책의 종료·회피 확인만으로 실제 CPU 과점유 증거까지 충족했다고 판정하지 않는다.
After 생존은 관측 구간으로 한정하며, 관측 만료 후 스크립트 정리와 앱 자체 종료를 구분한다.

## 별도 학습 페이지

요청한 [동기화 시각화 HTML](visualizations/synchronization.html)은 유지한다.
Mutex·Semaphore·Deadlock을 단계별로 조작하는 오프라인 교육 모델이며,
실제 OS 관제 증거와는 구분한다. 모델 검사: `node tests/test_synchronization.cjs`.
# codyssey_b4_2
