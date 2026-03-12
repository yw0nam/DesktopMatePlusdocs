# Knowledge Store — FastAPI Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a file-based knowledge store to the FastAPI backend with upsert/search/read API, grace period enforcement, session-triggered auto-save, and Director LangGraph tools.

**Architecture:** `KnowledgeBaseService` wraps a GDrive-mounted markdown file tree. All writes go through a single service (grace period check + `IndexUpdater` with `FileLock`). API endpoints are Bearer-authenticated for NanoClaw MCP. Director `PersonaAgent` tools call the service directly (no HTTP loopback).

**Tech Stack:** FastAPI, Pydantic v2, `python-slugify`, `filelock`, `ripgrep` (rg CLI), LangGraph `BaseTool`, pytest + `tmp_path`

**Spec:** `docs/superpowers/specs/2026-03-12-knowledge-store-design.md`

---

## File Structure

### New files

| File | Responsibility |
|---|---|
| `backend/yaml_files/services/knowledge_base_service/knowledge_base.yaml` | Service config |
| `backend/src/services/knowledge_base_service/__init__.py` | Public exports |
| `backend/src/services/knowledge_base_service/models.py` | Pydantic request/response schemas |
| `backend/src/services/knowledge_base_service/slug.py` | Slug generation + tag normalization |
| `backend/src/services/knowledge_base_service/index_updater.py` | INDEX.md + MOC update with FileLock |
| `backend/src/services/knowledge_base_service/service.py` | `KnowledgeBaseService` (upsert/search/read) |
| `backend/src/api/routes/knowledge_base.py` | API router (Bearer auth) |
| `backend/src/services/agent_service/tools/knowledge/__init__.py` | Tool exports |
| `backend/src/services/agent_service/tools/knowledge/search_knowledge.py` | `SearchKnowledgeTool` |
| `backend/src/services/agent_service/tools/knowledge/read_note.py` | `ReadNoteTool` |
| `backend/tests/services/test_knowledge_base_service.py` | Service unit tests |
| `backend/tests/api/test_knowledge_base_api.py` | API integration tests |

### Modified files

| File | Change |
|---|---|
| `backend/src/api/routes/__init__.py` | Register knowledge_base router |
| `backend/src/services/service_manager.py` | Add `initialize_knowledge_base_service`, `get_knowledge_base_service` |
| `backend/src/services/__init__.py` | Export new service functions |
| `backend/src/services/websocket_service/manager/connection.py` | Add `current_session_id` field |
| `backend/src/services/websocket_service/manager/handlers.py` | Track `current_session_id` + `last_message_at` per turn |
| `backend/src/services/websocket_service/manager/websocket_manager.py` | Call knowledge summary delegate on disconnect |
| `backend/src/services/task_sweep_service/sweep.py` | Add idle timeout check for knowledge summary |

---

## Chunk 1: Foundation — Config, Models, Slug/Tag utilities

### Task 1: Config YAML + Pydantic settings model

**Files:**
- Create: `backend/yaml_files/services/knowledge_base_service/knowledge_base.yaml`
- Create: `backend/src/services/knowledge_base_service/models.py`
- Test: `backend/tests/services/test_knowledge_base_service.py` (first test)

- [ ] **Step 1.1: Write the failing test**

```python
# backend/tests/services/test_knowledge_base_service.py
import pytest
from pathlib import Path
from src.services.knowledge_base_service.models import (
    KnowledgeBaseConfig,
    UpsertRequest,
    SearchRequest,
)

def test_config_defaults():
    config = KnowledgeBaseConfig(knowledge_base_path=Path("/tmp/kb"))
    assert config.grace_period_days == 3
    assert config.session_idle_timeout_minutes == 30
    assert config.min_turns_for_summary == 3
    assert config.filelock_timeout == 5.0

def test_upsert_request_requires_title_and_content():
    req = UpsertRequest(title="Test", content="Body", tags=["nanoclaw"])
    assert req.tags == ["nanoclaw"]

def test_search_request_fails_when_both_empty():
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        SearchRequest(query=None, tags=[])
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -v
```
Expected: `ImportError` or `ModuleNotFoundError`

- [ ] **Step 1.3: Create YAML config**

```yaml
# backend/yaml_files/services/knowledge_base_service/knowledge_base.yaml
knowledge_base_config:
  type: local
  configs:
    knowledge_base_path: /mnt/gdrive/knowledge_base
    grace_period_days: 3
    session_idle_timeout_minutes: 30
    min_turns_for_summary: 3
    filelock_timeout: 5.0
    internal_api_key: "changeme-replace-in-production"
```

- [ ] **Step 1.4: Create models.py**

```python
# backend/src/services/knowledge_base_service/models.py
from datetime import datetime
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field, model_validator
from pydantic_settings import BaseSettings


class KnowledgeBaseConfig(BaseModel):
    knowledge_base_path: Path
    grace_period_days: int = 3
    session_idle_timeout_minutes: int = 30
    min_turns_for_summary: int = 3
    filelock_timeout: float = 5.0
    internal_api_key: str = "changeme"


class UpsertRequest(BaseModel):
    title: str = Field(..., min_length=1)
    content: str
    tags: list[str] = []


class UpsertResponse(BaseModel):
    path: str
    created: bool


class SearchRequest(BaseModel):
    query: Optional[str] = None
    tags: list[str] = []

    @model_validator(mode="after")
    def require_query_or_tags(self) -> "SearchRequest":
        if not self.query and not self.tags:
            raise ValueError("At least one of 'query' or 'tags' must be provided")
        return self


class SearchSnippet(BaseModel):
    file_path: str
    lines: list[str]


class SearchResponse(BaseModel):
    results: list[SearchSnippet]


class ReadResponse(BaseModel):
    path: str
    content: str
```

- [ ] **Step 1.5: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -v
```
Expected: 3 PASS

- [ ] **Step 1.6: Create empty `__init__.py` for the package**

```python
# backend/src/services/knowledge_base_service/__init__.py
# (populated in Task 7 — create empty now so imports work during TDD)
```

- [ ] **Step 1.7: Commit**

```bash
cd backend && git add yaml_files/services/knowledge_base_service/ src/services/knowledge_base_service/__init__.py src/services/knowledge_base_service/models.py tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add config YAML and Pydantic models"
```

---

### Task 2: Slug generation + tag normalization

**Files:**
- Create: `backend/src/services/knowledge_base_service/slug.py`
- Test: append to `backend/tests/services/test_knowledge_base_service.py`

- [ ] **Step 2.1: Write failing tests**

```python
# Append to test_knowledge_base_service.py
from datetime import date
from src.services.knowledge_base_service.slug import generate_filename, normalize_tags

