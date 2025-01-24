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

# --- STEP 2: Install and validate dependencies ---
Write-Host "`nSTEP 2: Ensuring Poetry dependencies are installed..."
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

    Write-Host "Adding python-dotenv as a dependency..."
    poetry add python-dotenv | Out-Null

    # --- STEP 4.3: Check Jupyter Notebook support ---
    if ($UseJupyter -eq "y") {
        Write-Host "Installing Jupyter Notebooks..."
        Set-Location -Path $BasePath
        poetry add notebook | Out-Null

        Set-Location -Path $ProjectPath

        Write-Host "Jupyter Notebooks installed successfully."
    }
    else {
        Write-Host "Skipping Jupyter Notebooks installation."
    }

    # --- STEP 4.4: Update Poetry dependencies ---
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
New-Item -Path "tests/test_main.py" -ItemType "File" -Value "def test_example(): assert 1 + 1 == 2" | Out-Null

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
    return get_environment_variable('OPENAI_URL')
"@
Write-Host "Creating Python file '$pythonFilePath'..."
Set-Content -Path $pythonFilePath -Value $pythonFileContent

# --- STEP 6.6: Create "scripts" folder and add .ps1 scripts
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
