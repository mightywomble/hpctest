# HPC Test Results Analysis Platform

Complete system design and implementation specifications for analyzing HPC test results, ranking suppliers, and generating performance reports.

## 📚 Documentation Index

### 1. **REFACTOR_README.md** (In parent hpctests directory)
   - High-level system design overview
   - Architecture diagram
   - Directory structure
   - Service breakdown (API, Analysis, Frontend, Database)
   - Technology stack
   - Key design decisions
   - **Start here** for understanding the overall architecture

### 2. **PLATFORM_IMPLEMENTATION_SPEC.md** (This directory)
   - **Part 1**: Complete PostgreSQL database schema (SQL)
   - **Part 2**: FastAPI service specifications & endpoints
   - **Part 3**: HTML enhancement strategy (modifications to hpctests.sh)
   - **Part 4**: Analysis service (Celery tasks, scoring algorithm)
   - **Part 5**: Implementation checklist (6 phases)
   - **Part 6**: Development setup guide
   - **Start here** for implementation details

---

## 🎯 Quick Overview

### System Flow

```
Engineer uploads HTML
         ↓
API validates & extracts server info
         ↓
Tests parsed from HTML JSON block
         ↓
Celery calculates scores (async)
         ↓
Server scores cached (0-100)
         ↓
Supplier league updated
         ↓
Web dashboard shows rankings
         ↓
Reports generated on demand (PDF)
```

### Key Features

✅ **HTML-based workflow** - Engineers upload test results as HTML files  
✅ **Automatic extraction** - Server info (hostname, IP, make, model) auto-detected  
✅ **Configurable scoring** - Per-test score ranges defined in web UI  
✅ **Category weighting** - System 20%, Benchmarks 35%, Networking 35%, Security 10%  
✅ **Color-coded results** - Red (0-20) → Orange (21-40) → Yellow (41-60) → Light Green (61-80) → Green (81-100)  
✅ **Multiple rankings** - Sort suppliers by average/best/median score  
✅ **Category rankings** - See best performers per category  
✅ **Version history** - Track trends over time  
✅ **PDF reports** - On-demand downloadable reports  
✅ **Modular services** - API, Analysis, Frontend independent & scalable  

---

## 🛠️ Implementation Phases

### Phase 1: Foundation (1-2 weeks)
Database setup and basic CRUD API

- [ ] PostgreSQL database with schema
- [ ] FastAPI project scaffold
- [ ] Suppliers and Servers endpoints
- [ ] Basic upload endpoint

### Phase 2: HTML Parsing (1 week)
Parsing test results from HTML files

- [ ] HTML parser utility
- [ ] Extract server info from metadata
- [ ] Parse test results
- [ ] Versioning logic

### Phase 3: Analysis Engine (2 weeks)
Scoring and league calculations

- [ ] Celery task queue setup
- [ ] Scoring algorithm implementation
- [ ] Server score caching
- [ ] Supplier league generation

### Phase 4: Web Frontend (2-3 weeks)
User interface for uploads and dashboards

- [ ] Upload form UI
- [ ] Dashboard with server info
- [ ] League table view
- [ ] Category rankings

### Phase 5: Reporting (1-2 weeks)
PDF report generation

- [ ] ReportLab integration
- [ ] Report templates
- [ ] On-demand generation
- [ ] PDF downloads

### Phase 6: Testing & Deployment (1-2 weeks)
Quality assurance and production deployment

- [ ] Unit and integration tests
- [ ] Docker containerization
- [ ] Ubuntu 24.04 deployment
- [ ] Nginx reverse proxy setup

---

## 📊 Database Schema Summary

### Core Tables

| Table | Purpose |
|-------|---------|
| `suppliers` | Supplier company information |
| `servers` | Server inventory (1:1 with supplier) |
| `test_results` | Versioned test results |
| `test_configurations` | Scoring ranges per test |
| `server_scores` | Cached server scores |
| `supplier_scores` | League table rankings |
| `analysis_reports` | Generated reports |

---

## 🔌 API Endpoints

### Suppliers
```
POST   /api/suppliers              Create supplier
GET    /api/suppliers              List suppliers
GET    /api/suppliers/{id}         Get supplier details
PUT    /api/suppliers/{id}         Update supplier
DELETE /api/suppliers/{id}         Delete supplier
```

### Uploads
```
POST   /api/uploads                Upload HTML file
GET    /api/uploads/{id}/status    Check processing status
```

### Test Configuration
```
GET    /api/test-configs           List all configs
GET    /api/test-configs/{id}      Get specific config
PUT    /api/test-configs/{id}      Update config
POST   /api/test-configs/reset     Reset to defaults
```

### Reports & League
```
POST   /api/reports/generate       Generate report (async)
GET    /api/reports/{id}/status    Check generation status
GET    /api/reports/{id}/download  Download report
GET    /api/league-table           Get supplier rankings
```

---

## 🔧 Technology Stack

### Backend
- **FastAPI** - REST API framework
- **SQLAlchemy** - ORM
- **Celery** - Async task queue
- **APScheduler** - Scheduled jobs
- **ReportLab** - PDF generation

### Database
- **PostgreSQL 14+** - Single instance

### Frontend
- **Flask/Dash** or **React** - Dashboard UI
- **Bootstrap** - Styling