def test_generate_filename_basic(tmp_path):
    name = generate_filename("NanoClaw 포트 충돌", date(2026, 3, 12), tmp_path)
    assert name.startswith("20260312-")
    assert name.endswith(".md")

def test_generate_filename_collision(tmp_path):
    d = date(2026, 3, 12)
    first = generate_filename("Test Title", d, tmp_path)
    (tmp_path / first).touch()
    second = generate_filename("Test Title", d, tmp_path)
    assert second != first
    assert second.startswith("20260312-")
    assert "-2.md" in second or second.endswith("-2.md")

def test_normalize_tags_lowercase():
    assert normalize_tags(["NanoClaw", "FastAPI", "bugFix"]) == ["nanoclaw", "fastapi", "bugfix"]

def test_normalize_tags_spaces_to_hyphens():
    result = normalize_tags(["fast api", "my_tag"])
    assert "fast-api" in result
    assert "my-tag" in result

def test_normalize_tags_dedup():
    assert normalize_tags(["nanoclaw", "NanoClaw"]) == ["nanoclaw"]

def test_normalize_tags_special_chars():
    result = normalize_tags(["@foo", "bar.baz"])
    assert all(c.isalnum() or c == "-" for tag in result for c in tag)
```

- [ ] **Step 2.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py::test_generate_filename_basic -v
```
Expected: `ImportError`

- [ ] **Step 2.3: Create slug.py**

```python
# backend/src/services/knowledge_base_service/slug.py
from datetime import date
from pathlib import Path

from slugify import slugify


def generate_filename(title: str, dt: date, directory: Path) -> str:
    """Generate a unique {YYYYMMDD}-{slug}.md filename in directory."""
    date_prefix = dt.strftime("%Y%m%d")
    base_slug = slugify(title, separator="-") or "untitled"
    candidate = f"{date_prefix}-{base_slug}.md"

    if not (directory / candidate).exists():
        return candidate

    counter = 2
    while True:
        candidate = f"{date_prefix}-{base_slug}-{counter}.md"
        if not (directory / candidate).exists():
            return candidate
        counter += 1


def normalize_tags(tags: list[str]) -> list[str]:
    """Lowercase, hyphenate, strip special chars, and deduplicate tags."""
    seen: set[str] = set()
    result: list[str] = []
    for tag in tags:
        normalized = slugify(tag, separator="-") or tag.lower().replace(" ", "-")
        if normalized and normalized not in seen:
            seen.add(normalized)
            result.append(normalized)
    return result
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "slug or tag" -v
```
Expected: 5 PASS

- [ ] **Step 2.5: Commit**

```bash
cd backend && git add src/services/knowledge_base_service/slug.py tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add slug generation and tag normalization"
```

---

## Chunk 2: Core Service — IndexUpdater + KnowledgeBaseService

### Task 3: IndexUpdater (FileLock + INDEX.md + MOC)

**Files:**
- Create: `backend/src/services/knowledge_base_service/index_updater.py`
- Test: append to `backend/tests/services/test_knowledge_base_service.py`

- [ ] **Step 3.1: Write failing tests**

```python
# Append to test_knowledge_base_service.py
from datetime import datetime, timezone
from src.services.knowledge_base_service.index_updater import IndexUpdater

def test_update_all_creates_monthly_index(tmp_path):
    kb_path = tmp_path / "kb"
    kb_path.mkdir()
    updater = IndexUpdater(kb_path)
    file_path = kb_path / "2026-03" / "20260312-test.md"
    updater.update_all(
        file_path=file_path,
        title="Test Note",
        tags=["nanoclaw"],
        created_at=datetime(2026, 3, 12, tzinfo=timezone.utc),
    )
    monthly_index = kb_path / "2026-03" / "INDEX.md"
    assert monthly_index.exists()
    content = monthly_index.read_text()
    assert "20260312-test" in content
    assert "#nanoclaw" in content

def test_update_all_creates_root_index(tmp_path):
    kb_path = tmp_path / "kb"
    kb_path.mkdir()
    updater = IndexUpdater(kb_path)
    file_path = kb_path / "2026-03" / "20260312-test.md"
    updater.update_all(
        file_path=file_path,
        title="Test Note",
        tags=["nanoclaw"],
        created_at=datetime(2026, 3, 12, tzinfo=timezone.utc),
    )
    root_index = kb_path / "INDEX.md"
    assert root_index.exists()
    assert "2026-03" in root_index.read_text()

def test_update_all_creates_moc_per_tag(tmp_path):
    kb_path = tmp_path / "kb"
    kb_path.mkdir()
    updater = IndexUpdater(kb_path)
    file_path = kb_path / "2026-03" / "20260312-test.md"
    updater.update_all(
        file_path=file_path,
        title="Test Note",
        tags=["nanoclaw", "bugfix"],
        created_at=datetime(2026, 3, 12, tzinfo=timezone.utc),
    )
    assert (kb_path / "moc" / "nanoclaw-MOC.md").exists()
    assert (kb_path / "moc" / "bugfix-MOC.md").exists()

def test_update_all_idempotent(tmp_path):
    kb_path = tmp_path / "kb"
    kb_path.mkdir()
    updater = IndexUpdater(kb_path)
    file_path = kb_path / "2026-03" / "20260312-test.md"
    dt = datetime(2026, 3, 12, tzinfo=timezone.utc)
    updater.update_all(file_path=file_path, title="Test", tags=["a"], created_at=dt)
    updater.update_all(file_path=file_path, title="Test", tags=["a"], created_at=dt)
    content = (kb_path / "2026-03" / "INDEX.md").read_text()
    assert content.count("20260312-test") == 1
```

