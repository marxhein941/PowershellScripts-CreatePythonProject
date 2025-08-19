param (
    [string]$ProjectName,
    [string]$BasePath,
    [string]$UseJupyter
)

# --- STEP 0: Handle project parameters ---
if (-not $ProjectName) {
    $ProjectName = Read-Host "Please enter the project name for your new Python project"
}
if (-not $BasePath) {
    $BasePath = Read-Host "Please enter the directory path where the project should be created"
}
if (-not $UseJupyter) {
    $UseJupyter = Read-Host "Would you like to use Jupyter Notebooks in your project? (y/n)"
}

# --- STEP 0.1: Validate base directory existence ---
if (-not (Test-Path $BasePath)) {
    Write-Host "ERROR: The directory '$BasePath' does not exist. Please provide a valid directory path." -ForegroundColor Red
    exit 1
}

Write-Host "`nPreparing to set up a new Python project named '$ProjectName' at '$BasePath'..."

# --- STEP 0.2: Validate or create project directory ---
$ProjectPath = Join-Path -Path $BasePath -ChildPath $ProjectName
if (-not (Test-Path $ProjectPath)) {
    Write-Host "`nCreating project folder '$ProjectPath'..."
    New-Item -ItemType Directory -Path $ProjectPath | Out-Null
}
else {
    Write-Host "`nNOTE: Project folder '$ProjectPath' already exists."
}

# --- STEP 1: Define utility functions ---

# --- STEP 1.0: Check Python version ---
function Test-PythonVersion {
    try {
        $pythonVersion = py --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $versionMatch = [regex]::Match($pythonVersion, 'Python (\d+)\.(\d+)')
            if ($versionMatch.Success) {
                $major = [int]$versionMatch.Groups[1].Value
                $minor = [int]$versionMatch.Groups[2].Value
                if ($major -eq 3 -and $minor -ge 8) {
                    Write-Host "Python version: $pythonVersion"
                    return $true
                }
                else {
                    Write-Host "ERROR: Python 3.8 or higher is required. Found: $pythonVersion" -ForegroundColor Red
                    return $false
                }
            }
        }
        return $false
    }
    catch {
        Write-Host "ERROR: Python is not installed or not accessible via 'py' command." -ForegroundColor Red
        return $false
    }
}

