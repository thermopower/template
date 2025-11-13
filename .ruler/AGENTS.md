# Korean Text
 코드를 생성한 후에 utf-8 기준으로 깨지는 한글이 있는지 확인해주세요. 만약 있다면 수정해주세요.
 항상 한국어로 응답하세요.

# 절대 금지 사항 (Strict Prohibitions)
- 설계 문서의 근거 없이 코드를 수정하는 행위.
- 코드의 내용을 기준으로 설계 문서를 역으로 수정하려는 시도. (단, 사용자가 명시적으로 허용한 경우는 제외)
- 설계가 불분명하다는 이유로 임의의 로직을 추측하여 구현하는 행위.

---

# Codebase Architecture Document

## Project Overview
대학교 사내 데이터 시각화 대시보드 프로젝트 - Django REST Framework + React + Supabase

## Architecture Pattern
**Layered Architecture with SOLID Principles**

이 프로젝트는 명확한 계층 분리와 SOLID 원칙을 준수하여 유지보수성, 확장성, 테스트 용이성을 극대화합니다.

---

## Core Architectural Principles

### 1. Presentation Layer Separation
- **원칙**: Presentation은 반드시 Business Logic과 분리되어야 합니다.
- **적용**:
  - Frontend(React)는 UI/UX만 담당하며, 비즈니스 로직을 포함하지 않습니다.
  - Backend에서는 API Views가 HTTP 요청/응답만 처리하고, 비즈니스 로직은 Service Layer에 위임합니다.

### 2. Business Logic Isolation
- **원칙**: Pure Business Logic은 반드시 Persistence Layer와 분리되어야 합니다.
- **적용**:
  - Service Layer는 순수 비즈니스 로직만 포함하며, 데이터베이스 접근은 Repository Layer를 통해서만 수행합니다.
  - 비즈니스 로직은 ORM 모델에 직접 의존하지 않고, Domain Model을 사용합니다.

### 3. External Integration Separation
- **원칙**: Internal Logic은 반드시 외부연동 Contract, Caller와 분리되어야 합니다.
- **적용**:
  - External Integration Layer는 외부 서비스(Supabase Auth, File Storage 등)와의 연동을 캡슐화합니다.
  - 내부 로직은 인터페이스를 통해 외부 서비스를 호출하여, 외부 서비스 변경 시 영향을 최소화합니다.

### 4. Single Responsibility Principle
- **원칙**: 하나의 모듈은 반드시 하나의 책임을 가져야 합니다.
- **적용**:
  - 각 클래스와 함수는 단일 책임만 가지며, 명확한 이름으로 의도를 표현합니다.
  - 예: `ExcelParser`는 엑셀 파싱만, `DashboardService`는 대시보드 비즈니스 로직만 담당합니다.

---

## Technology Stack

### Backend
- **Framework**: Django 5.x + Django REST Framework
- **Language**: Python 3.11+
- **Database**: Supabase (PostgreSQL 관리형)
- **ORM**: Django ORM
- **Authentication**: Supabase Auth (JWT 기반)
- **File Processing**: openpyxl, pandas
- **Deployment**: Railway

### Frontend
- **Framework**: React 18 + TypeScript + Vite
- **UI Library**: Material-UI (MUI)
- **Charts**: Recharts
- **Authentication**: @supabase/supabase-js
- **HTTP Client**: Axios
- **Routing**: React Router
- **Deployment**: Vercel 또는 Railway

### Database & Auth
- **Primary**: Supabase (PostgreSQL + Auth)
- **Driver**: psycopg2-binary

---

## Backend Architecture (Django)

### Layered Structure

