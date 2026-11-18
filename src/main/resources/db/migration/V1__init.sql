-- V1: 작기 목록(cropping_season)과 환경 기록(env_record) 초기 스키마
-- 주의: 한 번 적용된 뒤에는 이 파일을 수정하지 말 것 (Flyway 체크섬 불일치). 변경은 V2 이상으로 추가.

-- 작기(농사 한 회차) 목록. 스마트팜코리아 작기 목록 API 응답을 그대로 저장한다.
CREATE TABLE cropping_season (
    cropping_serl_no   bigint PRIMARY KEY,   -- 작기 일련번호
    facility_id        text   NOT NULL,      -- 시설 ID
    item_code          text   NOT NULL,      -- 품목 코드
    item_name          text,                 -- 품목명 (예: 파프리카)
    address_name       text,                 -- 지역 (예: 전라남도 나주시)
    cropping_date      date,                 -- 작기 시작일
    cropping_end_date  date,                 -- 작기 종료일
    acq_auto_yn        char(1),              -- 자동 수집 여부 (원본 Y/N 그대로)
    acq_manl_yn        char(1),              -- 수동 제어 수집 여부
    acq_culti_yn       char(1),              -- 재배 정보 수집 여부
    acq_mgmt_yn        char(1)               -- 경영 정보 수집 여부
);

-- 작기별 환경 측정 기록. 한 행 = (작기, 시각, 분류, 항목)의 측정값 하나.
CREATE TABLE env_record (
    cropping_serl_no  bigint    NOT NULL REFERENCES cropping_season (cropping_serl_no),
    meas_date         timestamp NOT NULL,    -- 측정 시각 (원본에 시간대 정보 없음, 그대로 저장)
    sect_code         text      NOT NULL,    -- 분류 코드 (EL 토양환경, NT 양액정보 등)
    fatr_code         text      NOT NULL,    -- 항목 코드 (BW 배지무게, CL 배지온도 등)
    sen_val           numeric,               -- 측정값 (정밀도 미지정: 조용한 반올림 방지)
    cnt_collect       integer,               -- 수집 건수
    -- 시각을 앞쪽에 둬서 "작기 + 시간 구간" 조회와 시간순 정렬을 PK 인덱스가 담당
    PRIMARY KEY (cropping_serl_no, meas_date, sect_code, fatr_code)
);

-- Supabase 자동 REST API 경로 차단용. 정책 없이 RLS만 켜면 공개 키 접근이 막힌다.
ALTER TABLE cropping_season ENABLE ROW LEVEL SECURITY;
ALTER TABLE env_record      ENABLE ROW LEVEL SECURITY;