# --- STEP 1.1: Test if a Python module is importable using `py` ---
function Test-PythonModule($moduleName) {
    $cmd = "import $moduleName"
    try {
        py -c $cmd 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

# --- STEP 1.2: Ensure a Python module is installed via `py -m pip` ---
function Install-PythonModule($moduleName) {
    if (!(Test-PythonModule $moduleName)) {
        Write-Host "Installing missing dependency '$moduleName'..."
        py -m pip install --quiet $moduleName

        if (Test-PythonModule $moduleName) {
            Write-Host "Successfully installed '$moduleName'."
        }
        else {
            Write-Host "ERROR: Could not install '$moduleName'. Please install it manually and rerun." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "'$moduleName' already available."
    }
}

# --- STEP 1.3: Test if Poetry is available ---
function Test-Poetry {
    try {
        $poetryVersion = poetry --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Poetry is available: $poetryVersion"
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

# --- STEP 2: Validate Python installation and dependencies ---
Write-Host "`nSTEP 2: Validating Python installation..."
if (-not (Test-PythonVersion)) {
    Write-Host "Please install Python 3.8 or higher and ensure it's accessible via the 'py' command." -ForegroundColor Red
    exit 1
}

Write-Host "Upgrading pip with the Python launcher to avoid dependency resolver issues..."
py -m pip install --upgrade pip --quiet

# Install-PythonModule "urllib3"
# Install-PythonModule "requests"
# Install-PythonModule "certifi"
# Install-PythonModule "idna"
# Install-PythonModule "python-dotenv"
# Install-PythonModule "notebook"

# --- STEP 3: Check Poetry installation ---
Write-Host "`nSTEP 3: Checking Poetry installation..."
if (-not (Test-Poetry)) {
    Write-Host "Poetry not found. Attempting installation..."
    Invoke-Expression "(Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | py -"

    # Add Poetry's default install location to PATH for this session
    $env:Path += ";$env:USERPROFILE\.poetry\bin"
    Write-Host "Poetry installed. Re-checking availability..."

    if (-not (Test-Poetry)) {
        Write-Host "Poetry installation still not found. Ensure Python is in your PATH and try again." -ForegroundColor Red
        exit 1
    }
}
Write-Host "Poetry is already installed and available."

# --- STEP 4: Initialize a new Poetry project ---
Write-Host "`nSTEP 4: Initializing a new Poetry project named '$ProjectName' in '$ProjectPath'..."

try {
    # --- STEP 4.1: Create project structure with Poetry ---
    Set-Location -Path $BasePath
    poetry new --src --name $ProjectName $ProjectName | Out-Null

    Set-Location -Path $ProjectPath

    # --- STEP 4.2: Configure Poetry environment ---
    Write-Host "Forcing Poetry to use 'py' so it doesn't rely on a missing 'python' command..."
    poetry env use py | Out-Null

    Write-Host "Adding core dependencies..."
    $addResult = poetry add python-dotenv 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to add python-dotenv: $addResult" -ForegroundColor Yellow
    }

    # --- STEP 4.3: Add development dependencies ---
    Write-Host "Adding development dependencies (pytest, black, flake8, mypy, isort, pre-commit)..."
    $devResult = poetry add --group dev pytest pytest-cov black flake8 mypy isort pre-commit 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Some development dependencies may not have been installed: $devResult" -ForegroundColor Yellow
    }

    # --- STEP 4.4: Check Jupyter Notebook support ---
    if ($UseJupyter -eq "y") {
        Write-Host "Installing Jupyter Notebooks and ipykernel..."
        Set-Location -Path $BasePath
        $jupyterResult = poetry add notebook ipykernel 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: Failed to add Jupyter dependencies: $jupyterResult" -ForegroundColor Yellow
        }
        Set-Location -Path $ProjectPath
        Write-Host "Jupyter Notebooks installation completed."
    }
    else {
        Write-Host "Skipping Jupyter Notebooks installation."
    }

    # --- STEP 4.5: Update Poetry dependencies ---
    Write-Host "`nUpdating dependencies with 'poetry update'..."
    poetry update | Out-Null
}
catch {
    Write-Host "Failed to create or update the Poetry project. Check your Python/Poetry installation." -ForegroundColor Red
    exit 1
}

# --- STEP 5: Create project configuration files ---
Write-Host "`nSTEP 5: Creating .gitignore..."
$gitignoreContent = @"
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*.class

# Virtual environment and environment variables
venv/
.env

# IDE and editor settings
.vscode/
.idea/
*.code-workspace

# Distribution / packaging
build/
dist/
*.egg-info/
*.egg

# Logs and temporary files
*.log
*.tmp
*.bak
*.swp

# OS-generated files
.DS_Store
Thumbs.db

# Autogenerated documentation or assets (if applicable)
assets/generated/
docs/generated/

# Poetry-related files
# Remove the following if you want to track it
poetry.lock

# Project structure folder
projstructure/

# Cache files
*.pytest_cache
.mypy_cache/

# pytest
.pytest_cache

# Docs
*docs

"@
Set-Content -Path ".gitignore" -Value $gitignoreContent

# --- STEP 6: Create folder structure and files ---

Write-Host "`nSTEP 6: Setting up project structure..."

# --- STEP 6.1: Create 'src' and Python package files ---
if (-not (Test-Path -Path "src")) {
    New-Item -ItemType Directory -Path "src" | Out-Null
}
if (-not (Test-Path -Path "src\__init__.py")) {
    New-Item -Path "src\__init__.py" -ItemType "File" -Value "# This file marks 'src' as a Python package." | Out-Null
}

# --- STEP 6.2: Create docs folder ---
New-Item -ItemType Directory -Path "docs" -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "docs/README.md" -ItemType "File" -Value "# Documentation" | Out-Null

# --- STEP 6.3: Create tests folder and sample test ---
if (-not (Test-Path -Path "tests")) {
    New-Item -ItemType Directory -Path "tests" | Out-Null
}
New-Item -Path "tests/__init__.py" -ItemType "File" -Value "" | Out-Null
New-Item -Path "tests/test_main.py" -ItemType "File" -Value @"
import pytest
from src.main import main

def test_example():
    """Example test case."""
    assert 1 + 1 == 2

def test_main():
    """Test the main function."""
    # This will need to be updated based on your main function
    assert main() is None
"@ | Out-Null

# --- STEP 6.4: Create .env file ---
if (-not (Test-Path -Path ".env")) {
    Write-Host "Creating .env file with default URL variable..."
    New-Item -Path ".env" -ItemType "File" -Value @"
# Environment variables for the project
# Add additional variables in the format:
# VARIABLE_NAME=value

URL=https://github.com/
"@ | Out-Null
}

# --- STEP 6.5: Create src/env_utils.py ---
$pythonFilePath = "src\env_utils.py"
$pythonFileContent = @"
from dotenv import load_dotenv, find_dotenv, get_key, set_key

dotenv_path = find_dotenv()

load_dotenv(dotenv_path)

def update_environment_variable(key, value):
    set_key(dotenv_path, key, value)
    load_dotenv(dotenv_path)
    
def get_environment_variable(key):
    return get_key(dotenv_path, key)

def get_url():
    return get_environment_variable('URL')
"@
Write-Host "Creating Python file '$pythonFilePath'..."
Set-Content -Path $pythonFilePath -Value $pythonFileContent

# --- STEP 6.5.1: Create src/main.py ---
$mainFilePath = "src\main.py"
$mainFileContent = @"
import logging
from pathlib import Path
from env_utils import get_environment_variable, update_environment_variable

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main entry point of the application."""
    logger.info("Application started")
    
    # Example: Read an environment variable
    url = get_environment_variable('URL')
    if url:
        logger.info(f"URL from environment: {url}")
    
    # Your application logic here
    logger.info("Application finished")
    
if __name__ == "__main__":
    main()
"@
Write-Host "Creating main.py entry point..."
Set-Content -Path $mainFilePath -Value $mainFileContent

# --- STEP 6.5.2: Create logging configuration ---
$loggingConfigPath = "src\logging_config.py"
$loggingConfigContent = @"
import logging
import logging.config
from pathlib import Path

# Create logs directory if it doesn't exist
log_dir = Path('logs')
log_dir.mkdir(exist_ok=True)

LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        },
        'detailed': {
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s'
        }
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'level': 'INFO',
            'formatter': 'standard',
            'stream': 'ext://sys.stdout'
        },
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'DEBUG',
            'formatter': 'detailed',
            'filename': 'logs/app.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5
        }
    },
    'loggers': {
        '': {  # root logger
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False
        }
    }
}

def setup_logging():
    """Set up logging configuration."""
    logging.config.dictConfig(LOGGING_CONFIG)
"@
Write-Host "Creating logging configuration..."
Set-Content -Path $loggingConfigPath -Value $loggingConfigContent

# --- STEP 6.6: Create README.md ---
$readmePath = "README.md"
$readmeContent = @"
# $ProjectName

A Python project created with create-python-project.ps1

## Project Structure

```
$ProjectName/
├── src/                    # Source code
│   ├── __init__.py
│   ├── main.py            # Main entry point
│   ├── env_utils.py       # Environment variable utilities
│   └── logging_config.py  # Logging configuration
├── tests/                 # Test files
│   ├── __init__.py
│   └── test_main.py
├── docs/                  # Documentation
├── scripts/               # Utility scripts
├── .env                   # Environment variables (not in git)
├── .gitignore
├── pyproject.toml         # Poetry configuration
└── README.md
```

## Setup

### Prerequisites

- Python 3.8 or higher
- Poetry (installed automatically if not present)

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   poetry install
   ```

### Running the Application

```bash
poetry run python src/main.py
```

### Running Tests

```bash
poetry run pytest
```

With coverage:
```bash
poetry run pytest --cov=src --cov-report=html
```

### Code Quality

Format code:
```bash
poetry run black .
```

Lint code:
```bash
poetry run flake8 .
```

Type checking:
```bash
poetry run mypy src/
```

Sort imports:
```bash
poetry run isort .
```

### Pre-commit Hooks

Install pre-commit hooks:
```bash
poetry run pre-commit install
```

Run manually:
```bash
poetry run pre-commit run --all-files
```

## Environment Variables

Copy `.env.example` to `.env` and update the values:

```bash
cp .env.example .env
```

## Development

### Adding Dependencies

```bash
poetry add <package-name>
```

For development dependencies:
```bash
poetry add --group dev <package-name>
```

### Updating Dependencies

```bash
poetry update
```

## License

[Your License Here]
"@
Write-Host "Creating README.md..."
Set-Content -Path $readmePath -Value $readmeContent

# --- STEP 6.7: Create .env.example ---
$envExamplePath = ".env.example"
$envExampleContent = @"
# Environment variables for the project
# Copy this file to .env and update the values

# API URLs
URL=https://api.example.com

# API Keys (keep these secret!)
API_KEY=your-api-key-here

# Database
DATABASE_URL=postgresql://user:password@localhost/dbname

# Application Settings
DEBUG=False
LOG_LEVEL=INFO
"@
Write-Host "Creating .env.example..."
Set-Content -Path $envExamplePath -Value $envExampleContent

# --- STEP 6.8: Create "scripts" folder and add .ps1 scripts
Write-Host "`nCreating 'scripts' folder and adding sample scripts..."

# Define the "scripts" folder path
$scriptsFolderPath = Join-Path -Path $ProjectPath -ChildPath "scripts"

# Create the "scripts" folder if it doesn't already exist
if (-not (Test-Path -Path $scriptsFolderPath)) {
    New-Item -ItemType Directory -Path $scriptsFolderPath | Out-Null
    Write-Host "Created 'scripts' folder at $scriptsFolderPath"
}
else {
    Write-Host "The 'scripts' folder already exists at $scriptsFolderPath"
}

# Define the paths for the new script files
$scriptProjectStructureAll = Join-Path -Path $scriptsFolderPath -ChildPath "get-project-structure-all.ps1"
#$scriptProjectStructureSrc = Join-Path -Path $scriptsFolderPath -ChildPath "get-project-structure-src.ps1"

# Add content to get-project-structure-all.ps1
if (-not (Test-Path -Path $scriptProjectStructureAll)) {
    Set-Content -Path $scriptProjectStructureAll -Value @"
# -------------------------------------
# Script to generate a tree structure starting from one directory above the script's directory
# -------------------------------------

# Get the directory of the script
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Go ONE level up from the script's directory
$rootFolder = [System.IO.Path]::GetFullPath("$scriptDirectory\..")

# Create a "docs" folder in the parent directory (one level up)
$docsFolder = Join-Path $rootFolder "docs"

# Define the output file path
$outputFile = Join-Path $docsFolder "project_structure_all.txt"

Write-Host "DEBUG: scriptDirectory = $scriptDirectory"
Write-Host "DEBUG: rootFolder      = $rootFolder"
Write-Host "DEBUG: docsFolder      = $docsFolder"
Write-Host "DEBUG: outputFile      = $outputFile"

# Check/create the 'docs' folder
if (-not (Test-Path $docsFolder)) {
    Write-Host "Creating 'docs' folder in parent directory..."
    try {
        New-Item -ItemType Directory -Path $docsFolder -Force | Out-Null
        Write-Host "'docs' folder created successfully."
    }
    catch {
        Write-Host "Error creating 'docs' folder: $_"
        exit
    }
}
else {
    Write-Host "'docs' folder already exists in parent directory."
}

# Remove the old text file if it exists
if (Test-Path $outputFile) {
    Write-Host "Removing existing output file: $outputFile"
    try {
        Remove-Item $outputFile -Force
        Write-Host "Existing output file removed."
    }
    catch {
        Write-Host "Error removing existing output file: $_"
        exit
    }
}

# Generate the folder structure via 'tree', filtering out __pycache__ and .pyc
Write-Host "Generating project structure from $rootFolder (via tree command)..."
try {
    # Use cmd /c to ensure 'tree' is recognized
    $treeOutput = cmd /c "tree `"$rootFolder`" /F /A"

    # Check if the tree output is empty
    if (-not $treeOutput) {
        Write-Host "Error: No output generated by the 'tree' command. Ensure the directory exists and is accessible." -ForegroundColor Red
        exit
    }

    # Filter out lines containing __pycache__ or .pyc
    $filteredTreeOutput = $treeOutput | Where-Object { $_ -notmatch '__pycache__|\.pyc' }

    # Ensure filtered output is not empty
    if (-not $filteredTreeOutput) {
        Write-Host "Warning: No valid content to write after filtering '__pycache__' or '.pyc'." -ForegroundColor Yellow
        Write-Host "Empty output file will be created at $outputFile."
    }

    # Write filtered output to file
    $filteredTreeOutput | Out-File -FilePath $outputFile -Force

    Write-Host "Project structure has been saved to $outputFile"
}
catch {
    Write-Host "Error generating project structure: $_"
    exit
}

"@
    Write-Host "Created 'get-project-structure-all.ps1' in the 'scripts' folder."
}
else {
    Write-Host "'get-project-structure-all.ps1' already exists in the 'scripts' folder."
}

# # Add content to get-project-structure-src.ps1
# if (-not (Test-Path -Path $scriptProjectStructureSrc)) {
#     Set-Content -Path $scriptProjectStructureSrc -Value @"
# # get-project-structure-src.ps1
# # This is a sample script for script2.
# Write-Host 'Hello from script2!'
# "@

#     Write-Host "Created 'get-project-structure-src.ps1' in the 'scripts' folder."
# } else {
#     Write-Host "'get-project-structure-src.ps1' already exists in the 'scripts' folder."
# }


# --- STEP 6.9: Create .vscode/settings.json ---
Write-Host "`nCreating VS Code settings for Python development..."
$vscodeDir = ".vscode"
if (-not (Test-Path -Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir | Out-Null
}

$vscodeSettingsPath = "$vscodeDir\settings.json"
$vscodeSettingsContent = @"
{
    "python.linting.enabled": true,
    "python.linting.flake8Enabled": true,
    "python.linting.mypyEnabled": true,
    "python.formatting.provider": "black",
    "python.sortImports.provider": "isort",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "python.testing.pytestEnabled": true,
    "python.testing.unittestEnabled": false,
    "python.testing.pytestArgs": [
        "tests"
    ],
    "files.exclude": {
        "**/__pycache__": true,
        "**/*.pyc": true,
        "**/.pytest_cache": true,
        "**/.mypy_cache": true
    },
    "[python]": {
        "editor.rulers": [88],
        "editor.tabSize": 4
    }
}
"@
Set-Content -Path $vscodeSettingsPath -Value $vscodeSettingsContent

# --- STEP 6.10: Create .pre-commit-config.yaml ---
Write-Host "Creating pre-commit configuration..."
$preCommitConfigPath = ".pre-commit-config.yaml"
$preCommitConfigContent = @"
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-json
      - id: check-toml
      - id: check-merge-conflict
      - id: debug-statements

  - repo: https://github.com/psf/black
    rev: 23.12.1
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/PyCQA/isort
    rev: 5.13.2
    hooks:
      - id: isort
        args: ["--profile", "black"]

  - repo: https://github.com/PyCQA/flake8
    rev: 7.0.0
    hooks:
      - id: flake8
        args: ["--max-line-length=88", "--extend-ignore=E203,W503"]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.8.0
    hooks:
      - id: mypy
        args: ["--ignore-missing-imports"]
"@
Set-Content -Path $preCommitConfigPath -Value $preCommitConfigContent

# --- STEP 6.11: Create pyproject.toml configurations ---
Write-Host "Adding tool configurations to pyproject.toml..."
$pyprojectPath = "pyproject.toml"
if (Test-Path -Path $pyprojectPath) {
    $pyprojectContent = Get-Content -Path $pyprojectPath -Raw
    
    # Add tool configurations at the end
    $toolConfigs = @"

[tool.black]
line-length = 88
target-version = ['py38', 'py39', 'py310', 'py311']
include = '\.pyi?$'

[tool.isort]
profile = "black"
line_length = 88

[tool.mypy]
python_version = "3.8"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = false
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
python_classes = "Test*"
python_functions = "test_*"
addopts = "-v --tb=short"

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/test_*.py"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "if self.debug:",
    "if settings.DEBUG",
    "raise AssertionError",
    "raise NotImplementedError",
    "if 0:",
    "if __name__ == .__main__.:",
]
"@
    
    # Append configurations if they don't already exist
    if ($pyprojectContent -notmatch "\[tool\.black\]") {
        Add-Content -Path $pyprojectPath -Value $toolConfigs
        Write-Host "Added tool configurations to pyproject.toml"
    }
}

# --- STEP 7: Set up GitHub Actions ---
Write-Host "`nSTEP 7: Setting up GitHub Actions..."
if (-not (Test-Path -Path ".github/workflows")) {
    New-Item -ItemType Directory -Path ".github/workflows" | Out-Null
}
Set-Content -Path ".github/workflows/python-ci.yml" -Value @"
name: Python CI

on:
  push:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'
      - name: Install dependencies
        run: |
          pip install poetry
          poetry install
      - name: Run tests
        run: poetry run pytest
"@

# --- STEP 8: Initialize Git repository ---
Write-Host "`nSTEP 8: Initializing Git repository..."
git init | Out-Null

# --- STEP 9: Final confirmation ---
Write-Host "`nAll steps completed!"
Write-Host "Python project '$ProjectName' has been successfully created at '$ProjectPath'!" -ForegroundColor Green
