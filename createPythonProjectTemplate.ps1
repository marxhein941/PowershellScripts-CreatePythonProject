param (
  [string]$ProjectName,
  [string]$BasePath
)

# --- STEP 0: Prompt for missing parameters ---
if (-not $ProjectName) {
  $ProjectName = Read-Host "Please enter the project name for your new Python project"
}
if (-not $BasePath) {
  $BasePath = Read-Host "Please enter the directory path where the project should be created"
}

# --- STEP 0.1: Validate the base directory ---
if (-not (Test-Path $BasePath)) {
  Write-Host "ERROR: The directory '$BasePath' does not exist. Please provide a valid directory path." -ForegroundColor Red
  exit 1
}

Write-Host "`nPreparing to set up a new Python project named '$ProjectName' at '$BasePath'..."

# --- STEP 0.2: Create or Validate the Project Folder ---
$ProjectPath = Join-Path -Path $BasePath -ChildPath $ProjectName
if (-not (Test-Path $ProjectPath)) {
  Write-Host "`nCreating project folder '$ProjectPath'..."
  New-Item -ItemType Directory -Path $ProjectPath | Out-Null
}
else {
  Write-Host "`nNOTE: Project folder '$ProjectPath' already exists."
}

# --- FUNCTION: Test if a Python module is importable using `py` ---
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

# --- FUNCTION: Ensure a Python module is installed via `py -m pip` ---
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

# --- FUNCTION: Test if Poetry is Available ---
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



# --- STEP 1: Ensure Poetry dependencies (requests, urllib3, etc.) are installed ---
Write-Host "`nSTEP 1: Ensuring Poetry dependencies are installed..."

Write-Host "Upgrading pip with the Python launcher to avoid dependency resolver issues..."
py -m pip install --upgrade pip --quiet

# Install modules that Poetry or requests commonly require
Install-PythonModule "urllib3"
Install-PythonModule "requests"
Install-PythonModule "certifi"
#Install-PythonModule "charset-normalizer"
Install-PythonModule "idna"



# --- STEP 2: Check Poetry Installation ---
Write-Host "`nSTEP 2: Checking Poetry installation..."
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



# --- STEP 3: Initialize a new Poetry project in the project folder ---
Write-Host "`nSTEP 3: Initializing a new Poetry project named '$ProjectName' in '$ProjectPath'..."

try {
  # Go to the base path, then let Poetry create the project folder structure
  Set-Location -Path $BasePath
  poetry new --src --name $ProjectName $ProjectName | Out-Null

  # Move into the newly created project folder
  Set-Location -Path $ProjectPath

  # Force Poetry to use 'py' now that pyproject.toml exists
  Write-Host "Forcing Poetry to use 'py' so it doesn't rely on a missing 'python' command..."
  poetry env use py | Out-Null

  # (Optional) Run 'poetry update' inside this new folder
  Write-Host "`nSTEP 3.1: Updating dependencies with 'poetry update'..."
  poetry update | Out-Null
}
catch {
  Write-Host "Failed to create or update the Poetry project. Check your Python/Poetry installation." -ForegroundColor Red
  exit 1
}



# --- STEP 4: Create or verify .gitignore ---
Write-Host "`nSTEP 4: Creating .gitignore..."
$gitignoreContent = @"
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# Virtual environment
venv/
.env
.vscode/

# Distribution / packaging
build/
dist/
*.egg-info/
*.egg
"@
Set-Content -Path ".gitignore" -Value $gitignoreContent



# --- STEP 5: Create Additional Files and Folders (docs, tests, src, etc.) ---
Write-Host "`nSTEP 5: Setting up project structure..."

# Create a 'src' folder for main Python source code
if (-not (Test-Path -Path "src")) {
  New-Item -ItemType Directory -Path "src" | Out-Null
}
# Optionally, create an __init__.py to make it a package
if (-not (Test-Path -Path "src\__init__.py")) {
  New-Item -Path "src\__init__.py" -ItemType "File" -Value "# This file marks 'src' as a Python package." | Out-Null
}

# Create a docs folder with a basic README
New-Item -ItemType Directory -Path "docs" -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "docs/README.md" -ItemType "File" -Value "# Documentation" | Out-Null

# Create a tests folder with a sample test
if (-not (Test-Path -Path "tests")) {
  New-Item -ItemType Directory -Path "tests" | Out-Null
}
New-Item -Path "tests/test_main.py" -ItemType "File" -Value "def test_example(): assert 1 + 1 == 2" | Out-Null



# --- STEP 6: (Optional) Add GitHub Actions workflow ---
Write-Host "`nSTEP 6: Setting up GitHub Actions..."
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



# --- STEP 7: Initialize Git Repository ---
Write-Host "`nSTEP 7: Initializing Git repository..."
git init | Out-Null



# --- FINAL CONFIRMATION MESSAGE ---
Write-Host "`nAll steps completed!"
Write-Host "Python project '$ProjectName' has been successfully created at '$ProjectPath'!" -ForegroundColor Green