```
┌─────────────────────────────────────────────────────────────┐
│                   Presentation Layer                        │
│              (API Views, Serializers)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP Requests/Responses
┌─────────────────────▼───────────────────────────────────────┐
│                   Service Layer                             │
│              (Business Logic)                               │
└─────────────────────┬───────────────────────────────────────┘
                      │ Domain Models
┌─────────────────────▼───────────────────────────────────────┐
│                   Repository Layer                          │
│              (Data Access Abstraction)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │ ORM Operations
┌─────────────────────▼───────────────────────────────────────┐
│                   Persistence Layer                         │
│              (Django ORM Models, Database)                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│            External Integration Layer                       │
│   (Supabase Auth, File Storage, Email Service)             │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
backend/
├── config/                          # Django Project Configuration
│   ├── __init__.py
│   ├── settings/                    # Split settings for environments
│   │   ├── __init__.py
│   │   ├── base.py                  # Common settings
│   │   ├── development.py           # Dev-specific settings
│   │   └── production.py            # Production settings
│   ├── urls.py                      # Root URL configuration
│   ├── wsgi.py                      # WSGI entry point
│   └── asgi.py                      # ASGI entry point (optional)
│
├── apps/                            # Django Applications
│   │
│   ├── core/                        # Core/Shared App
│   │   ├── __init__.py
│   │   ├── models.py                # Abstract base models
│   │   ├── exceptions.py            # Custom exceptions
│   │   ├── validators.py            # Common validators
│   │   └── utils.py                 # Utility functions
│   │
│   ├── dashboard/                   # Dashboard Feature App
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   │
│   │   ├── presentation/            # Presentation Layer
│   │   │   ├── __init__.py
│   │   │   ├── views.py             # API ViewSets (HTTP handling only)
│   │   │   ├── serializers.py       # Request/Response serialization
│   │   │   └── urls.py              # URL routing
│   │   │
│   │   ├── services/                # Service Layer (Business Logic)
│   │   │   ├── __init__.py
│   │   │   ├── dashboard_service.py # Dashboard business logic
│   │   │   ├── metric_calculator.py # Metric calculation logic
│   │   │   └── chart_data_builder.py # Chart data transformation
│   │   │
│   │   ├── repositories/            # Repository Layer (Data Access)
│   │   │   ├── __init__.py
│   │   │   ├── performance_repository.py
│   │   │   ├── paper_repository.py
│   │   │   ├── student_repository.py
│   │   │   └── budget_repository.py
│   │   │
│   │   ├── domain/                  # Domain Layer (Business Models)
│   │   │   ├── __init__.py
│   │   │   ├── models.py            # Domain models (dataclasses/Pydantic)
│   │   │   └── value_objects.py     # Value objects
│   │   │
│   │   ├── persistence/             # Persistence Layer (ORM Models)
│   │   │   ├── __init__.py
│   │   │   └── models.py            # Django ORM models
│   │   │
│   │   ├── tests/                   # Tests for Dashboard app
│   │   │   ├── __init__.py
│   │   │   ├── test_views.py
│   │   │   ├── test_services.py
│   │   │   └── test_repositories.py
│   │   │
│   │   └── migrations/              # Database migrations
│   │       └── __init__.py
│   │
│   ├── uploads/                     # File Upload Feature App
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   │
│   │   ├── presentation/            # Presentation Layer
│   │   │   ├── __init__.py
│   │   │   ├── views.py             # Upload API views
│   │   │   ├── serializers.py       # File upload serializers
│   │   │   └── urls.py
│   │   │
│   │   ├── services/                # Service Layer
│   │   │   ├── __init__.py
│   │   │   ├── excel_parser.py      # Excel file parsing logic
│   │   │   ├── data_validator.py    # Data validation logic
│   │   │   └── file_processor.py    # File processing orchestration
│   │   │
│   │   ├── repositories/            # Repository Layer
│   │   │   ├── __init__.py
│   │   │   └── file_repository.py   # File metadata storage
│   │   │
│   │   ├── domain/                  # Domain Layer
│   │   │   ├── __init__.py
│   │   │   └── models.py            # File upload domain models
│   │   │
│   │   ├── persistence/             # Persistence Layer
│   │   │   ├── __init__.py
│   │   │   └── models.py            # UploadedFile ORM model
│   │   │
│   │   ├── external/                # External Integration Layer
│   │   │   ├── __init__.py
│   │   │   └── file_storage.py      # File storage abstraction
│   │   │
│   │   └── tests/
│   │       ├── __init__.py
│   │       └── test_excel_parser.py
│   │
│   └── accounts/                    # User Account Feature App
│       ├── __init__.py
│       ├── apps.py
│       │
│       ├── presentation/            # Presentation Layer
│       │   ├── __init__.py
│       │   ├── views.py             # User profile API views
│       │   ├── serializers.py       # User profile serializers
│       │   └── urls.py
│       │
│       ├── services/                # Service Layer
│       │   ├── __init__.py
│       │   └── profile_service.py   # Profile management logic
│       │
│       ├── repositories/            # Repository Layer
│       │   ├── __init__.py
│       │   └── user_repository.py   # User data access
│       │
│       ├── domain/                  # Domain Layer
│       │   ├── __init__.py
│       │   └── models.py            # User domain models
│       │
│       ├── persistence/             # Persistence Layer
│       │   ├── __init__.py
│       │   └── models.py            # UserProfile ORM model
│       │
│       ├── external/                # External Integration Layer
│       │   ├── __init__.py
│       │   └── supabase_auth.py     # Supabase Auth integration
│       │
│       └── tests/
│           └── __init__.py
│
├── infrastructure/                  # Infrastructure Layer
│   ├── __init__.py
│   ├── middleware/                  # Custom middleware
│   │   ├── __init__.py
│   │   ├── auth_middleware.py       # Supabase JWT verification
│   │   └── logging_middleware.py    # Request/response logging
│   │
│   ├── authentication/              # Authentication infrastructure
│   │   ├── __init__.py
│   │   ├── backends.py              # Custom auth backends
│   │   └── jwt_validator.py         # JWT token validation
│   │
│   └── external_services/           # External service clients
│       ├── __init__.py
│       ├── supabase_client.py       # Supabase Python client
│       └── email_service.py         # Email service (optional)
│
├── tests/                           # Integration tests
│   ├── __init__.py
│   ├── conftest.py                  # Pytest fixtures
│   ├── integration/
│   │   └── test_api_integration.py
│   └── e2e/
│       └── test_user_flows.py
│
├── scripts/                         # Utility scripts
│   ├── seed_data.py                 # Database seeding
│   └── import_excel.py              # Manual Excel import
│
├── media/                           # User uploaded files
│   └── uploads/
│       └── excel/
│
├── static/                          # Static files (collected)
│
├── requirements/                    # Python dependencies
│   ├── base.txt                     # Common dependencies
│   ├── development.txt              # Dev dependencies
│   └── production.txt               # Production dependencies
│
├── .env.example                     # Environment variable template
├── .gitignore
├── manage.py                        # Django management script
├── pytest.ini                       # Pytest configuration
├── railway.toml                     # Railway deployment config
└── README.md                        # Project documentation
```

