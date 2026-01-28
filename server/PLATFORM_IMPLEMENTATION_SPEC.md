# HPC Test Results Platform - Implementation Specifications

## Part 1: PostgreSQL Database Schema (SQL)

### Create Database and Extensions

```sql
-- Create database
CREATE DATABASE hpc_test_platform;

-- Connect to database
\c hpc_test_platform;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS uuid-ossp;
CREATE EXTENSION IF NOT EXISTS json;
```

### Create Tables

```sql
-- Suppliers Table
CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    contact_person VARCHAR(255),
    contact_email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Servers Table
CREATE TABLE servers (
    id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    hostname VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) UNIQUE NOT NULL,
    make VARCHAR(255),
    model VARCHAR(255),
    first_tested_at TIMESTAMP,
    last_tested_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(supplier_id, hostname)
);

-- Test Results Table (Versioned)
CREATE TABLE test_results (
    id SERIAL PRIMARY KEY,
    server_id INTEGER NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    test_run_id UUID NOT NULL DEFAULT uuid_generate_v4(),
    test_id VARCHAR(255) NOT NULL,
    test_name VARCHAR(255) NOT NULL,
    test_category VARCHAR(100) NOT NULL,
    command TEXT,
    result TEXT,
    result_type VARCHAR(50) NOT NULL,  -- 'boolean', 'numeric', 'text'
    status VARCHAR(50) NOT NULL,  -- 'pass', 'fail', 'partial'
    notes TEXT,
    raw_html LONGTEXT,  -- Full HTML file
    version INTEGER NOT NULL,
    test_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(server_id, test_run_id, test_id),
    INDEX(server_id),
    INDEX(test_run_id),
    INDEX(test_category)
);

-- Test Configurations Table
CREATE TABLE test_configurations (
    id SERIAL PRIMARY KEY,
    test_id VARCHAR(255) UNIQUE NOT NULL,
    test_name VARCHAR(255) NOT NULL,
    test_category VARCHAR(100) NOT NULL,
    weight DECIMAL(3, 2) NOT NULL DEFAULT 1.0,
    result_type VARCHAR(50) NOT NULL,  -- 'boolean', 'numeric', 'text'
    boolean_yes_score INTEGER DEFAULT 100,
    boolean_no_score INTEGER DEFAULT 0,
    range_1_min DECIMAL(10, 2),
    range_1_max DECIMAL(10, 2),
    range_2_min DECIMAL(10, 2),
    range_2_max DECIMAL(10, 2),
    range_3_min DECIMAL(10, 2),
    range_3_max DECIMAL(10, 2),
    range_4_min DECIMAL(10, 2),
    range_4_max DECIMAL(10, 2),
    range_5_min DECIMAL(10, 2),
    range_5_max DECIMAL(10, 2),
    unit_of_measurement VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(test_category)
);

-- Server Scores Table (Cached)
CREATE TABLE server_scores (
    id SERIAL PRIMARY KEY,
    server_id INTEGER NOT NULL UNIQUE REFERENCES servers(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    overall_score DECIMAL(5, 2) NOT NULL,
    score_breakdown JSON,  -- {'system': 85, 'benchmarks': 92, 'networking': 78, 'security': 88}
    color_grade VARCHAR(20) NOT NULL,  -- 'red', 'orange', 'yellow', 'light_green', 'green'
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(server_id),
    INDEX(overall_score)
);

-- Supplier Scores Table (League Table)
CREATE TABLE supplier_scores (
    id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL UNIQUE REFERENCES suppliers(id) ON DELETE CASCADE,
    average_score DECIMAL(5, 2) NOT NULL,
    best_score DECIMAL(5, 2) NOT NULL,
    median_score DECIMAL(5, 2) NOT NULL,
    server_count INTEGER NOT NULL,
    category_scores JSON,  -- {'system': 85, 'benchmarks': 92, 'networking': 78, 'security': 88}
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(supplier_id),
    INDEX(average_score),
    INDEX(best_score),
    INDEX(median_score)
);

-- Analysis Reports Table
CREATE TABLE analysis_reports (
    id SERIAL PRIMARY KEY,
    report_id UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE CASCADE,
    server_id INTEGER REFERENCES servers(id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,  -- 'supplier', 'server', 'comparison'
    pdf_path VARCHAR(500),
    json_data JSON,  -- Raw report data
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(report_id),
    INDEX(supplier_id),
    INDEX(server_id)
);

-- Create indexes for common queries
CREATE INDEX idx_test_results_server_version ON test_results(server_id, version);
CREATE INDEX idx_test_results_category ON test_results(test_category);
CREATE INDEX idx_server_scores_grade ON server_scores(color_grade);
CREATE INDEX idx_supplier_scores_rank ON supplier_scores(average_score DESC);
```

