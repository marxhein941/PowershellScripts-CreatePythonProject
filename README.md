# {{PROJECT_NAME}}

This project was generated via a PowerShell script that automates the setup of a new Python/Poetry project. Here’s an overview of the generated structure and usage tips.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Running Tests](#running-tests)
6. [Documentation](#documentation)
7. [CI/CD](#cicd)

---

## Project Structure

After running the setup script, you should have the following folders and files:

- **`src/`** – Your main Python source code goes here.
- **`tests/`** – Contains your test files.
- **`docs/`** – Optional folder for project documentation.
- **`.github/workflows/`** – Contains the GitHub Actions CI pipeline.
- **`pyproject.toml`** – Poetry configuration file with project metadata and dependencies.

---

## Prerequisites

- **Python 3.x**  
  Make sure you have Python 3 installed.  
- **Poetry**  
  The script automatically installs Poetry if it isn’t already found.  
- **Git**  
  The script also initializes a Git repository.

> **Note**: If you’re on Windows and seeing messages about “Python not found” from the Microsoft Store, you may want to [disable the Microsoft Store alias](https://learn.microsoft.com/en-us/windows/msix/packaging-tool/disable-microsoft-store-python) or [install Python from python.org](https://www.python.org/downloads/) and add it to your PATH.

---

## Installation

1. **Clone/Download** this repository.
2. **Move** into the project folder:

   ```bash
   cd {{PROJECT_NAME}}

## Usage

poetry run python src/main.py

## Running Tests

poetry run pytest

## Documentation

## CI/CD

.github/workflows/python-ci.yml