- [ ] **Step 3.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "index" -v
```
Expected: `ImportError`

- [ ] **Step 3.3: Create index_updater.py**

```python
# backend/src/services/knowledge_base_service/index_updater.py
from datetime import datetime
from pathlib import Path
from typing import Optional

from filelock import FileLock, Timeout
from loguru import logger


class IndexUpdater:
    """Updates INDEX.md and MOC files after a successful upsert."""

    def __init__(self, knowledge_base_path: Path, lock_timeout: float = 5.0) -> None:
        self._kb = knowledge_base_path
        self._lock_timeout = lock_timeout
        self._lock_path = self._kb / ".index.lock"

    def update_all(
        self,
        file_path: Path,
        title: str,
        tags: list[str],
        created_at: datetime,
    ) -> None:
        """Update monthly INDEX, root INDEX, and MOC files. Sequential with lock."""
        month_str = created_at.strftime("%Y-%m")
        rel_path = file_path.relative_to(self._kb)
        slug = file_path.stem
        tag_str = " ".join(f"#{t}" for t in tags)
        entry_line = f"- [{slug}](./{slug}.md) — {title} {tag_str}".strip()
        root_entry = f"- [{month_str}](./{month_str}/INDEX.md)"

        try:
            with FileLock(str(self._lock_path), timeout=self._lock_timeout):
                self._update_monthly_index(month_str, slug, entry_line)
                self._update_root_index(month_str, root_entry)
                for tag in tags:
                    self._update_moc(tag, slug, title, rel_path)
        except Timeout:
            logger.error(
                f"IndexUpdater: FileLock timeout after {self._lock_timeout}s for {file_path}"
            )
            raise

    def _update_monthly_index(self, month_str: str, slug: str, entry_line: str) -> None:
        index_path = self._kb / month_str / "INDEX.md"
        index_path.parent.mkdir(parents=True, exist_ok=True)
        existing = index_path.read_text(encoding="utf-8") if index_path.exists() else f"# {month_str}\n\n"
        if slug in existing:
            return  # idempotent
        lines = existing.rstrip().split("\n")
        # Find first list item position to insert at top
        insert_pos = next((i for i, l in enumerate(lines) if l.startswith("- [")), len(lines))
        lines.insert(insert_pos, entry_line)
        index_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _update_root_index(self, month_str: str, root_entry: str) -> None:
        root_path = self._kb / "INDEX.md"
        existing = root_path.read_text(encoding="utf-8") if root_path.exists() else "# Knowledge Base\n\n"
        if month_str in existing:
            return  # month already listed
        lines = existing.rstrip().split("\n")
        insert_pos = next((i for i, l in enumerate(lines) if l.startswith("- [")), len(lines))
        lines.insert(insert_pos, root_entry)
        root_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _update_moc(self, tag: str, slug: str, title: str, rel_path: Path) -> None:
        moc_dir = self._kb / "moc"
        moc_dir.mkdir(exist_ok=True)
        moc_path = moc_dir / f"{tag}-MOC.md"
        existing = moc_path.read_text(encoding="utf-8") if moc_path.exists() else f"# {tag} MOC\n\n"
        if slug in existing:
            return  # idempotent
        entry = f"- [{slug}](../{rel_path}) — {title}"
        lines = existing.rstrip().split("\n")
        insert_pos = next((i for i, l in enumerate(lines) if l.startswith("- [")), len(lines))
        lines.insert(insert_pos, entry)
        moc_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
```

- [ ] **Step 3.4: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "index or moc" -v
```
Expected: 4 PASS

- [ ] **Step 3.5: Commit**

```bash
cd backend && git add src/services/knowledge_base_service/index_updater.py tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add IndexUpdater with FileLock"
```

---

### Task 4: KnowledgeBaseService.upsert

**Files:**
- Create: `backend/src/services/knowledge_base_service/service.py`
- Test: append to `backend/tests/services/test_knowledge_base_service.py`

- [ ] **Step 4.1: Write failing tests**

```python
# Append to test_knowledge_base_service.py
import pytest
from fastapi import HTTPException
from src.services.knowledge_base_service.models import KnowledgeBaseConfig, UpsertRequest
from src.services.knowledge_base_service.service import KnowledgeBaseService

def make_service(tmp_path):
    config = KnowledgeBaseConfig(knowledge_base_path=tmp_path / "kb")
    (tmp_path / "kb").mkdir()
    return KnowledgeBaseService(config)

def test_upsert_creates_new_file(tmp_path):
    svc = make_service(tmp_path)
    req = UpsertRequest(title="Test Note", content="# Body\nHello", tags=["nanoclaw"])
    result = svc.upsert(req)
    assert result.created is True
    assert result.path.endswith(".md")
    file = (tmp_path / "kb") / result.path.lstrip("/")
    assert file.exists()
    text = file.read_text()
    assert "created_at:" in text
    assert "nanoclaw" in text

def test_upsert_within_grace_period_succeeds(tmp_path):
    # File just created → within grace period by definition
    svc = make_service(tmp_path)
    req = UpsertRequest(title="Test Note", content="V1", tags=["x"])
    result = svc.upsert(req)
    result2 = svc.upsert_by_path(result.path, UpsertRequest(title="Test Note", content="V2 updated", tags=["x"]))
    assert result2.created is False
    file = (tmp_path / "kb") / result.path.lstrip("/")
    assert "V2 updated" in file.read_text()

def test_upsert_after_grace_period_raises_409(tmp_path):
    import re
    from datetime import datetime, timezone, timedelta
    from fastapi import HTTPException
    svc = make_service(tmp_path)
    req = UpsertRequest(title="Old Note", content="V1", tags=["x"])
    result = svc.upsert(req)
    # Overwrite created_at to 10 days ago using regex substitution
    file_path = (tmp_path / "kb") / result.path.lstrip("/")
    old_date = (datetime.now(timezone.utc) - timedelta(days=10)).isoformat()
    text = file_path.read_text()
    text = re.sub(r"(created_at:\s*).*", f"\\g<1>{old_date}", text)
    file_path.write_text(text)
    with pytest.raises(HTTPException) as exc:
        svc.upsert_by_path(result.path, UpsertRequest(title="Old Note", content="V2", tags=["x"]))
    assert exc.value.status_code == 409

def test_upsert_raises_503_when_mount_missing(tmp_path):
    config = KnowledgeBaseConfig(knowledge_base_path=tmp_path / "nonexistent")
    svc = KnowledgeBaseService(config)
    with pytest.raises(HTTPException) as exc:
        svc.upsert(UpsertRequest(title="Test", content="body", tags=[]))
    assert exc.value.status_code == 503
```