---

## Part 2: API Service Specifications (FastAPI)

### 2.1 Project Structure

```
hpc-test-api/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app initialization
│   ├── config.py               # Configuration (DB_URL, etc.)
│   ├── models.py               # SQLAlchemy ORM models
│   ├── schemas.py              # Pydantic request/response schemas
│   ├── database.py             # Database connection
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── suppliers.py        # /api/suppliers endpoints
│   │   ├── servers.py          # /api/servers endpoints
│   │   ├── uploads.py          # /api/uploads endpoints
│   │   ├── test_configs.py     # /api/test-configs endpoints
│   │   └── reports.py          # /api/reports endpoints
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── html_parser.py      # HTML parsing logic
│   │   ├── scorer.py           # Score calculation
│   │   └── validators.py       # Data validation
│   └── tasks/
│       ├── __init__.py
│       └── celery_tasks.py     # Async task definitions
├── tests/
│   ├── test_api.py
│   └── test_parsers.py
├── requirements.txt
├── .env.example
└── run.py
```

### 2.2 API Endpoints (OpenAPI Specification)

#### Suppliers

```python
# POST /api/suppliers
# Create new supplier
Request Body:
{
    "name": "Dell EMC",
    "contact_person": "John Doe",
    "contact_email": "john@dell.com"
}

Response (201):
{
    "id": 1,
    "name": "Dell EMC",
    "contact_person": "John Doe",
    "contact_email": "john@dell.com",
    "created_at": "2026-01-28T13:57:57Z"
}

# GET /api/suppliers
# List all suppliers
Response (200):
{
    "total": 5,
    "suppliers": [
        {
            "id": 1,
            "name": "Dell EMC",
            "contact_person": "John Doe",
            "contact_email": "john@dell.com",
            "server_count": 3,
            "avg_score": 82.5
        }
    ]
}

# GET /api/suppliers/{id}
# Get specific supplier with stats
Response (200):
{
    "id": 1,
    "name": "Dell EMC",
    "contact_person": "John Doe",
    "contact_email": "john@dell.com",
    "servers": [
        {
            "id": 1,
            "hostname": "hpc-server-01",
            "ip_address": "192.168.1.100",
            "make": "Dell",
            "model": "PowerEdge R7625",
            "last_tested_at": "2026-01-28T10:00:00Z",
            "overall_score": 85,
            "color_grade": "light_green"
        }
    ],
    "average_score": 85,
    "best_score": 90,
    "median_score": 85
}

# PUT /api/suppliers/{id}
# Update supplier
Request Body:
{
    "contact_person": "Jane Smith",
    "contact_email": "jane@dell.com"
}

Response (200): Updated supplier object

# DELETE /api/suppliers/{id}
# Delete supplier (cascades to servers/results)
Response (204): No content
```

#### Servers