---

## Frontend Architecture (React)

### Layered Structure

```
┌─────────────────────────────────────────────────────────────┐
│                   Presentation Layer                        │
│              (Pages, Components)                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ User Interactions
┌─────────────────────▼───────────────────────────────────────┐
│                   Application Layer                         │
│              (Hooks, Context, State Management)             │
└─────────────────────┬───────────────────────────────────────┘
                      │ Domain Models
┌─────────────────────▼───────────────────────────────────────┐
│                   Service Layer                             │
│              (API Services, Data Transformation)            │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP Requests
┌─────────────────────▼───────────────────────────────────────┐
│                   External Integration Layer                │
│              (Axios, Supabase Client)                       │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
frontend/
├── public/                          # Static assets
│   ├── favicon.ico
│   └── logo.png
│
├── src/
│   │
│   ├── presentation/                # Presentation Layer
│   │   │
│   │   ├── pages/                   # Page components (routes)
│   │   │   ├── LoginPage.tsx        # Login page
│   │   │   ├── DashboardPage.tsx    # Main dashboard page
│   │   │   ├── UploadPage.tsx       # Excel upload page
│   │   │   ├── DataViewPage.tsx     # Raw data view page
│   │   │   └── ProfilePage.tsx      # User profile page
│   │   │
│   │   ├── components/              # Reusable UI components
│   │   │   ├── layout/              # Layout components
│   │   │   │   ├── AppLayout.tsx    # Main layout wrapper
│   │   │   │   ├── Navbar.tsx       # Navigation bar
│   │   │   │   ├── Sidebar.tsx      # Side navigation
│   │   │   │   └── Footer.tsx       # Footer
│   │   │   │
│   │   │   ├── charts/              # Chart components
│   │   │   │   ├── BarChart.tsx     # Bar chart wrapper
│   │   │   │   ├── LineChart.tsx    # Line chart wrapper
│   │   │   │   ├── PieChart.tsx     # Pie chart wrapper
│   │   │   │   └── MetricCard.tsx   # Metric display card
│   │   │   │
│   │   │   ├── forms/               # Form components
│   │   │   │   ├── LoginForm.tsx    # Login form
│   │   │   │   ├── UploadForm.tsx   # File upload form
│   │   │   │   └── ProfileForm.tsx  # Profile edit form
│   │   │   │
│   │   │   └── common/              # Common components
│   │   │       ├── Button.tsx       # Custom button
│   │   │       ├── Input.tsx        # Custom input
│   │   │       ├── Loading.tsx      # Loading spinner
│   │   │       ├── ErrorMessage.tsx # Error display
│   │   │       └── Modal.tsx        # Modal dialog
│   │   │
│   │   └── styles/                  # Component styles (if not using CSS-in-JS)
│   │       └── theme.ts             # MUI theme customization
│   │
│   ├── application/                 # Application Layer
│   │   │
│   │   ├── hooks/                   # Custom React hooks
│   │   │   ├── useAuth.ts           # Authentication hook
│   │   │   ├── useDashboard.ts      # Dashboard data hook
│   │   │   ├── useUpload.ts         # File upload hook
│   │   │   └── useDebounce.ts       # Utility hooks
│   │   │
│   │   ├── contexts/                # React Context providers
│   │   │   ├── AuthContext.tsx      # Authentication context
│   │   │   ├── ThemeContext.tsx     # Theme context (optional)
│   │   │   └── NotificationContext.tsx # Notification context
│   │   │
│   │   └── state/                   # State management (optional: Zustand/Redux)
│   │       └── store.ts             # Global state store
│   │
│   ├── domain/                      # Domain Layer
│   │   ├── models/                  # TypeScript interfaces/types
│   │   │   ├── User.ts              # User domain model
│   │   │   ├── Dashboard.ts         # Dashboard data model
│   │   │   ├── Chart.ts             # Chart data model
│   │   │   └── Upload.ts            # Upload model
│   │   │
│   │   └── enums/                   # Enumerations
│   │       └── ChartType.ts         # Chart type enum
│   │
│   ├── services/                    # Service Layer
│   │   ├── api/                     # API service clients
│   │   │   ├── client.ts            # Axios instance with interceptors
│   │   │   ├── dashboardApi.ts      # Dashboard API calls
│   │   │   ├── uploadApi.ts         # Upload API calls
│   │   │   └── accountApi.ts        # Account API calls
│   │   │
│   │   └── transformers/            # Data transformation
│   │       ├── chartTransformer.ts  # Transform API data to chart format
│   │       └── dateTransformer.ts   # Date formatting utilities
│   │
│   ├── infrastructure/              # Infrastructure Layer
│   │   │
│   │   ├── external/                # External service integrations
│   │   │   ├── supabase.ts          # Supabase client initialization
│   │   │   └── authService.ts       # Supabase Auth service
│   │   │
│   │   ├── routing/                 # Routing configuration
│   │   │   ├── routes.tsx           # Route definitions
│   │   │   ├── PrivateRoute.tsx     # Protected route wrapper
│   │   │   └── PublicRoute.tsx      # Public route wrapper
│   │   │
│   │   └── config/                  # Configuration
│   │       ├── env.ts               # Environment variables
│   │       └── constants.ts         # Application constants
│   │
│   ├── utils/                       # Utility functions
│   │   ├── validators.ts            # Validation helpers
│   │   ├── formatters.ts            # Formatting helpers
│   │   └── helpers.ts               # General helpers
│   │
│   ├── assets/                      # Static assets
│   │   ├── images/
│   │   ├── icons/
│   │   └── fonts/
│   │
│   ├── tests/                       # Tests
│   │   ├── unit/                    # Unit tests
│   │   │   └── components/
│   │   ├── integration/             # Integration tests
│   │   └── e2e/                     # End-to-end tests
│   │
│   ├── App.tsx                      # Root component
│   ├── main.tsx                     # Application entry point
│   └── vite-env.d.ts                # Vite type declarations
│
├── .env.example                     # Environment variable template
├── .gitignore
├── index.html                       # HTML entry point
├── package.json                     # npm dependencies
├── tsconfig.json                    # TypeScript configuration
├── vite.config.ts                   # Vite configuration
├── eslint.config.js                 # ESLint configuration
└── README.md                        # Frontend documentation
```