- [ ] **Step 4.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "upsert" -v
```
Expected: `ImportError`

- [ ] **Step 4.3: Create service.py (upsert part)**

```python
# backend/src/services/knowledge_base_service/service.py
from datetime import date, datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

import yaml
from fastapi import HTTPException, status
from loguru import logger

from .index_updater import IndexUpdater
from .models import (
    KnowledgeBaseConfig,
    ReadResponse,
    SearchRequest,
    SearchResponse,
    SearchSnippet,
    UpsertRequest,
    UpsertResponse,
)
from .slug import generate_filename, normalize_tags

_FRONTMATTER_TEMPLATE = """\
---
title: {title}
created_at: {created_at}
tags: [{tags}]
---
"""


class KnowledgeBaseService:
    def __init__(self, config: KnowledgeBaseConfig) -> None:
        self._config = config
        self._kb = config.knowledge_base_path
        self._updater = IndexUpdater(self._kb, lock_timeout=config.filelock_timeout)

    def _check_mount(self) -> None:
        if not self._kb.exists():
            logger.error(f"KnowledgeBaseService: mount missing at {self._kb}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Knowledge base storage unavailable",
            )

    def upsert(self, request: UpsertRequest) -> UpsertResponse:
        """Create a new knowledge note."""
        self._check_mount()
        tags = normalize_tags(request.tags)
        today = date.today()
        month_dir = self._kb / today.strftime("%Y-%m")
        month_dir.mkdir(parents=True, exist_ok=True)
        filename = generate_filename(request.title, today, month_dir)
        file_path = month_dir / filename
        created_at = datetime.now(timezone.utc)
        frontmatter = _FRONTMATTER_TEMPLATE.format(
            title=request.title,
            created_at=created_at.isoformat(),
            tags=", ".join(tags),
        )
        file_path.write_text(frontmatter + "\n" + request.content, encoding="utf-8")
        logger.info(f"KnowledgeBaseService: created {file_path} tags={tags}")
        self._updater.update_all(
            file_path=file_path, title=request.title, tags=tags, created_at=created_at
        )
        rel = str(file_path.relative_to(self._kb))
        return UpsertResponse(path=rel, created=True)

    def upsert_by_path(self, rel_path: str, request: UpsertRequest) -> UpsertResponse:
        """Update an existing note (grace period enforced)."""
        self._check_mount()
        file_path = self._kb / rel_path.lstrip("/")
        if not file_path.exists():
            # Treat as new upsert if file doesn't exist
            return self.upsert(request)

        # Read existing created_at
        text = file_path.read_text(encoding="utf-8")
        created_at = self._parse_created_at(text)
        if created_at is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot parse created_at from existing file",
            )

        age_days = (datetime.now(timezone.utc) - created_at).days
        if age_days > self._config.grace_period_days:
            logger.warning(
                f"KnowledgeBaseService: grace period exceeded for {rel_path} "
                f"(age={age_days}d, limit={self._config.grace_period_days}d)"
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "message": "Grace period exceeded. Create a new file and link to this one.",
                    "existing_path": rel_path,
                    "age_days": age_days,
                },
            )

        tags = normalize_tags(request.tags)
        frontmatter = _FRONTMATTER_TEMPLATE.format(
            title=request.title,
            created_at=created_at.isoformat(),
            tags=", ".join(tags),
        )
        file_path.write_text(frontmatter + "\n" + request.content, encoding="utf-8")
        logger.info(f"KnowledgeBaseService: updated {file_path} tags={tags}")
        return UpsertResponse(path=rel_path, created=False)

    @staticmethod
    def _parse_created_at(frontmatter_text: str) -> Optional[datetime]:
        try:
            fm_part = frontmatter_text.split("---")[1]
            data = yaml.safe_load(fm_part)
            raw = data.get("created_at")
            if raw is None:
                return None
            if isinstance(raw, str):
                dt = datetime.fromisoformat(raw)
            else:
                dt = raw  # already datetime
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except Exception:
            return None
```

- [ ] **Step 4.4: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "upsert" -v
```
Expected: 4 PASS

> Note: `test_upsert_within_grace_period_succeeds` uses `upsert_by_path` directly.

- [ ] **Step 4.5: Commit**

```bash
cd backend && git add src/services/knowledge_base_service/service.py tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add KnowledgeBaseService upsert"
```

---

### Task 5: KnowledgeBaseService.search + read

**Files:**
- Modify: `backend/src/services/knowledge_base_service/service.py`
- Test: append to `backend/tests/services/test_knowledge_base_service.py`

- [ ] **Step 5.1: Write failing tests**

```python
# Append to test_knowledge_base_service.py
import subprocess
from unittest.mock import patch, MagicMock
from src.services.knowledge_base_service.models import SearchRequest

def test_search_with_query_calls_ripgrep(tmp_path):
    svc = make_service(tmp_path)
    mock_output = (
        '{"type":"match","data":{"path":{"text":"2026-03/note.md"},'
        '"lines":{"text":"nanoclaw port issue"},"line_number":5}}\n'
        '{"type":"context","data":{"path":{"text":"2026-03/note.md"},'
        '"lines":{"text":"context line"},"line_number":6}}\n'
    )
    with patch("subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0, stdout=mock_output, stderr="")
        result = svc.search(SearchRequest(query="nanoclaw"))
    assert len(result.results) >= 1
    assert "2026-03/note.md" in result.results[0].file_path

def test_search_tags_only_uses_frontmatter_pattern(tmp_path):
    svc = make_service(tmp_path)
    with patch("subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="")
        result = svc.search(SearchRequest(tags=["nanoclaw"]))
    cmd = mock_run.call_args[0][0]
    assert any("tags:" in arg for arg in cmd)

def test_search_both_empty_raises_validation_error(tmp_path):
    # ValidationError is raised at model construction time, not service level
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        SearchRequest(query=None, tags=[])

def test_read_returns_file_content(tmp_path):
    svc = make_service(tmp_path)
    kb = tmp_path / "kb"
    (kb / "2026-03").mkdir(parents=True)
    note = kb / "2026-03" / "test.md"
    note.write_text("# Hello World", encoding="utf-8")
    result = svc.read("2026-03/test.md")
    assert result.content == "# Hello World"

def test_read_raises_404_when_missing(tmp_path):
    svc = make_service(tmp_path)
    with pytest.raises(HTTPException) as exc:
        svc.read("nonexistent/file.md")
    assert exc.value.status_code == 404
```