```python
# GET /api/servers
# List servers (with pagination)
Query Parameters:
- supplier_id: INTEGER (optional filter)
- page: INTEGER (default 1)
- limit: INTEGER (default 50)

Response (200):
{
    "total": 100,
    "page": 1,
    "limit": 50,
    "servers": [
        {
            "id": 1,
            "supplier_id": 1,
            "hostname": "hpc-server-01",
            "ip_address": "192.168.1.100",
            "make": "Dell",
            "model": "PowerEdge R7625",
            "overall_score": 85,
            "color_grade": "light_green",
            "last_tested_at": "2026-01-28T10:00:00Z",
            "version": 5
        }
    ]
}

# GET /api/servers/{id}
# Get server details with latest scores
Response (200):
{
    "id": 1,
    "supplier_id": 1,
    "hostname": "hpc-server-01",
    "ip_address": "192.168.1.100",
    "make": "Dell",
    "model": "PowerEdge R7625",
    "version": 5,
    "overall_score": 85,
    "color_grade": "light_green",
    "score_breakdown": {
        "system": 80,
        "benchmarks": 88,
        "networking": 85,
        "security": 82
    },
    "first_tested_at": "2026-01-10T00:00:00Z",
    "last_tested_at": "2026-01-28T10:00:00Z",
    "test_count": 87
}

# GET /api/servers/{id}/history
# Get version history (for trend analysis)
Query Parameters:
- limit: INTEGER (default 10)

Response (200):
{
    "servers_id": 1,
    "versions": [
        {
            "version": 5,
            "overall_score": 85,
            "tested_at": "2026-01-28T10:00:00Z"
        },
        {
            "version": 4,
            "overall_score": 82,
            "tested_at": "2026-01-21T10:00:00Z"
        }
    ]
}
```

#### Uploads

```python
# POST /api/uploads
# Upload HTML test file
Form Data:
- html_file: FILE (required, multipart/form-data)
- supplier_id: INTEGER (optional if creating new supplier)
- supplier_name: STRING (required if supplier_id not provided)
- supplier_contact_person: STRING (required if supplier_id not provided)
- supplier_contact_email: STRING (required if supplier_id not provided)

Response (202 Accepted):
{
    "upload_id": "uuid-here",
    "status": "processing",
    "message": "Upload received, processing in background",
    "test_run_id": "uuid-here",
    "server": {
        "hostname": "hpc-server-01",
        "ip_address": "192.168.1.100",
        "make": "Dell",
        "model": "PowerEdge R7625"
    },
    "test_count": 87,
    "check_status_url": "/api/uploads/uuid-here/status"
}

# GET /api/uploads/{upload_id}/status
# Check upload processing status
Response (200):
{
    "upload_id": "uuid-here",
    "status": "completed",  -- 'processing', 'completed', 'failed'
    "test_run_id": "uuid-here",
    "server_id": 1,
    "version": 5,
    "overall_score": 85,
    "color_grade": "light_green",
    "test_count": 87,
    "parsed_count": 87,
    "error_message": null,
    "completed_at": "2026-01-28T13:57:57Z"
}
```

#### Test Configurations

```python
# GET /api/test-configs
# List all test configurations
Response (200):
{
    "total": 87,
    "configurations": [
        {
            "id": 1,
            "test_id": "cpu-model",
            "test_name": "CPU Model",
            "test_category": "System",
            "weight": 0.05,
            "result_type": "text",
            "is_active": true
        },
        {
            "id": 2,
            "test_id": "total-memory",
            "test_name": "Total Memory",
            "test_category": "System",
            "weight": 0.10,
            "result_type": "numeric",
            "range_1_min": 0,
            "range_1_max": 64,
            "range_2_min": 65,
            "range_2_max": 128,
            "range_3_min": 129,
            "range_3_max": 256,
            "range_4_min": 257,
            "range_4_max": 512,
            "range_5_min": 513,
            "range_5_max": 99999,
            "unit_of_measurement": "GB",
            "is_active": true
        }
    ]
}

# GET /api/test-configs/{test_id}
# Get specific configuration
Response (200):
{
    "id": 2,
    "test_id": "total-memory",
    "test_name": "Total Memory",
    "test_category": "System",
    "weight": 0.10,
    "result_type": "numeric",
    "range_1_min": 0,
    "range_1_max": 64,
    "range_2_min": 65,
    "range_2_max": 128,
    "range_3_min": 129,
    "range_3_max": 256,
    "range_4_min": 257,
    "range_4_max": 512,
    "range_5_min": 513,
    "range_5_max": 99999,
    "unit_of_measurement": "GB",
    "is_active": true
}

# PUT /api/test-configs/{test_id}
# Update configuration ranges/weights
Request Body:
{
    "weight": 0.12,
    "range_1_max": 80,
    "range_2_min": 81
}

Response (200): Updated configuration

# POST /api/test-configs/reset-defaults
# Reset all configurations to defaults
Response (200):
{
    "message": "All test configurations reset to defaults",
    "count_reset": 87
}
```