---

## Top-Level Building Blocks

### 1. Presentation Layer
**Responsibility**: Handle HTTP requests/responses and user interface

**Backend Components**:
- `API Views`: Handle HTTP requests, delegate to services, return HTTP responses
- `Serializers`: Validate input data and serialize output data
- `URL Routing`: Map URLs to views

**Frontend Components**:
- `Pages`: Top-level route components
- `Components`: Reusable UI elements
- `Forms`: User input handling

**SOLID Principles Applied**:
- **Single Responsibility**: Views only handle HTTP concerns, no business logic
- **Dependency Inversion**: Views depend on service abstractions, not concrete implementations

### 2. Service Layer (Business Logic)
**Responsibility**: Implement core business rules and orchestrate operations

**Backend Components**:
- `Dashboard Service`: Dashboard metrics calculation and aggregation
- `Excel Parser`: Parse and validate Excel files
- `Data Validator`: Business rule validation
- `Metric Calculator`: Calculate KPIs and statistics

**Frontend Components**:
- `API Services`: Backend communication and data fetching
- `Data Transformers`: Transform API data for UI consumption

**SOLID Principles Applied**:
- **Single Responsibility**: Each service handles one business concern
- **Open/Closed**: Services are open for extension but closed for modification
- **Interface Segregation**: Services expose only necessary methods