- [ ] **Step 5.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "search or read" -v
```
Expected: `AttributeError` (methods don't exist yet)

- [ ] **Step 5.3: Add search and read to service.py**

> Add `import json`, `import re`, `import subprocess` at the top of `service.py` (with other imports). Then add the following two methods inside the `KnowledgeBaseService` class body.

```python
    def search(self, request: SearchRequest) -> SearchResponse:
        self._check_mount()
        if not request.query and not request.tags:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least one of 'query' or 'tags' must be provided",
            )

        if request.query:
            cmd = [
                "rg", "--json", "-C", "2",
                request.query,
                str(self._kb),
            ]
        else:
            # tags-only: search frontmatter
            tag_pattern = "|".join(request.tags)
            cmd = [
                "rg", "--json",
                f"tags:.*({tag_pattern})",
                str(self._kb),
            ]

        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        except FileNotFoundError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="ripgrep (rg) not found on system",
            )

        snippets: dict[str, list[str]] = {}
        for line in proc.stdout.splitlines():
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") not in ("match", "context"):
                continue
            data = obj.get("data", {})
            path = data.get("path", {}).get("text", "")
            text_line = data.get("lines", {}).get("text", "").rstrip()
            if not path:
                continue
            # Make path relative to kb root
            try:
                rel = str(Path(path).relative_to(self._kb))
            except ValueError:
                rel = path
            # Apply tags filter for query mode
            if request.tags and request.query:
                pass  # post-filter handled below
            snippets.setdefault(rel, []).append(text_line)

        # Post-filter by tags if both provided
        if request.query and request.tags:
            filtered: dict[str, list[str]] = {}
            for rel_path, lines in snippets.items():
                full_path = self._kb / rel_path
                if full_path.exists():
                    content = full_path.read_text(encoding="utf-8")
                    if any(re.search(f"tags:.*{re.escape(t)}", content) for t in request.tags):
                        filtered[rel_path] = lines
            snippets = filtered

        results = [SearchSnippet(file_path=k, lines=v) for k, v in snippets.items()]
        return SearchResponse(results=results)

    def read(self, rel_path: str) -> ReadResponse:
        self._check_mount()
        file_path = self._kb / rel_path.lstrip("/")
        if not file_path.exists():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Note not found: {rel_path}",
            )
        content = file_path.read_text(encoding="utf-8")
        logger.info(f"KnowledgeBaseService: read {rel_path}")
        return ReadResponse(path=rel_path, content=content)
```

- [ ] **Step 5.4: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -v
```
Expected: all PASS

- [ ] **Step 5.5: Commit**

```bash
cd backend && git add src/services/knowledge_base_service/service.py tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add search and read to KnowledgeBaseService"
```

---

## Chunk 3: API Router + Service Registration + Director Tools

### Task 6: API router (Bearer auth)

**Files:**
- Create: `backend/src/api/routes/knowledge_base.py`
- Create: `backend/tests/api/test_knowledge_base_api.py`

- [ ] **Step 6.1: Write failing tests**

```python
# backend/tests/api/test_knowledge_base_api.py
import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch

@pytest.fixture
def client(tmp_path):
    from fastapi import FastAPI
    from src.api.routes.knowledge_base import router
    from src.services.knowledge_base_service.models import KnowledgeBaseConfig
    from src.services.knowledge_base_service.service import KnowledgeBaseService
    app = FastAPI()
    app.include_router(router)
    kb_path = tmp_path / "kb"
    kb_path.mkdir()
    config = KnowledgeBaseConfig(
        knowledge_base_path=kb_path,
        internal_api_key="test-key",
    )
    svc = KnowledgeBaseService(config)
    # Inject into app state
    app.state.kb_service = svc
    app.state.kb_internal_key = "test-key"
    return TestClient(app)

def test_upsert_requires_bearer_auth(client):
    res = client.post("/api/knowledge_base/upsert", json={
        "title": "Test", "content": "Body", "tags": []
    })
    assert res.status_code == 401

def test_upsert_with_valid_auth_succeeds(client):
    res = client.post(
        "/api/knowledge_base/upsert",
        json={"title": "Test Note", "content": "Body text", "tags": ["nanoclaw"]},
        headers={"Authorization": "Bearer test-key"},
    )
    assert res.status_code == 200
    assert "path" in res.json()

def test_search_requires_bearer_auth(client):
    res = client.get("/api/knowledge_base/search?query=test")
    assert res.status_code == 401
```

- [ ] **Step 6.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/api/test_knowledge_base_api.py -v
```
Expected: `ImportError`

- [ ] **Step 6.3: Create knowledge_base.py router**

```python
# backend/src/api/routes/knowledge_base.py
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from src.services.knowledge_base_service.models import (
    SearchRequest,
    SearchResponse,
    ReadResponse,
    UpsertRequest,
    UpsertResponse,
)

router = APIRouter(prefix="/api/knowledge_base", tags=["Knowledge Base"])
_bearer = HTTPBearer()


def _get_service(request: Request):
    svc = getattr(request.app.state, "kb_service", None)
    if svc is None:
        raise HTTPException(status_code=503, detail="Knowledge base service not initialized")
    return svc


def _verify_key(request: Request, creds: HTTPAuthorizationCredentials = Depends(_bearer)):
    expected = getattr(request.app.state, "kb_internal_key", None)
    if expected and creds.credentials != expected:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return creds.credentials


@router.post(
    "/upsert",
    response_model=UpsertResponse,
    status_code=status.HTTP_200_OK,
    responses={
        401: {"description": "Unauthorized"},
        409: {"description": "Grace period exceeded"},
        503: {"description": "Storage unavailable"},
    },
)
async def upsert_note(
    payload: UpsertRequest,
    _key: str = Depends(_verify_key),
    svc=Depends(_get_service),
) -> UpsertResponse:
    return svc.upsert(payload)


