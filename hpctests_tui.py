#!/usr/bin/env python3
"""
HPC Tests TUI Wrapper
Displays a split-pane TUI with:
- Left (40%): Script output with test checkpoints
- Right top (80%): htop system monitor
- Right bottom (20%): Progress bar and test tracking
"""

import subprocess
import re
import threading
import time
from collections import deque
from datetime import datetime
from typing import Optional
from textual.app import ComposeResult, RenderableType
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Static, RichLog
from textual.reactive import reactive
from textual.binding import Binding
from rich.text import Text
from rich.panel import Panel
from rich.progress import Progress, BarColumn, TextColumn, DownloadColumn, MofNCompleteColumn
from rich.table import Table
from rich.console import Console


class ScriptOutput(Static):
    """Left pane: script output with test checkpoints"""
    
    DEFAULT_CSS = """
    ScriptOutput {
        width: 40%;
        height: 100%;
        border: solid $primary;
    }
    """
    
    def __init__(self, name: Optional[str] = None, id: Optional[str] = None):
        super().__init__(name=name, id=id)
        self.output_log = RichLog(markup=True)
        self.tests_completed = []
        self.tests_failed = []
        self.current_test = None
        self.test_pattern = re.compile(r'\[(?:SUCCESS|ERROR|WARNING)\]\s+(.+?)(?:\s+\(exit|\.)')
        self.running_pattern = re.compile(r'Running Test:.*?${COLOR_YELLOW}(.+?)${COLOR_RESET}')
    
    def compose(self) -> ComposeResult:
        yield self.output_log
    
    def add_line(self, text: str) -> None:
        """Add a line to the output log"""
        self.output_log.write(Text(text))
    
    def update_test_status(self, test_name: str, status: str, reason: str = "") -> None:
        """Update test status in the left pane"""
        if status == "pass":
            self.tests_completed.append(test_name)
            self.add_line(f"[green]✓[/green] {test_name}")
        elif status == "fail":
            self.tests_failed.append(test_name)
            msg = f"[red]✗[/red] {test_name}"
            if reason:
                msg += f" - {reason}"
            self.add_line(msg)
        elif status == "running":
            self.current_test = test_name
            self.add_line(f"[yellow]⟳[/yellow] {test_name}")