**Key Characteristics**:
- Pure business logic, no framework dependencies
- Testable without database or HTTP layer
- Framework-agnostic domain models

### 3. Repository Layer (Data Access Abstraction)
**Responsibility**: Abstract database operations from business logic

**Backend Components**:
- `Performance Repository`: CRUD operations for performance data
- `Paper Repository`: Research paper data access
- `Student Repository`: Student data access
- `Budget Repository`: Budget data access
- `File Repository`: File metadata storage

**SOLID Principles Applied**:
- **Dependency Inversion**: Business logic depends on repository interfaces, not ORM
- **Single Responsibility**: Each repository handles one entity type
- **Liskov Substitution**: Repositories can be swapped without affecting business logic

**Benefits**:
- Business logic is decoupled from ORM
- Easy to switch databases or ORMs
- Simplified testing with mock repositories

### 4. Domain Layer
**Responsibility**: Define core business entities and value objects

**Backend Components**:
- `Domain Models`: Pure Python dataclasses or Pydantic models representing business entities
- `Value Objects`: Immutable objects representing domain concepts (e.g., DateRange, Percentage)

**Frontend Components**:
- `TypeScript Interfaces`: Type definitions for domain entities
- `Enums`: Domain enumerations

**SOLID Principles Applied**:
- **Single Responsibility**: Each domain model represents one business concept
- **Open/Closed**: Domain models can be extended without modification

**Key Characteristics**:
- No framework dependencies (no Django ORM inheritance)
- Portable across layers
- Rich domain behavior encapsulation

### 5. Persistence Layer (Database)
**Responsibility**: Handle database schema and ORM mappings

**Backend Components**:
- `Django ORM Models`: Database table definitions
- `Migrations`: Schema version control

**SOLID Principles Applied**:
- **Single Responsibility**: Models define schema only, no business logic
- **Interface Segregation**: Separate read models from write models if needed

**Key Characteristics**:
- Framework-specific (Django ORM)
- Should not leak into business logic
- Accessed only through repository layer

### 6. External Integration Layer
**Responsibility**: Integrate with external services and APIs

**Backend Components**:
- `Supabase Auth Client`: Authentication integration
- `File Storage Service`: File upload/download abstraction
- `Email Service`: Email sending (optional)

**Frontend Components**:
- `Supabase Client`: Supabase integration
- `Axios Client`: HTTP client with interceptors
- `Auth Service`: Authentication flow management

**SOLID Principles Applied**:
- **Dependency Inversion**: Internal logic depends on interfaces, not concrete clients
- **Single Responsibility**: Each client handles one external service
- **Open/Closed**: Easy to add new external services without modifying existing code

**Benefits**:
- Internal logic is decoupled from external APIs
- Easy to mock external services for testing
- Easy to replace external services (e.g., switch from Supabase to Auth0)