@router.get(
    "/search",
    response_model=SearchResponse,
    responses={
        400: {"description": "query or tags required"},
        401: {"description": "Unauthorized"},
    },
)
async def search_knowledge(
    query: str | None = None,
    tags: list[str] | None = None,
    _key: str = Depends(_verify_key),
    svc=Depends(_get_service),
) -> SearchResponse:
    req = SearchRequest(query=query, tags=tags or [])
    return svc.search(req)


@router.get(
    "/read",
    response_model=ReadResponse,
    responses={
        401: {"description": "Unauthorized"},
        404: {"description": "Note not found"},
    },
)
async def read_note(
    path: str,
    _key: str = Depends(_verify_key),
    svc=Depends(_get_service),
) -> ReadResponse:
    return svc.read(path)
```

- [ ] **Step 6.4: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/api/test_knowledge_base_api.py -v
```
Expected: 3 PASS

- [ ] **Step 6.5: Commit**

```bash
cd backend && git add src/api/routes/knowledge_base.py tests/api/test_knowledge_base_api.py
git commit -m "feat(knowledge-store): add Bearer-authenticated API router"
```

---

### Task 7: Service registration + router wiring

**Files:**
- Create: `backend/src/services/knowledge_base_service/__init__.py`
- Modify: `backend/src/services/service_manager.py`
- Modify: `backend/src/services/__init__.py`
- Modify: `backend/src/api/routes/__init__.py`

- [ ] **Step 7.1: Create `__init__.py`**

```python
# backend/src/services/knowledge_base_service/__init__.py
from .models import KnowledgeBaseConfig, UpsertRequest, UpsertResponse, SearchRequest, SearchResponse, ReadResponse
from .service import KnowledgeBaseService

__all__ = [
    "KnowledgeBaseConfig",
    "KnowledgeBaseService",
    "UpsertRequest",
    "UpsertResponse",
    "SearchRequest",
    "SearchResponse",
    "ReadResponse",
]
```

- [ ] **Step 7.2: Add to service_manager.py**

```python
# Append to service_manager.py (after existing imports):
from src.services.knowledge_base_service import KnowledgeBaseConfig, KnowledgeBaseService

_knowledge_base_service_instance: Optional[KnowledgeBaseService] = None


def initialize_knowledge_base_service(
    config_path: Optional[str | Path] = None, force_reinit: bool = False
) -> KnowledgeBaseService:
    global _knowledge_base_service_instance
    if _knowledge_base_service_instance is not None and not force_reinit:
        return _knowledge_base_service_instance
    if config_path is None:
        config_path = (
            Path(__file__).parent.parent.parent
            / "yaml_files" / "services" / "knowledge_base_service" / "knowledge_base.yaml"
        )
    raw = _load_yaml_config(config_path)
    configs = raw.get("knowledge_base_config", {}).get("configs", {})
    config = KnowledgeBaseConfig(**configs)
    svc = KnowledgeBaseService(config)
    _knowledge_base_service_instance = svc
    is_available = config.knowledge_base_path.exists()
    if is_available:
        logger.info(f"✅ KnowledgeBaseService ready at {config.knowledge_base_path}")
    else:
        logger.warning(f"⚠️  KnowledgeBaseService: mount missing at {config.knowledge_base_path}")
    return svc


def get_knowledge_base_service() -> Optional[KnowledgeBaseService]:
    return _knowledge_base_service_instance
```

- [ ] **Step 7.3: Register in `services/__init__.py`**

Add to imports and `__all__`:
```python
from src.services.service_manager import (
    # ... existing ...
    initialize_knowledge_base_service,
    get_knowledge_base_service,
)
# Add to __all__: "initialize_knowledge_base_service", "get_knowledge_base_service"
```

- [ ] **Step 7.4: Register router in `routes/__init__.py`**

```python
# In src/api/routes/__init__.py, add:
from src.api.routes import callback, knowledge_base, ltm, stm, tts, websocket

# In the router includes section, add:
router.include_router(knowledge_base.router)
```

- [ ] **Step 7.5: Wire service into app state (main.py lifespan)**

In `backend/src/main.py`, in the lifespan startup section, add:
```python
from src.services import initialize_knowledge_base_service, get_knowledge_base_service
# After other service initializations:
kb_svc = initialize_knowledge_base_service()
app.state.kb_service = kb_svc
app.state.kb_internal_key = kb_svc._config.internal_api_key
```

- [ ] **Step 7.6: Run full test suite to verify nothing broken**

```bash
cd backend && uv run pytest -x -v
```
Expected: all existing tests PASS

- [ ] **Step 7.7: Commit**

```bash
cd backend && git add src/services/knowledge_base_service/__init__.py src/services/service_manager.py src/services/__init__.py src/api/routes/__init__.py src/main.py
git commit -m "feat(knowledge-store): register service and router in app"
```

---

### Task 8: Director LangGraph tools (SearchKnowledgeTool, ReadNoteTool)

**Files:**
- Create: `backend/src/services/agent_service/tools/knowledge/__init__.py`
- Create: `backend/src/services/agent_service/tools/knowledge/search_knowledge.py`
- Create: `backend/src/services/agent_service/tools/knowledge/read_note.py`

- [ ] **Step 8.1: Write failing tests**

```python
# Append to test_knowledge_base_service.py
from src.services.agent_service.tools.knowledge.search_knowledge import SearchKnowledgeTool
from src.services.agent_service.tools.knowledge.read_note import ReadNoteTool

def test_search_knowledge_tool_calls_service(tmp_path):
    svc = make_service(tmp_path)
    kb = tmp_path / "kb"
    (kb / "2026-03").mkdir()
    (kb / "2026-03" / "20260312-test.md").write_text(
        "---\ntitle: Test\ncreated_at: 2026-03-12T00:00:00+00:00\ntags: [nanoclaw]\n---\nnanoclaw content",
        encoding="utf-8"
    )
    tool = SearchKnowledgeTool(kb_service=svc)
    with patch("subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='{"type":"match","data":{"path":{"text":"' + str(kb / "2026-03/20260312-test.md") + '"},"lines":{"text":"nanoclaw content"},"line_number":6}}\n',
            stderr="",
        )
        result = tool._run(query="nanoclaw")
    assert "2026-03" in result

def test_read_note_tool_returns_content(tmp_path):
    svc = make_service(tmp_path)
    kb = tmp_path / "kb"
    (kb / "2026-03").mkdir()
    (kb / "2026-03" / "note.md").write_text("# Hello", encoding="utf-8")
    tool = ReadNoteTool(kb_service=svc)
    result = tool._run(path="2026-03/note.md")
    assert "Hello" in result
```