#### Reports

```python
# POST /api/reports/generate
# Generate report (async)
Query Parameters:
- supplier_id: INTEGER (optional)
- server_id: INTEGER (optional)
- format: STRING (pdf or json)

Response (202 Accepted):
{
    "report_id": "uuid-here",
    "status": "generating",
    "format": "pdf",
    "scope": "supplier",  -- 'supplier', 'server', 'comparison'
    "check_status_url": "/api/reports/uuid-here/status",
    "download_url": "/api/reports/uuid-here/download"
}

# GET /api/reports/{report_id}/status
# Check report generation status
Response (200):
{
    "report_id": "uuid-here",
    "status": "completed",  -- 'generating', 'completed', 'failed'
    "format": "pdf",
    "size_mb": 2.5,
    "generated_at": "2026-01-28T13:57:57Z",
    "expires_at": "2026-02-27T13:57:57Z",
    "download_url": "/api/reports/uuid-here/download"
}

# GET /api/reports/{report_id}/download
# Download generated report
Response (200): File (PDF or JSON)

# GET /api/league-table
# Get supplier league rankings
Query Parameters:
- sort_by: STRING (average, best, median) - default: average
- category: STRING (optional filter by category)
- limit: INTEGER (default 100)

Response (200):
{
    "sort_by": "average",
    "category": null,
    "total": 5,
    "suppliers": [
        {
            "rank": 1,
            "supplier_id": 1,
            "supplier_name": "Dell EMC",
            "average_score": 87.5,
            "best_score": 92,
            "median_score": 87,
            "server_count": 3,
            "category_scores": {
                "system": 85,
                "benchmarks": 90,
                "networking": 88,
                "security": 82
            }
        },
        {
            "rank": 2,
            "supplier_id": 2,
            "supplier_name": "HP Enterprise",
            "average_score": 84.2,
            "best_score": 88,
            "median_score": 84,
            "server_count": 4,
            "category_scores": {
                "system": 82,
                "benchmarks": 87,
                "networking": 85,
                "security": 80
            }
        }
    ]
}
```

---

## Part 3: HTML Enhancement (Modified hpctests.sh)

### 3.1 Changes to HTML Generation

Location: `hpctests.sh` - in `initialize_html_report()` function

Add to `<head>` section:

```bash
cat >> "${OUTPUT_FILE}" << 'EOF'
    <meta name="test-run-id" content="TEST_RUN_ID_HERE" />
    <meta name="test-date" content="TEST_DATE_HERE" />
    <meta name="hostname" content="HOSTNAME_HERE" />
    <meta name="ip-address" content="IP_ADDRESS_HERE" />
    <meta name="make" content="MAKE_HERE" />
    <meta name="model" content="MODEL_HERE" />
EOF
```

### 3.2 Modify HTML Row Generation

Location: `add_row_to_html_report()` function

Change from:
```bash
echo "<tr><td>${test_name}</td><td>${sanitized_cmd}</td><td><pre>${sanitized_result}</pre></td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
```

To:
```bash
# Generate test_id from test_name (lowercase, spaces to underscores)
local test_id=$(echo "$test_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g')
local test_category="CATEGORY_NAME"  # Set based on context

echo "<tr data-test-id=\"${test_id}\" data-test-name=\"${test_name}\" data-category=\"${test_category}\" data-result=\"${result}\" data-result-type=\"text\" data-status=\"${status_raw}\"><td>${test_name}</td><td>${sanitized_cmd}</td><td><pre>${sanitized_result}</pre></td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
```