### 7. Infrastructure Layer
**Responsibility**: Provide cross-cutting concerns and framework infrastructure

**Backend Components**:
- `Middleware`: Authentication, logging, error handling
- `JWT Validator`: Token verification
- `Custom Authentication Backend`: Supabase JWT integration with Django

**Frontend Components**:
- `Routing`: Route configuration and guards
- `Configuration`: Environment variables and constants
- `Error Handling`: Global error boundaries

**SOLID Principles Applied**:
- **Single Responsibility**: Each middleware/service has one concern
- **Open/Closed**: Infrastructure can be extended without modifying core logic

---

## Dependency Flow

### Backend Dependency Direction (Inward)
```
Presentation Layer (API Views)
        ↓ depends on
Service Layer (Business Logic)
        ↓ depends on
Repository Layer (Data Access Abstraction)
        ↓ depends on
Persistence Layer (ORM Models)

External Integration Layer → Service Layer (via interfaces)
Infrastructure Layer → All layers (cross-cutting)
```

**Key Rule**: Dependencies point inward. Outer layers depend on inner layers, never vice versa.

### Frontend Dependency Direction
```
Presentation Layer (Pages/Components)
        ↓ depends on
Application Layer (Hooks/Context)
        ↓ depends on
Service Layer (API Services)
        ↓ depends on
Infrastructure Layer (External Clients)

Domain Layer ← All layers depend on domain models
```

---

## SOLID Principles in Practice

### 1. Single Responsibility Principle (SRP)
- **API Views**: Only handle HTTP requests/responses
- **Services**: Only contain business logic
- **Repositories**: Only handle data access
- **Models**: Only define data structure

**Example**:
```python
# BAD: View contains business logic
class DashboardView(APIView):
    def get(self, request):
        performances = Performance.objects.all()
        total = sum(p.amount for p in performances)  # Business logic in view!
        return Response({'total': total})

# GOOD: View delegates to service
class DashboardView(APIView):
    def __init__(self, dashboard_service: DashboardService):
        self.dashboard_service = dashboard_service

    def get(self, request):
        summary = self.dashboard_service.get_dashboard_summary()
        serializer = DashboardSerializer(summary)
        return Response(serializer.data)
```

### 2. Open/Closed Principle (OCP)
- Services are open for extension (inheritance) but closed for modification
- Use strategy pattern for varying algorithms

**Example**:
```python
# Base parser that can be extended
class ExcelParser(ABC):
    @abstractmethod
    def parse(self, file_path: str) -> List[Dict]:
        pass

# Specific implementations
class PerformanceExcelParser(ExcelParser):
    def parse(self, file_path: str) -> List[Dict]:
        # Specific parsing logic for performance data
        pass

class BudgetExcelParser(ExcelParser):
    def parse(self, file_path: str) -> List[Dict]:
        # Specific parsing logic for budget data
        pass
```

### 3. Liskov Substitution Principle (LSP)
- Any repository implementation can be substituted without breaking the service layer
- Mock repositories for testing

**Example**:
```python
# Service depends on repository interface
class DashboardService:
    def __init__(self, performance_repo: PerformanceRepository):
        self.performance_repo = performance_repo

    def get_total_performance(self) -> Decimal:
        performances = self.performance_repo.get_all()
        return sum(p.amount for p in performances)

# Production implementation
class DjangoPerformanceRepository(PerformanceRepository):
    def get_all(self) -> List[Performance]:
        return [self._to_domain(p) for p in PerformanceModel.objects.all()]

# Test implementation
class InMemoryPerformanceRepository(PerformanceRepository):
    def __init__(self):
        self._data = []

    def get_all(self) -> List[Performance]:
        return self._data
```

### 4. Interface Segregation Principle (ISP)
- Define small, focused interfaces instead of large, monolithic ones
- Clients only depend on methods they use

**Example**:
```python
# BAD: Fat interface
class DataRepository:
    def create(self, data): pass
    def read(self, id): pass
    def update(self, id, data): pass
    def delete(self, id): pass
    def bulk_import(self, data): pass
    def export_to_csv(self): pass

# GOOD: Segregated interfaces
class ReadableRepository(ABC):
    @abstractmethod
    def get_by_id(self, id): pass

    @abstractmethod
    def get_all(self): pass

class WritableRepository(ABC):
    @abstractmethod
    def create(self, data): pass

    @abstractmethod
    def update(self, id, data): pass

class BulkImportRepository(ABC):
    @abstractmethod
    def bulk_create(self, data_list): pass
```