- [ ] **Step 8.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "tool" -v
```
Expected: `ImportError`

- [ ] **Step 8.3: Create tool files**

```python
# backend/src/services/agent_service/tools/knowledge/search_knowledge.py
import json
from langchain_core.tools import BaseTool
from src.services.knowledge_base_service.models import SearchRequest
from src.services.knowledge_base_service.service import KnowledgeBaseService

class SearchKnowledgeTool(BaseTool):
    name: str = "search_knowledge"
    description: str = "Search the personal knowledge base by keyword and/or tags."
    kb_service: KnowledgeBaseService

    class Config:
        arbitrary_types_allowed = True

    def _run(self, query: str | None = None, tags: list[str] | None = None) -> str:
        req = SearchRequest(query=query, tags=tags or [])
        resp = self.kb_service.search(req)
        if not resp.results:
            return "No results found."
        lines = []
        for snippet in resp.results:
            lines.append(f"File: {snippet.file_path}")
            lines.extend(f"  {l}" for l in snippet.lines)
        return "\n".join(lines)
```

```python
# backend/src/services/agent_service/tools/knowledge/read_note.py
from langchain_core.tools import BaseTool
from src.services.knowledge_base_service.service import KnowledgeBaseService

class ReadNoteTool(BaseTool):
    name: str = "read_note"
    description: str = "Read the full content of a knowledge base note by path."
    kb_service: KnowledgeBaseService

    class Config:
        arbitrary_types_allowed = True

    def _run(self, path: str) -> str:
        resp = self.kb_service.read(path)
        return resp.content
```

```python
# backend/src/services/agent_service/tools/knowledge/__init__.py
from .read_note import ReadNoteTool
from .search_knowledge import SearchKnowledgeTool
__all__ = ["SearchKnowledgeTool", "ReadNoteTool"]
```

- [ ] **Step 8.4: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "tool" -v
```
Expected: 2 PASS

- [ ] **Step 8.5: Commit**

```bash
cd backend && git add src/services/agent_service/tools/knowledge/ tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add SearchKnowledgeTool and ReadNoteTool for Director"
```

---

## Chunk 4: Session Trigger (Disconnect + Idle Timeout)

### Task 9: Track session_id in ConnectionState + handlers

**Files:**
- Modify: `backend/src/services/websocket_service/manager/connection.py`
- Modify: `backend/src/services/websocket_service/manager/handlers.py`
- Modify: `backend/src/services/websocket_service/manager/websocket_manager.py`

- [ ] **Step 9.1: Add `current_session_id` to ConnectionState**

In `connection.py`, add one field:
```python
self.current_session_id: Optional[str] = None
```

- [ ] **Step 9.2: Track session_id and last_message_at in handlers.py**

In `handle_chat_message`, after `session_id = str(session_id)`:
```python
# Track current session for disconnect trigger
connection_state.current_session_id = session_id
# Update last_message_at in STM metadata
if stm_service:
    stm_service.update_session_metadata(
        session_id,
        {"last_message_at": datetime.now(timezone.utc).isoformat()}
    )
```

Add at top of handlers.py: `from datetime import datetime, timezone`

- [ ] **Step 9.3: Add knowledge summary delegate helper to handlers.py**

```python
# Append to handlers.py
async def _delegate_knowledge_summary(session_id: str, user_id: str) -> None:
    """Fire-and-forget: delegate knowledge summary task to NanoClaw."""
    from src.services import get_stm_service
    stm_service = get_stm_service()
    if stm_service is None:
        logger.warning("_delegate_knowledge_summary: STM service not available")
        return
    # Use DelegateTaskTool pattern but with knowledge_summary task type
    # STM context payload: Option A (inline) — include last N messages as text
    try:
        history = stm_service.get_chat_history(
            user_id=user_id, agent_id="persona", session_id=session_id, limit=50
        )
        context_text = "\n".join(
            f"[{msg.__class__.__name__}] {msg.content}"
            for msg in history
            if hasattr(msg, "content") and isinstance(msg.content, str)
        )
    except Exception:
        context_text = ""

    from src.services.agent_service.tools.delegate.delegate_task import DelegateTaskTool
    stm_svc = get_stm_service()
    if stm_svc:
        tool = DelegateTaskTool(stm_service=stm_svc, session_id=session_id)
        import asyncio
        asyncio.create_task(
            asyncio.to_thread(
                tool._run,
                task=f"knowledge_summary: Summarize and save key knowledge from this session.\n\nContext:\n{context_text}",
            ),
            name=f"knowledge-summary-{session_id}",
        )
        logger.info(f"Knowledge summary delegated for session {session_id}")
```

- [ ] **Step 9.4: Add disconnect hook in websocket_manager.py**

In `_close_connection`, BEFORE `del self.connections[connection_id]`:
```python
# Knowledge summary trigger on disconnect
connection_state = self.connections.get(connection_id)
if connection_state and connection_state.current_session_id and connection_state.user_id:
    session_id = connection_state.current_session_id
    user_id = connection_state.user_id
    stm_service = get_stm_service()
    if stm_service is not None:
        metadata = stm_service.get_session_metadata(session_id)
        history = stm_service.get_chat_history(
            user_id=user_id, agent_id="persona",
            session_id=session_id, limit=None
        )
        # Count HumanMessages only
        from langchain_core.messages import HumanMessage as HM
        human_count = sum(1 for m in history if isinstance(m, HM))
        min_turns = 3  # TODO: load from kb config
        if (not metadata.get("knowledge_saved")
                and human_count >= min_turns):
            stm_service.update_session_metadata(
                session_id, {"knowledge_saved": True}
            )
            asyncio.create_task(
                _delegate_knowledge_summary(session_id, user_id),
                name=f"knowledge-summary-disconnect-{session_id}",
            )
```