### Deployment
- **Docker** - Containerization
- **Gunicorn** - WSGI server
- **Nginx** - Reverse proxy
- **Ubuntu 24.04** - OS

---

## 📋 HTML Enhancement Requirements

Enhanced HTML files must include:

### 1. Metadata in `<head>`
```html
<meta name="test-run-id" content="uuid-here" />
<meta name="test-date" content="2026-01-28T13:57:57Z" />
<meta name="hostname" content="server-hostname" />
<meta name="ip-address" content="192.168.1.100" />
<meta name="make" content="Dell" />
<meta name="model" content="PowerEdge R7625" />
```

### 2. Data attributes on test rows
```html
<tr data-test-id="cpu-model" data-test-name="CPU Model"
    data-category="System" data-result="Intel..." 
    data-result-type="text" data-status="pass">
```

### 3. JSON block before `</body>`
```html
<script type="application/json" id="test-data">
{
  "test_run_id": "uuid",
  "test_date": "2026-01-28T...",
  "server_info": { ... },
  "tests": [ ... ]
}
</script>
```

---

## 📈 Scoring System

### Test Scoring
- **Boolean tests**: Yes = 100, No = 0
- **Numeric tests**: Mapped to 0-20, 21-40, 41-60, 61-80, 81-100 ranges
- **Text tests**: No scoring (0 points)

### Category Scoring
```
System (20%):
  - System info, CPU, RAM, Storage tests

Benchmarks (35%):
  - HPL, GPU-burn tests

Networking (35%):
  - Ethernet, InfiniBand, Speedtest tests

Security (10%):
  - SSH, permissions, account tests
```

### Overall Score
```
Overall = (System × 0.20) + (Benchmarks × 0.35) + 
          (Networking × 0.35) + (Security × 0.10)
```

### Color Grades
- 🔴 **Red** (0-20)
- 🟠 **Orange** (21-40)
- 🟡 **Yellow** (41-60)
- 🟢 **Light Green** (61-80)
- 🟢 **Dark Green** (81-100)

---

## 🚀 Getting Started

### Prerequisites
- PostgreSQL 14+
- Python 3.10+
- Redis (for Celery)
- Ubuntu 24.04 (recommended)

### Quick Setup

```bash
# 1. Clone and navigate
cd /path/to/hpc-test-platform

# 2. Create PostgreSQL database
psql -U postgres -c "CREATE DATABASE hpc_test_platform;"

# 3. Run schema
psql -U postgres -d hpc_test_platform -f schema.sql

# 4. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 5. Install dependencies
pip install -r requirements.txt

# 6. Configure environment
cp .env.example .env
# Edit .env with your settings

# 7. Start services
# Terminal 1: FastAPI
uvicorn app.main:app --reload

# Terminal 2: Celery worker
celery -A app.tasks.celery_tasks worker -l info

# Terminal 3: Frontend
python app/frontend/app.py
```

---

## 📖 Detailed Guides

For detailed implementation information, see:

1. **Database Design** → PLATFORM_IMPLEMENTATION_SPEC.md (Part 1)
2. **API Endpoints** → PLATFORM_IMPLEMENTATION_SPEC.md (Part 2)
3. **HTML Parsing** → PLATFORM_IMPLEMENTATION_SPEC.md (Part 3)
4. **Scoring Algorithm** → PLATFORM_IMPLEMENTATION_SPEC.md (Part 4)
5. **Checklist & Setup** → PLATFORM_IMPLEMENTATION_SPEC.md (Part 5-6)

---

## ✅ Success Criteria

After implementation, the system should:

- ✅ Accept HTML uploads with server metadata
- ✅ Automatically extract server info (hostname, IP, make, model)
- ✅ Parse test results from enhanced HTML
- ✅ Store versioned test results
- ✅ Calculate scores based on configurable ranges
- ✅ Generate per-test, category, and overall scores
- ✅ Maintain supplier league rankings (average/best/median)
- ✅ Provide category-specific rankings
- ✅ Generate on-demand PDF reports
- ✅ Display color-coded dashboards
- ✅ Track trends over time (version history)
- ✅ Run independently scalable services

---

## 🤝 Team Assignments

Suggested team breakdown:

**Backend Team (2 engineers)**
- Phase 1-2: Database + API + HTML parsing
- Phase 3: Analysis engine

**Frontend Team (1-2 engineers)**
- Phase 4: Web UI + dashboards
- Phase 5: PDF reports

**DevOps/QA (1 engineer)**
- Phase 6: Testing + deployment
- Ongoing: Monitoring + maintenance

---

## 📞 Support

For questions about:
- **Architecture**: See REFACTOR_README.md
- **Implementation**: See PLATFORM_IMPLEMENTATION_SPEC.md
- **Scoring logic**: See PLATFORM_IMPLEMENTATION_SPEC.md (Part 4)
- **API design**: See PLATFORM_IMPLEMENTATION_SPEC.md (Part 2)

---

## 📝 Version

- **Created**: 2026-01-28
- **Status**: Design Complete - Ready for Implementation
- **Target Platform**: Ubuntu 24.04 LTS
- **Python Version**: 3.10+

---

**Ready to build the HPC Test Results Analysis Platform!** 🚀