### 3.3 Add JSON Block at End of HTML

Location: `finalize_html_report()` function - before closing `</body>`

```bash
cat >> "${OUTPUT_FILE}" << 'EOF'
    <script type="application/json" id="test-data">
    {
      "test_run_id": "TEST_RUN_ID_HERE",
      "test_date": "TEST_DATE_HERE",
      "server_info": {
        "hostname": "HOSTNAME_HERE",
        "ip_address": "IP_ADDRESS_HERE",
        "make": "MAKE_HERE",
        "model": "MODEL_HERE"
      },
      "tests": [
        {
          "test_id": "test_id_here",
          "test_name": "Test Name",
          "category": "Category",
          "command": "command here",
          "result": "result here",
          "result_type": "text",
          "status": "pass",
          "notes": ""
        }
      ]
    }
    </script>
EOF
```

---

## Part 4: Analysis Service (Celery Tasks)

### 4.1 Scoring Algorithm Implementation

```python
# app/utils/scorer.py

def calculate_test_score(test_result, config):
    """
    Calculate score (0-100) for a single test based on its configuration.
    """
    result = test_result['result']
    
    if config.result_type == 'boolean':
        # Boolean: yes = yes_score, no = no_score
        result_lower = str(result).lower()
        if result_lower in ['yes', 'true', '1', 'pass']:
            return float(config.boolean_yes_score)
        else:
            return float(config.boolean_no_score)
    
    elif config.result_type == 'numeric':
        # Numeric: match to range
        try:
            value = float(result)
        except:
            return 0  # Invalid numeric value
        
        # Check ranges (1-5 correspond to score ranges)
        ranges = [
            (config.range_1_min, config.range_1_max, 20),
            (config.range_2_min, config.range_2_max, 40),
            (config.range_3_min, config.range_3_max, 60),
            (config.range_4_min, config.range_4_max, 80),
            (config.range_5_min, config.range_5_max, 100)
        ]
        
        for range_min, range_max, score in ranges:
            if range_min is not None and range_max is not None:
                if range_min <= value <= range_max:
                    return float(score)
        
        # Value outside all ranges - return 0
        return 0.0
    
    else:  # text
        # Text results don't score
        return 0.0

def calculate_category_score(test_results, configs, category):
    """
    Calculate weighted score for a category.
    Returns score 0-100.
    """
    category_tests = [
        t for t in test_results 
        if t['test_category'].lower() == category.lower()
    ]
    
    if not category_tests:
        return 0.0
    
    total_weight = 0.0
    weighted_sum = 0.0
    
    for test in category_tests:
        config = next((c for c in configs if c.test_id == test['test_id']), None)
        if not config or not config.is_active:
            continue
        
        test_score = calculate_test_score(test, config)
        weight = float(config.weight)
        
        weighted_sum += test_score * weight
        total_weight += weight
    
    if total_weight == 0:
        return 0.0
    
    return weighted_sum / total_weight

def calculate_overall_score(test_results, configs):
    """
    Calculate overall server score (0-100) using weighted categories.
    
    Weights:
    - System: 20%
    - Benchmarks: 35%
    - Networking: 35%
    - Security: 10%
    """
    category_weights = {
        'system': 0.20,
        'benchmarks': 0.35,
        'networking': 0.35,
        'security': 0.10
    }
    
    scores = {}
    for category in category_weights.keys():
        scores[category] = calculate_category_score(test_results, configs, category)
    
    overall = (
        scores['system'] * category_weights['system'] +
        scores['benchmarks'] * category_weights['benchmarks'] +
        scores['networking'] * category_weights['networking'] +
        scores['security'] * category_weights['security']
    )
    
    return overall, scores

def get_color_grade(score):
    """
    Return color grade based on score (0-100).
    """
    if score >= 81:
        return 'green'
    elif score >= 61:
        return 'light_green'
    elif score >= 41:
        return 'yellow'
    elif score >= 21:
        return 'orange'
    else:
        return 'red'
```

