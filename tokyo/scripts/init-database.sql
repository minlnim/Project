-- Tokyo Portal 초기 데이터 삽입 스크립트
-- 테스트 사용자 및 조직도 데이터

-- 직원 테이블 (employees)
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(100),
    position VARCHAR(100),
    phone VARCHAR(50),
    hire_date DATE DEFAULT CURRENT_DATE,
    manager_id INTEGER REFERENCES employees(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 부서 테이블 (departments)
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    manager_id INTEGER REFERENCES employees(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 공지사항 테이블 (notices)
CREATE TABLE IF NOT EXISTS notices (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    author_id INTEGER REFERENCES employees(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    views INTEGER DEFAULT 0
);

-- 결재 테이블 (approvals)
CREATE TABLE IF NOT EXISTS approvals (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    requester_id INTEGER REFERENCES employees(id),
    approver_id INTEGER REFERENCES employees(id),
    status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 테스트 직원 데이터 삽입
INSERT INTO employees (email, name, department, position, phone) VALUES
    ('ceo@company.com', '홍길동', '경영진', '대표이사', '010-1234-5678'),
    ('cto@company.com', '김철수', '기술본부', '기술이사', '010-2345-6789'),
    ('manager1@company.com', '이영희', '개발팀', '팀장', '010-3456-7890'),
    ('dev1@company.com', '박민수', '개발팀', '선임개발자', '010-4567-8901'),
    ('dev2@company.com', '최지혜', '개발팀', '주임개발자', '010-5678-9012'),
    ('hr@company.com', '정수현', '인사팀', '팀장', '010-6789-0123')
ON CONFLICT (email) DO NOTHING;

-- 조직 관계 설정 (manager_id 업데이트)
UPDATE employees SET manager_id = (SELECT id FROM employees WHERE email = 'ceo@company.com')
WHERE email IN ('cto@company.com', 'hr@company.com');

UPDATE employees SET manager_id = (SELECT id FROM employees WHERE email = 'cto@company.com')
WHERE email = 'manager1@company.com';

UPDATE employees SET manager_id = (SELECT id FROM employees WHERE email = 'manager1@company.com')
WHERE email IN ('dev1@company.com', 'dev2@company.com');

-- 부서 데이터 삽입
INSERT INTO departments (name, description, manager_id) VALUES
    ('경영진', '회사 경영 총괄', (SELECT id FROM employees WHERE email = 'ceo@company.com')),
    ('기술본부', '기술 개발 및 운영', (SELECT id FROM employees WHERE email = 'cto@company.com')),
    ('개발팀', '소프트웨어 개발', (SELECT id FROM employees WHERE email = 'manager1@company.com')),
    ('인사팀', '인사 관리 및 채용', (SELECT id FROM employees WHERE email = 'hr@company.com'))
ON CONFLICT (name) DO NOTHING;

-- 샘플 공지사항
INSERT INTO notices (title, content, author_id) VALUES
    ('회사 포털 시스템 오픈', '새로운 사내 포털 시스템이 오픈되었습니다. 많은 이용 부탁드립니다.', 
     (SELECT id FROM employees WHERE email = 'ceo@company.com')),
    ('개발팀 워크샵 안내', '다음 주 금요일에 개발팀 워크샵이 있습니다. 참석 부탁드립니다.',
     (SELECT id FROM employees WHERE email = 'manager1@company.com')),
    ('인사 평가 일정 안내', '2025년 상반기 인사 평가 일정을 안내드립니다.',
     (SELECT id FROM employees WHERE email = 'hr@company.com'));

-- 샘플 결재 문서
INSERT INTO approvals (title, content, requester_id, approver_id, status) VALUES
    ('출장 신청서', '클라이언트 미팅을 위한 출장 신청합니다.', 
     (SELECT id FROM employees WHERE email = 'dev1@company.com'),
     (SELECT id FROM employees WHERE email = 'manager1@company.com'),
     'pending'),
    ('휴가 신청서', '다음 주 월요일 연차 휴가 신청합니다.',
     (SELECT id FROM employees WHERE email = 'dev2@company.com'),
     (SELECT id FROM employees WHERE email = 'manager1@company.com'),
     'approved'),
    ('예산 승인 요청', '개발 장비 구매를 위한 예산 승인 요청드립니다.',
     (SELECT id FROM employees WHERE email = 'manager1@company.com'),
     (SELECT id FROM employees WHERE email = 'cto@company.com'),
     'pending');

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);
CREATE INDEX IF NOT EXISTS idx_employees_manager ON employees(manager_id);
CREATE INDEX IF NOT EXISTS idx_notices_author ON notices(author_id);
CREATE INDEX IF NOT EXISTS idx_approvals_requester ON approvals(requester_id);
CREATE INDEX IF NOT EXISTS idx_approvals_approver ON approvals(approver_id);
CREATE INDEX IF NOT EXISTS idx_approvals_status ON approvals(status);

-- 완료 메시지
SELECT 'Database initialization completed successfully!' AS status;
