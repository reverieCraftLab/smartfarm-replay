# 스마트팜 가상 온실 리플레이 (smartfarm-replay)

## 목표
스마트팜코리아 CROPSEASON Open API로 실제 작기 데이터를 모아 Postgres(Supabase)에 저장하고, 시간을 압축해 다시 흘려보내는 백엔드.
포트폴리오용(팜360닷에이아이 백엔드 공고, 마감 2026-12-09). 백엔드 설계와 구현은 GT가 직접 한다. AI는 설계 상담, 코드 리뷰, 뼈대 작성을 맡는다. 프론트엔드는 나중에 AI가 생성.

## 스택
Spring Boot 4.1.2 (Spring Framework 7), Java 21 (Temurin), Maven wrapper, Lombok(pom.xml에 추가, annotationProcessorPaths 설정 포함), Flyway, JdbcTemplate(대량 적재), Supabase Postgres(Session pooler), 배포는 EC2 t2.micro 예정.
설정은 Properties 형식. 프로필: local(로컬 DB, git 제외) / dev(local과 동일) / prd(환경변수).
Spring Boot 4.x 주의: Flyway는 `spring-boot-starter-flyway`, 웹은 `webmvc` 스타터, JSON은 Jackson 3(`tools.jackson`). 인터넷 예제는 3.x 기준이 많다.

## 현재 상태 (2026-11-19)
- Flyway V1 적용 완료 (cropping_season, env_record, RLS). 이미 적용된 V1은 수정 금지, 변경은 V2 이상.
- collector 패키지 뼈대 있음. `SmartfarmClient.fetchCroppingSeasons`를 GT가 구현 중.
- 다음: 작기 목록 478건 적재 -> 작기 7535 환경 데이터 33,435행 적재 -> 검증.
- V2에 `ALTER TABLE flyway_schema_history ENABLE ROW LEVEL SECURITY;` 포함할 것 (dev DB에는 콘솔에서 직접 적용돼 있어 코드와 한 줄 다름).

## 확정된 결정
- env_record PK = (cropping_serl_no, meas_date, sect_code, fatr_code), 대리키 없음. meas_date는 timestamp(시간대 없음, 한국 시각 가정, 미검증). sen_val은 numeric(정밀도 미지정).
- env_record -> cropping_season 외래키 유지. 제어는 control_record(V2)로 분리.
- 스키마 변경은 Flyway로만. Supabase MCP나 DB 콘솔로 직접 바꾸지 않는다.
- 적재: 페이지 1개 단위 커밋 + `ON CONFLICT DO NOTHING`(멱등), JdbcTemplate.batchUpdate.
- MSA는 적용하지 않고 패키지 경계로 모듈형 모놀리스 유지 (t2.micro, DB 하나, 1인 개발).

## 패키지 규칙 (`com.gt.smartfarm_replay`)
collector(client/dto/loader), season, env, replay, common.
1. 외부 API를 아는 것은 collector.client뿐.
2. 서비스키는 SmartfarmClient 밖으로 나가지 않는다 (로그, 예외 메시지 포함).
3. season, env, replay는 collector를 import하지 않고 DB 테이블만 읽는다.
4. 수집 클래스는 `smartfarm.collect.enabled=true`일 때만 동작 (기본 꺼짐).

## API 주의점
- https만 사용(http는 응답 없이 연결을 붙잡음). 읽기 타임아웃 60초 이상(호출당 약 3.5초, 가끔 20초대).
- pageNum은 1부터. 종료는 `ceil(totalRows/1000)`, 서버의 totalPage는 틀리다.
- 응답 판정 = HTTP 상태 + 첫 원소 statusCode. statusCode/statusMessage는 첫 원소에만 있다. "00" 정상, "03" 데이터 없음(종료 신호).
- 재시도: 01/02/04/05. 즉시 중단: 10/11/12/20/21. 22(요청 제한)는 대기 후 재개.
- 환경/제어 응답에는 croppingSerlNo가 없다. 요청값을 붙여서 저장. null 센티널 행은 적재 제외.
- 서비스키가 URL 경로에 들어간다. URL을 로그나 예외에 남기지 않는다.

## 금지 / 보안
- `.env`, `application-local.properties`를 읽거나 출력하거나 커밋하지 않는다. 비밀번호, 서비스키, 접속 계정을 답변이나 문서에 쓰지 않는다.
- 병렬 호출은 호출 제한 수치가 확인되기 전까지 하지 않는다.

## 작업 규칙
- 코드만 주지 말고 왜 그렇게 하는지 설명한다. DB 설계와 트랜잭션 결정은 근거를 자세히.
- 영어 이름(클래스, 용어)에는 한국어 발음과 뜻을 괄호로 병기한다.
- 근거를 말할 때는 원본 파일(경로와 내용)을 함께 보여 준다.
- 확인하지 않은 것은 추정이라고 표시한다. 컴파일/실행하지 않은 코드는 그렇게 밝힌다.
- 이미 있는 파일과 이전 결정을 먼저 확인하고, 없을 때만 요청한다.

## 문서 위치 (저장소 밖)
- /Users/a1/project/SmartPam/설계/2026-11-16_DB적재_작업목록.md (단계별 작업 목록, 0~1단계 완료 표시)
- /Users/a1/project/SmartPam/설계/API_분석_요약.md
- /Users/a1/project/SmartPam/세션로그/ (대화별 결정 기록, 최신: 2026-11-18)
- /Users/a1/project/SmartPam/명세서/_extracted/ (CROPSEASON_plain.txt 등 API 명세, response_*.json 실제 응답 표본은 SmartPam/ 바로 아래)
