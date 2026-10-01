"""
Configuration for the Enterprise Access Governance Data Generator.

Adjust these parameters to control the scale and shape of the synthetic dataset.
All random operations are seeded for reproducibility.
"""

# ──────────────────────────────────────────────
# Reproducibility
# ──────────────────────────────────────────────
RANDOM_SEED = 42

# ──────────────────────────────────────────────
# Entity Counts
# ──────────────────────────────────────────────
NUM_EMPLOYEES = 500
NUM_DEPARTMENTS = 12
NUM_SECURITY_GROUPS = 30
NUM_RESOURCES = 20

# ──────────────────────────────────────────────
# Employee Distribution
# ──────────────────────────────────────────────
# Probabilities for employee types (must sum to 1.0)
EMPLOYEE_TYPE_WEIGHTS = {
    "Full-Time": 0.65,
    "Contractor": 0.25,
    "Vendor": 0.10,
}

# ──────────────────────────────────────────────
# Group Membership
# ──────────────────────────────────────────────
# Each employee is assigned to between MIN and MAX groups
MIN_GROUPS_PER_EMPLOYEE = 1
MAX_GROUPS_PER_EMPLOYEE = 4

# ──────────────────────────────────────────────
# Group Inheritance (creates transitive paths)
# ──────────────────────────────────────────────
# Number of group-to-group inheritance edges
# (child_group inherits permissions from parent_group)
NUM_GROUP_INHERITANCE_EDGES = 15

# ──────────────────────────────────────────────
# Resource Permissions
# ──────────────────────────────────────────────
# Each group gets between MIN and MAX resource permissions
MIN_PERMISSIONS_PER_GROUP = 1
MAX_PERMISSIONS_PER_GROUP = 4

PERMISSION_LEVELS = ["Read", "Write", "Admin"]
PERMISSION_LEVEL_WEIGHTS = [0.50, 0.35, 0.15]  # Read-heavy distribution

RESOURCE_TYPES = ["Database", "Server", "Application", "FileShare"]

SENSITIVITY_LEVELS = ["Low", "Medium", "High", "Critical"]
SENSITIVITY_WEIGHTS = [0.30, 0.35, 0.25, 0.10]  # Most resources are Low/Medium

# ──────────────────────────────────────────────
# Toxic Path Injection
# ──────────────────────────────────────────────
# Number of deliberate toxic paths to inject:
# Contractor → Group A → (inherits) Group B → Write/Admin on High/Critical resource
NUM_TOXIC_PATHS = 8

# ──────────────────────────────────────────────
# Output
# ──────────────────────────────────────────────
OUTPUT_DIR = "sample_output"
OUTPUT_FORMATS = ["json", "csv"]  # Generate both formats