### 5. Dependency Inversion Principle (DIP)
- High-level modules (services) do not depend on low-level modules (repositories)
- Both depend on abstractions (interfaces)

**Example**:
```python
# BAD: Service depends on concrete repository
class DashboardService:
    def __init__(self):
        self.performance_repo = DjangoPerformanceRepository()  # Tight coupling!

# GOOD: Service depends on abstraction
class DashboardService:
    def __init__(self, performance_repo: PerformanceRepository):
        self.performance_repo = performance_repo  # Depends on interface

# Dependency injection in Django views
class DashboardView(APIView):
    def __init__(self):
        # Dependencies are injected (can be done with DI container)
        performance_repo = DjangoPerformanceRepository()
        self.dashboard_service = DashboardService(performance_repo)
```

---

## Data Flow Examples

### 1. User Uploads Excel File

```
Frontend                           Backend
--------                          --------
1. User selects file
   ↓
2. UploadForm submits file
   via uploadApi.uploadExcel()
   ↓                              3. UploadView receives request
                                     ↓
                                  4. Validates file using serializer
                                     ↓
                                  5. Calls FileProcessorService.process_file()
                                     ↓
                                  6. ExcelParser.parse() extracts data
                                     ↓
                                  7. DataValidator.validate() checks business rules
                                     ↓
                                  8. PerformanceRepository.bulk_create() saves data
                                     ↓
                                  9. Returns success response
   ↓
10. Display success notification
```

### 2. User Views Dashboard

```
Frontend                           Backend
--------                          --------
1. User navigates to dashboard
   ↓
2. useDashboard hook calls
   dashboardApi.getDashboard()
   ↓                              3. DashboardView receives request
                                     ↓
                                  4. Authenticates user via JWT middleware
                                     ↓
                                  5. Calls DashboardService.get_dashboard_summary()
                                     ↓
                                  6. Service calls multiple repositories:
                                     - PerformanceRepository.get_summary()
                                     - PaperRepository.get_count()
                                     - StudentRepository.get_count()
                                     - BudgetRepository.get_total()
                                     ↓
                                  7. MetricCalculator.calculate_trends()
                                     ↓
                                  8. ChartDataBuilder.build_chart_data()
                                     ↓
                                  9. Serializes domain models to JSON
                                     ↓
                                  10. Returns response
   ↓
11. ChartTransformer formats data
   ↓
12. Renders charts with Recharts
```

### 3. User Authentication

```
Frontend                           Backend
--------                          --------
1. User enters credentials
   ↓
2. LoginForm calls
   authService.login()
   ↓
3. Supabase Auth authenticates
   ↓
4. Receives JWT token
   ↓
5. Stores token in localStorage
   ↓
6. Sets AuthContext state
   ↓
7. Axios interceptor adds token
   to subsequent requests
   ↓                              8. AuthMiddleware validates JWT
                                     ↓
                                  9. Extracts user ID from token
                                     ↓
                                  10. Attaches user to request
                                     ↓
                                  11. Processes API request
```

---

## Key Design Decisions

### 1. Repository Pattern
**Why**: Decouple business logic from ORM, making the codebase testable and framework-agnostic.

**Implementation**:
- Service layer depends on repository interfaces, not Django ORM
- Repositories translate between domain models and ORM models
- Easy to mock repositories for unit testing

### 2. Domain Models vs. ORM Models
**Why**: Business logic should not depend on framework-specific models.

**Implementation**:
- Domain models are pure Python dataclasses or Pydantic models
- ORM models are Django models (framework-specific)
- Repositories handle the translation between the two

### 3. Service Layer
**Why**: Centralize business logic in a testable, reusable layer.

**Implementation**:
- Services contain all business rules
- Services are framework-agnostic (can be tested without Django)
- Services orchestrate repositories and external services

### 4. External Integration Abstraction
**Why**: Minimize impact of external service changes on internal logic.

**Implementation**:
- External services are accessed through interfaces
- Easy to replace Supabase with another auth provider
- Easy to mock external services for testing