### 4.2 Celery Task Definitions

```python
# app/tasks/celery_tasks.py

from celery import shared_task
import json
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import ServerScores, SupplierScores, Servers
from app.utils.scorer import calculate_overall_score, get_color_grade

@shared_task
def calculate_server_score(server_id, version):
    """
    Calculate and store server score for a specific version.
    """
    db = SessionLocal()
    try:
        # Get all test results for this server/version
        test_results = db.query(TestResults).filter(
            TestResults.server_id == server_id,
            TestResults.version == version
        ).all()
        
        # Get test configurations
        configs = db.query(TestConfigurations).filter(
            TestConfigurations.is_active == True
        ).all()
        
        # Calculate scores
        overall_score, category_scores = calculate_overall_score(test_results, configs)
        color_grade = get_color_grade(overall_score)
        
        # Store or update server_scores
        server_score = db.query(ServerScores).filter(
            ServerScores.server_id == server_id
        ).first()
        
        if server_score:
            server_score.version = version
            server_score.overall_score = overall_score
            server_score.score_breakdown = json.dumps(category_scores)
            server_score.color_grade = color_grade
            server_score.calculated_at = datetime.now()
        else:
            server_score = ServerScores(
                server_id=server_id,
                version=version,
                overall_score=overall_score,
                score_breakdown=json.dumps(category_scores),
                color_grade=color_grade
            )
            db.add(server_score)
        
        db.commit()
        
        # Trigger league recalculation
        recalculate_supplier_league.delay()
        
        return {'status': 'success', 'overall_score': overall_score}
    
    finally:
        db.close()

@shared_task
def recalculate_supplier_league():
    """
    Recalculate all supplier scores and rankings.
    """
    db = SessionLocal()
    try:
        suppliers = db.query(Suppliers).all()
        
        for supplier in suppliers:
            servers = db.query(Servers).filter(
                Servers.supplier_id == supplier.id
            ).all()
            
            if not servers:
                continue
            
            server_ids = [s.id for s in servers]
            scores = db.query(ServerScores).filter(
                ServerScores.server_id.in_(server_ids)
            ).all()
            
            if not scores:
                continue
            
            score_values = [s.overall_score for s in scores]
            avg_score = sum(score_values) / len(score_values)
            best_score = max(score_values)
            median_score = sorted(score_values)[len(score_values) // 2]
            
            # Calculate category averages
            category_scores = {}
            for category in ['system', 'benchmarks', 'networking', 'security']:
                category_avgs = []
                for score in scores:
                    breakdown = json.loads(score.score_breakdown)
                    if category in breakdown:
                        category_avgs.append(breakdown[category])
                
                if category_avgs:
                    category_scores[category] = sum(category_avgs) / len(category_avgs)
            
            # Store or update supplier_scores
            supplier_score = db.query(SupplierScores).filter(
                SupplierScores.supplier_id == supplier.id
            ).first()
            
            if supplier_score:
                supplier_score.average_score = avg_score
                supplier_score.best_score = best_score
                supplier_score.median_score = median_score
                supplier_score.server_count = len(servers)
                supplier_score.category_scores = json.dumps(category_scores)
                supplier_score.updated_at = datetime.now()
            else:
                supplier_score = SupplierScores(
                    supplier_id=supplier.id,
                    average_score=avg_score,
                    best_score=best_score,
                    median_score=median_score,
                    server_count=len(servers),
                    category_scores=json.dumps(category_scores)
                )
                db.add(supplier_score)
        
        db.commit()
        return {'status': 'success', 'suppliers_updated': len(suppliers)}
    
    finally:
        db.close()

@shared_task
def generate_pdf_report(report_id):
    """
    Generate PDF report asynchronously.
    """
    # Implementation with ReportLab
    # Updates analysis_reports table with pdf_path
    pass

@shared_task
def cleanup_old_reports():
    """
    Scheduled task to clean up old reports (>30 days).
    Runs daily via APScheduler.
    """
    db = SessionLocal()
    try:
        cutoff_date = datetime.now() - timedelta(days=30)
        old_reports = db.query(AnalysisReports).filter(
            AnalysisReports.created_at < cutoff_date
        ).all()
        
        for report in old_reports:
            if report.pdf_path and os.path.exists(report.pdf_path):
                os.remove(report.pdf_path)
            db.delete(report)
        
        db.commit()
        return {'status': 'success', 'reports_deleted': len(old_reports)}
    
    finally:
        db.close()
```