Add imports at top of websocket_manager.py: `from src.services import get_stm_service` and `from .handlers import _delegate_knowledge_summary`

- [ ] **Step 9.5: Run existing websocket tests to verify nothing broken**

```bash
cd backend && uv run pytest tests/ -x -v -k "websocket"
```
Expected: all PASS

- [ ] **Step 9.6: Commit**

```bash
cd backend && git add src/services/websocket_service/manager/
git commit -m "feat(knowledge-store): add session disconnect trigger for knowledge summary"
```

---

### Task 10: Idle timeout in BackgroundSweepService

**Files:**
- Modify: `backend/src/services/task_sweep_service/sweep.py`

- [ ] **Step 10.1: Write failing tests**

```python
# Append to test_knowledge_base_service.py
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock
from src.services.task_sweep_service.sweep import BackgroundSweepService, SweepConfig
import asyncio
import pytest

@pytest.mark.asyncio
async def test_idle_timeout_triggers_knowledge_summary():
    stm = MagicMock()
    stm.list_all_sessions.return_value = [{"session_id": "s1", "user_id": "u1", "agent_id": "a1"}]
    old_time = (datetime.now(timezone.utc) - timedelta(minutes=35)).isoformat()
    stm.get_session_metadata.return_value = {
        "last_message_at": old_time,
        "knowledge_saved": False,
        "user_id": "u1",
        "agent_id": "a1",
    }
    stm.get_chat_history.return_value = [MagicMock()] * 5
    stm.update_session_metadata.return_value = True

    config = SweepConfig(sweep_interval_seconds=60, task_ttl_seconds=300, session_idle_timeout_minutes=30)
    svc = BackgroundSweepService(stm_service=stm, config=config)
    with patch("src.services.task_sweep_service.sweep._delegate_knowledge_summary") as mock_delegate:
        mock_delegate.return_value = None
        await svc._sweep_once()
    stm.update_session_metadata.assert_called()

@pytest.mark.asyncio
async def test_idle_timeout_skips_when_knowledge_saved():
    stm = MagicMock()
    stm.list_all_sessions.return_value = [{"session_id": "s1", "user_id": "u1"}]
    old_time = (datetime.now(timezone.utc) - timedelta(minutes=35)).isoformat()
    stm.get_session_metadata.return_value = {
        "last_message_at": old_time,
        "knowledge_saved": True,
    }
    config = SweepConfig(sweep_interval_seconds=60, task_ttl_seconds=300, session_idle_timeout_minutes=30)
    svc = BackgroundSweepService(stm_service=stm, config=config)
    with patch("src.services.task_sweep_service.sweep._delegate_knowledge_summary") as mock_delegate:
        await svc._sweep_once()
    mock_delegate.assert_not_called()
```

- [ ] **Step 10.2: Run to verify failure**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "idle_timeout" -v
```
Expected: test collection error or AttributeError

- [ ] **Step 10.3: Add idle timeout check to sweep.py**

In `SweepConfig`, add:
```python
session_idle_timeout_minutes: int = Field(default=30, ge=1)
```

In `_sweep_once`, after the existing pending_tasks logic, add a second pass:
```python
# --- Idle timeout knowledge summary check ---
last_msg_raw: str = metadata.get("last_message_at", "")
knowledge_saved: bool = metadata.get("knowledge_saved", False)
user_id: str = metadata.get("user_id", "")

if last_msg_raw and not knowledge_saved and user_id:
    try:
        last_msg_at = datetime.fromisoformat(last_msg_raw)
        if last_msg_at.tzinfo is None:
            last_msg_at = last_msg_at.replace(tzinfo=timezone.utc)
        idle_minutes = (now - last_msg_at).total_seconds() / 60
        if idle_minutes > self.config.session_idle_timeout_minutes:
            # Check if enough human turns exist
            try:
                history = self._stm.get_chat_history(
                    user_id=user_id,
                    agent_id=metadata.get("agent_id", "persona"),
                    session_id=session_id,
                    limit=None,
                )
                from langchain_core.messages import HumanMessage as HM
                human_count = sum(1 for m in history if isinstance(m, HM))
            except Exception:
                human_count = 0

            if human_count >= 3:  # min_turns_for_summary default
                logger.info(
                    f"BackgroundSweepService: idle timeout for session {session_id} "
                    f"({idle_minutes:.1f}min), triggering knowledge summary"
                )
                self._stm.update_session_metadata(
                    session_id, {"knowledge_saved": True}
                )
                import asyncio
                asyncio.create_task(
                    _delegate_knowledge_summary(session_id, user_id),
                    name=f"knowledge-summary-idle-{session_id}",
                )
    except Exception:
        logger.exception(
            f"BackgroundSweepService: error in idle timeout check for session {session_id}"
        )
```

Add `_delegate_knowledge_summary` import at top of sweep.py:
```python
from src.services.websocket_service.manager.handlers import _delegate_knowledge_summary
```

- [ ] **Step 10.4: Update sweep.yml to include idle timeout config**

```yaml
# Append to backend/yaml_files/services/task_sweep_service/sweep.yml:
# session_idle_timeout_minutes: 30
```

- [ ] **Step 10.5: Run tests to verify they pass**

```bash
cd backend && uv run pytest tests/services/test_knowledge_base_service.py -k "idle" -v
```
Expected: 2 PASS

- [ ] **Step 10.6: Run full test suite**

```bash
cd backend && uv run pytest -v
```
Expected: all PASS

- [ ] **Step 10.7: Lint**

```bash
cd backend && sh scripts/lint.sh
```
Expected: no errors

- [ ] **Step 10.8: Final commit**

```bash
cd backend && git add src/services/task_sweep_service/sweep.py yaml_files/services/task_sweep_service/sweep.yml tests/services/test_knowledge_base_service.py
git commit -m "feat(knowledge-store): add idle timeout trigger in BackgroundSweepService"
```

---

## Done

FastAPI knowledge store implementation complete. The NanoClaw MCP server (skill-based) is a separate plan:
`docs/superpowers/plans/2026-03-12-knowledge-store-nanoclaw.md` (to be written).