### 5. Frontend Layered Architecture
**Why**: Separate UI concerns from business logic and data fetching.

**Implementation**:
- Presentation layer only handles UI rendering
- Application layer manages state and side effects (hooks, context)
- Service layer handles API communication
- Infrastructure layer handles external integrations (Supabase, Axios)

---

## Testing Strategy

### Backend Testing Layers

```
Unit Tests
├── Service Layer Tests (pure business logic)
│   - Mock repositories
│   - Test business rules
│   └── No database or HTTP dependencies
├── Repository Tests
│   - Use in-memory database
│   └── Test ORM queries
└── Utility Tests
    └── Test helper functions

Integration Tests
├── API Endpoint Tests
│   - Use Django test client
│   - Test request/response flow
│   └── Use test database
└── Service + Repository Tests
    └── Test full data flow

End-to-End Tests
└── Full user flow tests
    - Use pytest with Playwright or Selenium
    └── Test against real or staging environment
```

### Frontend Testing Layers

```
Unit Tests
├── Component Tests (React Testing Library)
│   - Mock services and hooks
│   └── Test UI behavior
├── Hook Tests
│   └── Test custom hooks in isolation
└── Utility Tests
    └── Test helper functions

Integration Tests
├── Page Tests
│   - Mock API calls
│   └── Test user interactions
└── Service Tests
    └── Test API service logic

End-to-End Tests
└── Full user flow tests
    - Use Playwright or Cypress
    └── Test against real or staging backend
```

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└──────────────────┬──────────────────┬───────────────────────┘
                   │                  │
         ┌─────────▼────────┐  ┌──────▼──────────┐
         │  Frontend (Vercel) │  │ Backend (Railway) │
         │  React + Vite      │  │ Django + DRF      │
         └────────────────────┘  └──────┬───────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
         ┌──────────▼──────────┐ ┌─────▼──────┐  ┌────────▼─────────┐
         │ Supabase (Auth)     │ │  Supabase  │  │  Railway         │
         │ JWT Token Provider  │ │ PostgreSQL │  │  File Storage    │
         └─────────────────────┘ └────────────┘  └──────────────────┘
```

---

## Environment Configuration

### Backend Environment Variables

```bash
# Django Settings
DJANGO_SETTINGS_MODULE=config.settings.production
SECRET_KEY=your-secret-key
DEBUG=False
ALLOWED_HOSTS=your-domain.railway.app

# Database (Supabase PostgreSQL)
DB_NAME=your-db-name
DB_USER=your-db-user
DB_PASSWORD=your-db-password
DB_HOST=db.your-project.supabase.co
DB_PORT=5432

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret

# CORS
CORS_ALLOWED_ORIGINS=https://your-frontend.vercel.app

# Media Files
MEDIA_URL=/media/
MEDIA_ROOT=/app/media
```

### Frontend Environment Variables

```bash
# API
VITE_API_URL=https://your-backend.railway.app/api

# Supabase
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

---

## Migration Path

### Phase 1: Initial Setup
1. Set up project structure
2. Configure Django and React projects
3. Set up Supabase and connect to backend

### Phase 2: Core Features
1. Implement authentication (Supabase Auth)
2. Implement file upload and Excel parsing
3. Create database models and repositories

### Phase 3: Dashboard
1. Implement dashboard service and repositories
2. Create dashboard API endpoints
3. Build frontend dashboard with charts

### Phase 4: Testing & Deployment
1. Write unit and integration tests
2. Set up CI/CD pipeline
3. Deploy to Railway and Vercel

### Phase 5: Refinement
1. Performance optimization
2. Error handling and logging
3. User feedback and iteration

---

## Conclusion

This architecture ensures:

1. **Separation of Concerns**: Each layer has a clear responsibility
2. **Testability**: Business logic can be tested without framework dependencies
3. **Maintainability**: Easy to understand and modify
4. **Scalability**: Easy to add new features without breaking existing code
5. **Framework Independence**: Business logic is not tied to Django or React
6. **SOLID Principles**: All five principles are consistently applied
7. **Flexibility**: Easy to replace external services or databases

By following these architectural guidelines, the project will be well-structured, maintainable, and aligned with industry best practices.
