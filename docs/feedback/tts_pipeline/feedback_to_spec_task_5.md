# Architecture Overview


전체 아키텍처 건강도: 🟡 (Some concerns - Barrier와 Timeout 개념은 완벽하나, 이전 설계 원칙 위배(Warning)가 또 발생함)


비동기 환경에서 발생할 수 있는 Race Condition(TTS 청크가 `stream_end`보다 늦게 도착하는 현상)을 정확히 인지하고, `asyncio.wait_for`를 통해 Barrier와 Timeout 로직을 설계한 것은 아키텍처 관점에서 매우 훌륭하고 필수적인 방어 기제입니다. 타임아웃 값을 10초로 설정하고 YAML을 통해 환경별로 주입받도록 한 설정(Configuration) 관리도 모범적입니다.

하지만 클라이언트와의 계약(Contract) 측면에서는 여전히 흠집이 있습니다.

## Step 1 Findings — Questionable Requirements

* **[CRITICAL] 또, 또, 또 등장한 Warning 이벤트:** `except asyncio.TimeoutError:` 블록 안을 보십시오. 왜 프론트엔드에게 `TTS_BARRIER_TIMEOUT`이라는 경고를 보냅니까?
프론트엔드는 타임아웃이 났든, 서버가 불탔든 상관할 바가 아닙니다. 그저 약속된 타임아웃 시간이 지나면 서버가 알아서 태스크를 끊고 마지막 이벤트인 `stream_end`를 쏴주면, 프론트엔드는 "아, 턴이 끝났구나" 하고 대기 상태로 들어가면 그만입니다.

## Step 2 Findings — Candidates for Deletion

* **[CRITICAL] `Warning` 전송 로직 전체:** `_wait_for_tts_tasks` 내의 `await self._put_event(turn_id, {"type": "warning", ...})` 블록을 통째로 삭제하십시오.
* **[CRITICAL] 테스트 및 검증 시나리오의 Warning 의존성:** `test_barrier_timeout_sends_warning_and_continues` 테스트와 통합 테스트 테이블에 있는 `warning(TTS_BARRIER_TIMEOUT)` 수신 검증 항목을 모두 삭제하십시오.

## Step 3 Findings — Simplification Opportunities

* **[IMPORTANT] 백엔드 로깅으로 대체:** 타임아웃이 발생했다는 사실은 시스템 모니터링 관점에서 매우 중요한 지표입니다. 클라이언트에게 이벤트를 쏘는 대신, T3에서 했던 것처럼 **백엔드 로그(`logger.error` 또는 `logger.warning`)**로 남기십시오.

```python
# 수정된 예시
    except asyncio.TimeoutError:
        # 초과된 task cancel
        for task in turn.tts_tasks:
            if not task.done():
                task.cancel()
        
        # 클라이언트에게 보내지 않고 백엔드에만 기록합니다.
        logger.warning(f"TTS synthesis timed out after {timeout}s for turn {turn_id}, proceeding to stream_end")

```

## Step 4 Findings — Cycle Time Blockers

* 해당 사항 없습니다. 타임아웃 설정은 시스템 데드락을 방지하여 오히려 전체 서비스와 개발 주기의 안정성을 높여줍니다.

## Step 5 Findings — Automation Assessment

* **[IMPORTANT] 테스트 코드 수정:** 타임아웃 테스트(`test_barrier_timeout_sends_warning_and_continues`)는 Warning 이벤트를 찾는 대신, 타임아웃 발생 후에도 **`stream_end` 이벤트가 정상적으로 큐에 들어가는지**, 그리고 **로그가 정상적으로 출력되었는지(Mocking)**를 검증하는 방향으로 수정되어야 합니다.

---

## Priority Actions

1. **Warning 이벤트 최종 말살:** `_wait_for_tts_tasks`에서 Warning 이벤트를 큐에 넣는 코드를 삭제하고 `logger.warning`으로 교체하십시오.
2. **테스트 명세 업데이트:** 단위 테스트와 통합 테스트 시나리오에서 Warning 관련 검증을 모두 제거하고, `stream_end` 도착 여부와 로깅 여부로 검증 기준을 변경하십시오.