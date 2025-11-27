import json
import pymysql
import os

def lambda_handler(event, context):
    """
    Aurora MySQL 데이터베이스 초기화 Lambda 함수
    """
    db_host = os.environ.get('DB_HOST')
    db_port = os.environ.get('DB_PORT', '3306')
    db_name = os.environ.get('DB_NAME')
    db_user = os.environ.get('DB_USER')
    db_password = os.environ.get('DB_PASSWORD')
    
    if not all([db_host, db_name, db_user, db_password]):
        return {
            'statusCode': 400,
            'body': json.dumps('Missing required database configuration')
        }
    
    try:
        # Aurora MySQL에 연결 (데이터베이스 지정 없이)
        conn = pymysql.connect(
            host=db_host,
            port=int(db_port),
            user=db_user,
            password=db_password,
            autocommit=True
        )
        cur = conn.cursor()
        
        # 데이터베이스 생성
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {db_name}")
        cur.execute(f"USE {db_name}")
        
        # employees 테이블 생성
        cur.execute("""
        CREATE TABLE IF NOT EXISTS employees (
            id INT AUTO_INCREMENT PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            name VARCHAR(100) NOT NULL,
            department VARCHAR(100),
            position VARCHAR(100),
            phone VARCHAR(50),
            manager_id INT,
            hire_date DATE DEFAULT (CURRENT_DATE),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (manager_id) REFERENCES employees(id)
        )
        """)
        
        # notices 테이블 생성
        cur.execute("""
        CREATE TABLE IF NOT EXISTS notices (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            content TEXT,
            author_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (author_id) REFERENCES employees(id)
        )
        """)
        
        # approvals 테이블 생성
        cur.execute("""
        CREATE TABLE IF NOT EXISTS approvals (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            content TEXT,
            status VARCHAR(50) DEFAULT 'pending',
            requester_id INT NOT NULL,
            approver_id INT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (requester_id) REFERENCES employees(id),
            FOREIGN KEY (approver_id) REFERENCES employees(id)
        )
        """)
        
        # 인덱스 생성 (이미 존재하면 무시)
        try:
            cur.execute("CREATE INDEX idx_employees_email ON employees(email)")
        except pymysql.err.OperationalError:
            pass  # 이미 존재함
        
        try:
            cur.execute("CREATE INDEX idx_employees_department ON employees(department)")
        except pymysql.err.OperationalError:
            pass
        
        try:
            cur.execute("CREATE INDEX idx_notices_created_at ON notices(created_at DESC)")
        except pymysql.err.OperationalError:
            pass
        
        try:
            cur.execute("CREATE INDEX idx_approvals_status ON approvals(status)")
        except pymysql.err.OperationalError:
            pass
        
        try:
            cur.execute("CREATE INDEX idx_approvals_requester_id ON approvals(requester_id)")
        except pymysql.err.OperationalError:
            pass
        
        # 테스트 직원 데이터 삽입
        cur.execute("""
        INSERT IGNORE INTO employees (email, name, department, position, phone, manager_id, hire_date) VALUES
        ('ceo@company.com', '홍길동', '경영진', '대표이사', '02-1234-5678', NULL, '2020-01-01'),
        ('cto@company.com', '김철수', '기술본부', '기술이사', '02-1234-5679', 1, '2020-03-01'),
        ('hr@company.com', '정수현', '인사팀', '팀장', '02-1234-5680', 1, '2020-06-01'),
        ('manager1@company.com', '이영희', '개발팀', '팀장', '02-1234-5681', 2, '2021-01-01'),
        ('dev1@company.com', '박민수', '개발팀', '선임개발자', '02-1234-5682', 4, '2021-06-01'),
        ('dev2@company.com', '최지혜', '개발팀', '주임개발자', '02-1234-5683', 4, '2022-03-01')
        """)
        
        # 공지사항이 없을 때만 추가
        cur.execute("SELECT COUNT(*) FROM notices")
        notice_count = cur.fetchone()[0]
        
        if notice_count == 0:
            cur.execute("""
            INSERT INTO notices (title, content, author_id) VALUES
            ('시스템 점검 안내', '금일 18:00~20:00 시스템 점검이 예정되어 있습니다.', 1),
            ('신규 프로젝트 킥오프', '다음 주 월요일 오전 10시 신규 프로젝트 킥오프 미팅이 있습니다.', 2),
            ('휴가 신청 안내', '여름 휴가 신청은 이번 주 금요일까지 완료해주시기 바랍니다.', 3)
            """)
        
        # 결재가 없을 때만 추가
        cur.execute("SELECT COUNT(*) FROM approvals")
        approval_count = cur.fetchone()[0]
        
        if approval_count == 0:
            cur.execute("""
            INSERT INTO approvals (title, content, status, requester_id, approver_id) VALUES
            ('휴가 신청', '2025년 12월 24일~26일 연차 휴가 신청합니다.', 'pending', 5, 4),
            ('출장 신청', '부산 고객사 방문 출장 신청', 'approved', 6, 4),
            ('교육 신청', 'AWS 교육 참가 신청', 'pending', 5, 2)
            """)
        
        cur.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps('Database initialized successfully')
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