---

## Part 5: Implementation Checklist

### Phase 1: Foundation
- [ ] Set up PostgreSQL database
- [ ] Run database schema creation SQL
- [ ] Create FastAPI project structure
- [ ] Implement database models (SQLAlchemy)
- [ ] Implement suppliers endpoints (CRUD)
- [ ] Implement servers endpoints (GET, history)
- [ ] Create Pydantic schemas
- [ ] Set up environment configuration

### Phase 2: HTML Parsing & Upload
- [ ] Create HTML parser utility
- [ ] Implement upload endpoint
- [ ] Extract server info from HTML metadata
- [ ] Parse test results from HTML
- [ ] Store raw HTML in database
- [ ] Implement versioning logic
- [ ] Add data validation

### Phase 3: Analysis Engine
- [ ] Set up Celery with Redis/RabbitMQ
- [ ] Implement scoring algorithm
- [ ] Implement category calculations
- [ ] Create test configuration table & CRUD
- [ ] Implement server_scores caching
- [ ] Implement supplier_scores league table
- [ ] Set up APScheduler for background jobs

### Phase 4: Web Frontend
- [ ] Create Flask/Dash application
- [ ] Implement upload form UI
- [ ] Implement supplier management UI
- [ ] Implement test config UI
- [ ] Create server dashboard
- [ ] Create league table view (with sorting)
- [ ] Create category-specific rankings

### Phase 5: Reporting
- [ ] Implement PDF report generation (ReportLab)
- [ ] Create report templates
- [ ] Implement report caching
- [ ] Implement cleanup task
- [ ] Test report generation

### Phase 6: Testing & Deployment
- [ ] Write unit tests (pytest)
- [ ] Write integration tests
- [ ] Load testing
- [ ] Docker containerization
- [ ] Deploy to Ubuntu 24.04
- [ ] Set up Nginx reverse proxy
- [ ] Configure Gunicorn

---

## Part 6: Development Setup Guide

### Install Dependencies

```bash
# Python packages
pip install fastapi uvicorn sqlalchemy psycopg2-binary pydantic python-multipart
pip install celery redis flower
pip install reportlab
pip install flask dash plotly

# System packages (Ubuntu 24.04)
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib python3-dev

# Optional: Redis for Celery
sudo apt-get install -y redis-server
```

### Initialize Database

```bash
# Create PostgreSQL database
psql -U postgres -c "CREATE DATABASE hpc_test_platform;"

# Run schema (from PLATFORM_IMPLEMENTATION_SPEC.md Part 1)
psql -U postgres -d hpc_test_platform -f schema.sql
```

### Environment Configuration

```bash
# .env file
DATABASE_URL=postgresql://user:password@localhost:5432/hpc_test_platform
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key-here
DEBUG=False
LOG_LEVEL=INFO
```

---

## Next Steps

1. **Review** this specification with your team
2. **Setup** PostgreSQL and create schema
3. **Scaffold** FastAPI project structure
4. **Implement** Phase 1 (suppliers, servers)
5. **Test** HTML parsing with sample files
6. **Implement** Phase 2 (uploads)
7. **Setup** Celery and APScheduler
8. **Implement** Phase 3 (analysis engine)

Ready to start implementation? 🚀
