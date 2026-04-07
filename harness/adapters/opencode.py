"""OpenCodeInterpreter adapter.

Wraps OpenCodeInterpreter for code-generation agents (implementer,
common-module-writer). Uses the tool abstraction layer for file I/O
since OCI may not have native file editing like Claude Code.

Supports two modes:
1. API mode: Direct HTTP calls to an OCI server
2. CLI mode: Subprocess invocation of an OCI command
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import shutil
from typing import Any

from harness.adapters.base import (
    AdapterCapabilities,
    AgentContext,
    AgentResult,
    ModelAdapter,
)
from harness.agents.loader import load_agent_spec
from harness.prompt_builder import PromptBuilder
from harness.tools.registry import create_tool_registry

logger = logging.getLogger(__name__)


class OpenCodeAdapter(ModelAdapter):
    """Adapter for OpenCodeInterpreter.

    Best suited for coding agents (implementer, common-module-writer).
    The orchestrator handles sub-agent orchestration since OCI doesn't
    support agent nesting.
    """

    def __init__(
        self,
        prompts_dir: str = "harness/prompts",
        server_url: str | None = None,
    ) -> None:
        self._prompts_dir = prompts_dir
        self._server_url = server_url or os.environ.get(
            "OPENCODE_SERVER_URL", "http://localhost:8080"
        )

    @property
    def name(self) -> str:
        return "opencode"

    @property
    def capabilities(self) -> AdapterCapabilities:
        return AdapterCapabilities(
            supports_sub_agents=False,
            supports_parallel=False,
            supports_mcp=False,
            supports_memory=False,
            supports_isolation=False,
            max_context_window=32_000,
            supported_tools=["file:read", "file:write", "shell:exec"],
        )

    async def check_available(self) -> bool:
        """Check if OCI server is reachable or CLI is installed."""
        # Check CLI
        if shutil.which("opencode") or shutil.which("open-interpreter"):
            return True
        # Check server
        try:
            import urllib.request

            req = urllib.request.Request(
                f"{self._server_url}/health", method="GET"
            )
            urllib.request.urlopen(req, timeout=3)
            return True
        except Exception:
            return False

    async def run_agent(
        self, agent_name: str, context: AgentContext
    ) -> AgentResult:
        # Build prompt with context files
        spec = load_agent_spec(agent_name)
        prompt_builder = PromptBuilder(self._prompts_dir)
        system_prompt = prompt_builder.build(agent_name, adapter_name="opencode")

        if not system_prompt and spec:
            system_prompt = spec.description

        # Inject relevant state file contents into the prompt
        tool_registry = create_tool_registry(cwd=context.project_dir)
        enriched_prompt = await self._enrich_prompt(
            system_prompt, context, spec, tool_registry
        )

        full_prompt = f"{enriched_prompt}\n\n---\n\n{context.message}"

        # Try API mode first, fall back to CLI
        if await self._try_api(full_prompt, context):
            return await self._run_api(full_prompt, context)
        return await self._run_cli(full_prompt, context)

    async def _enrich_prompt(
        self, base_prompt: str, context: AgentContext, spec: Any, registry: dict
    ) -> str:
        """Read input files and inject their contents into the prompt."""
        if spec is None or not spec.inputs:
            return base_prompt

        file_reader = registry.get("file:read")
        if file_reader is None:
            return base_prompt

        sections = [base_prompt]
        for input_path in spec.inputs:
            result = await file_reader.execute(
                path=os.path.join(context.project_dir, input_path)
            )
            if result.success and result.output.strip():
                sections.append(f"\n## {input_path}\n```\n{result.output}\n```")

        return "\n".join(sections)

    async def _try_api(self, prompt: str, context: AgentContext) -> bool:
        """Check if API mode is available."""
        try:
            import urllib.request

            req = urllib.request.Request(
                f"{self._server_url}/health", method="GET"
            )
            urllib.request.urlopen(req, timeout=2)
            return True
        except Exception:
            return False

    async def _run_api(
        self, prompt: str, context: AgentContext
    ) -> AgentResult:
        """Run via OCI HTTP API."""
        try:
            import urllib.request

            payload = json.dumps({
                "prompt": prompt,
                "working_directory": context.project_dir,
            }).encode("utf-8")

            req = urllib.request.Request(
                f"{self._server_url}/generate",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=300) as resp:
                result = json.loads(resp.read().decode("utf-8"))

            return AgentResult(
                success=True,
                output=result.get("output", ""),
                files_changed=result.get("files_changed", []),
            )
        except Exception as e:
            logger.exception("OCI API error")
            return AgentResult(success=False, error=str(e))

    async def _run_cli(
        self, prompt: str, context: AgentContext
    ) -> AgentResult:
        """Run via OCI CLI (open-interpreter or similar)."""
        cli = shutil.which("opencode") or shutil.which("open-interpreter")
        if cli is None:
            return AgentResult(
                success=False,
                error="Neither 'opencode' nor 'open-interpreter' CLI found, and API server not reachable.",
            )

        proc = await asyncio.create_subprocess_exec(
            cli,
            "--non-interactive",
            "--message",
            prompt,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=context.project_dir,
        )
        stdout, stderr = await proc.communicate()
        exit_code = proc.returncode or 0

        return AgentResult(
            success=exit_code == 0,
            output=stdout.decode("utf-8", errors="replace"),
            exit_code=exit_code,
            error=stderr.decode("utf-8", errors="replace") if exit_code != 0 else None,
        )