class SystemMonitor(Static):
    """Right top pane: htop system monitor"""
    
    DEFAULT_CSS = """
    SystemMonitor {
        width: 60%;
        height: 80%;
        border: solid $primary;
    }
    """
    
    def __init__(self, name: Optional[str] = None, id: Optional[str] = None):
        super().__init__(name=name, id=id)
        self.htop_process: Optional[subprocess.Popen] = None
        self.htop_output = deque(maxlen=30)
        self.lock = threading.Lock()
    
    def on_mount(self) -> None:
        """Start htop monitoring"""
        self.start_htop_monitoring()
    
    def start_htop_monitoring(self) -> None:
        """Start htop in batch mode and read output"""
        def run_htop():
            try:
                # Run htop in batch mode
                self.htop_process = subprocess.Popen(
                    ['htop', '-b', '-n', '1', '-u', 'root'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                for line in self.htop_process.stdout:
                    with self.lock:
                        self.htop_output.append(line.rstrip())
            except FileNotFoundError:
                with self.lock:
                    self.htop_output.append("[Error: htop not installed]")
        
        thread = threading.Thread(target=run_htop, daemon=True)
        thread.start()
    
    def render(self) -> RenderableType:
        """Render htop output"""
        with self.lock:
            content = "\n".join(self.htop_output) if self.htop_output else "Starting htop..."
        
        return Panel(
            content,
            title="System Monitor (htop)",
            border_style="blue",
            expand=True
        )


class ProgressDisplay(Static):
    """Right bottom pane: progress bar and test tracking"""
    
    DEFAULT_CSS = """
    ProgressDisplay {
        width: 60%;
        height: 20%;
        border: solid $primary;
    }
    """
    
    def __init__(self, total_tests: int = 0, name: Optional[str] = None, id: Optional[str] = None):
        super().__init__(name=name, id=id)
        self.total_tests = total_tests
        self.completed_tests = 0
        self.failed_tests = 0
        self.lock = threading.Lock()
    
    def update_progress(self, completed: int, failed: int = 0, total: int = None) -> None:
        """Update progress counter"""
        with self.lock:
            self.completed_tests = completed
            self.failed_tests = failed
            if total:
                self.total_tests = total
        self.refresh()
    
    def render(self) -> RenderableType:
        """Render progress display"""
        with self.lock:
            completed = self.completed_tests
            failed = self.failed_tests
            total = self.total_tests
        
        # Calculate percentage
        if total > 0:
            pct = int((completed / total) * 100)
            bar_length = 20
            filled = int((completed / total) * bar_length)
            bar = "█" * filled + "░" * (bar_length - filled)
        else:
            pct = 0
            bar = "░" * 20
        
        status_text = f"[green]{completed}[/green] passed"
        if failed > 0:
            status_text += f" • [red]{failed}[/red] failed"
        
        progress_line = f"Test Progress: {bar} {pct:>3}% ({completed}/{total})"
        
        content = f"""
{progress_line}

Status: {status_text}
Runtime: {self._get_runtime()}
        """
        
        return Panel(
            content.strip(),
            title="Progress",
            border_style="green",
            expand=True
        )
    
    def _get_runtime(self) -> str:
        """Get elapsed time (placeholder)"""
        if not hasattr(self, 'start_time'):
            self.start_time = time.time()
        elapsed = int(time.time() - self.start_time)
        return f"{elapsed}s"


class HpctestsTUI(Static):
    """Main TUI container"""
    
    DEFAULT_CSS = """
    HpctestsTUI {
        width: 100%;
        height: 100%;
        background: $surface;
    }
    
    #script-output {
        width: 40%;
        height: 100%;
    }
    
    #right-pane {
        width: 60%;
        height: 100%;
    }
    
    #htop-monitor {
        width: 100%;
        height: 80%;
    }
    
    #progress-display {
        width: 100%;
        height: 20%;
    }
    """
    
    def __init__(self, script_path: str, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.script_path = script_path
        self.script_process: Optional[subprocess.Popen] = None
        self.script_thread: Optional[threading.Thread] = None
        self.test_count = 0
        self.tests_discovered = []
    
    def compose(self) -> ComposeResult:
        with Horizontal():
            yield ScriptOutput(id="script-output")
            with Vertical(id="right-pane"):
                yield SystemMonitor(id="htop-monitor")
                yield ProgressDisplay(id="progress-display")
    
    def on_mount(self) -> None:
        """Start script execution when TUI mounts"""
        self.script_thread = threading.Thread(target=self._run_script, daemon=True)
        self.script_thread.start()
    
    def _run_script(self) -> None:
        """Run the hpctests.sh script and parse output"""
        try:
            self.script_process = subprocess.Popen(
                ['bash', self.script_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            script_output = self.query_one("#script-output", ScriptOutput)
            progress = self.query_one("#progress-display", ProgressDisplay)
            
            for line in self.script_process.stdout:
                line = line.rstrip()
                
                # Add line to output
                script_output.add_line(line)
                
                # Parse test completion
                if "[SUCCESS]" in line or "[COMPLETED]" in line:
                    # Extract test name
                    match = re.search(r"Test '(.+?)' complete", line)
                    if match:
                        test_name = match.group(1)
                        script_output.update_test_status(test_name, "pass")
                        completed = len(script_output.tests_completed)
                        progress.update_progress(completed, len(script_output.tests_failed))
                
                elif "[WARNING]" in line or "command failed" in line:
                    match = re.search(r"'(.+?)'", line)
                    if match:
                        test_name = match.group(1)
                        script_output.update_test_status(test_name, "fail", "Command failed")
                        progress.update_progress(
                            len(script_output.tests_completed),
                            len(script_output.tests_failed)
                        )
                
                elif "Running Test:" in line:
                    match = re.search(r"Running Test:.*?${COLOR_YELLOW}(.+?)${COLOR_RESET}", line)
                    if match:
                        test_name = match.group(1)
                        script_output.update_test_status(test_name, "running")
            
            self.script_process.wait()
        
        except Exception as e:
            script_output = self.query_one("#script-output", ScriptOutput)
            script_output.add_line(f"[red]Error running script: {e}[/red]")


def main():
    import sys
    from textual.app import App
    
    script_path = "/home/david/code/hpctest/hpctests.sh"
    if len(sys.argv) > 1:
        script_path = sys.argv[1]
    
    class HpctestsApp(App):
        BINDINGS = [
            Binding("q", "quit", "Quit [Q]", show=True),
        ]
        
        TITLE = "HPC Tests Monitor"
        SUB_TITLE = f"Running: {script_path}"
        
        def compose(self) -> ComposeResult:
            yield HpctestsTUI(script_path)
    
    app = HpctestsApp()
    app.run()


if __name__ == "__main__":
    main()
