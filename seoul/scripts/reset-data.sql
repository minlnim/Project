-- 데이터 초기화 및 재삽입 스크립트
USE corpportal;

-- 외래 키 체크 임시 비활성화
SET FOREIGN_KEY_CHECKS = 0;

-- 기존 데이터 삭제
TRUNCATE TABLE approvals;
TRUNCATE TABLE notices;
TRUNCATE TABLE departments;
TRUNCATE TABLE employees;

-- 외래 키 체크 재활성화
SET FOREIGN_KEY_CHECKS = 1;

-- 테스트 직원 데이터 삽입
INSERT INTO employees (email, name, department, position, phone) VALUES
    ('ceo@company.com', '홍길동', '경영진', '대표이사', '010-1234-5678'),
    ('cto@company.com', '김철수', '기술본부', '기술이사', '010-2345-6789'),
    ('manager1@company.com', '이영희', '개발팀', '팀장', '010-3456-7890'),
    ('dev1@company.com', '박민수', '개발팀', '선임개발자', '010-4567-8901'),
    ('dev2@company.com', '최지혜', '개발팀', '주임개발자', '010-5678-9012'),
    ('hr@company.com', '정수현', '인사팀', '팀장', '010-6789-0123');

-- 조직 관계 설정
UPDATE employees SET manager_id = (SELECT id FROM (SELECT id FROM employees WHERE email = 'ceo@company.com') AS temp)
WHERE email IN ('cto@company.com', 'hr@company.com');

UPDATE employees SET manager_id = (SELECT id FROM (SELECT id FROM employees WHERE email = 'cto@company.com') AS temp)
WHERE email = 'manager1@company.com';

UPDATE employees SET manager_id = (SELECT id FROM (SELECT id FROM employees WHERE email = 'manager1@company.com') AS temp)
WHERE email IN ('dev1@company.com', 'dev2@company.com');

-- 부서 데이터
INSERT INTO departments (name, description, manager_id) VALUES
    ('경영진', '회사 경영 총괄', (SELECT id FROM (SELECT id FROM employees WHERE email = 'ceo@company.com') AS temp)),
    ('기술본부', '기술 개발 및 운영', (SELECT id FROM (SELECT id FROM employees WHERE email = 'cto@company.com') AS temp)),
    ('개발팀', '소프트웨어 개발', (SELECT id FROM (SELECT id FROM employees WHERE email = 'manager1@company.com') AS temp)),
    ('인사팀', '인사 관리 및 채용', (SELECT id FROM (SELECT id FROM employees WHERE email = 'hr@company.com') AS temp));

-- 공지사항
INSERT INTO notices (title, content, author_id) VALUES
    ('회사 포털 시스템 오픈', '새로운 사내 포털 시스템이 오픈되었습니다. 많은 이용 부탁드립니다.', 
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'ceo@company.com') AS temp)),
    ('개발팀 워크샵 안내', '다음 주 금요일에 개발팀 워크샵이 있습니다. 참석 부탁드립니다.',
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'manager1@company.com') AS temp)),
    ('인사 평가 일정 안내', '2025년 상반기 인사 평가 일정을 안내드립니다.',
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'hr@company.com') AS temp));

-- 결재 문서
INSERT INTO approvals (title, content, requester_id, approver_id, status) VALUES
    ('출장 신청서', '클라이언트 미팅을 위한 출장 신청합니다.', 
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'dev1@company.com') AS temp),
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'manager1@company.com') AS temp),
     'pending'),
    ('휴가 신청서', '다음 주 월요일 연차 휴가 신청합니다.',
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'dev2@company.com') AS temp),
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'manager1@company.com') AS temp),
     'approved'),
    ('예산 승인 요청', '개발 장비 구매를 위한 예산 승인 요청드립니다.',
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'manager1@company.com') AS temp),
     (SELECT id FROM (SELECT id FROM employees WHERE email = 'cto@company.com') AS temp),
     'pending');

SELECT 'Data reset completed!' AS status;
