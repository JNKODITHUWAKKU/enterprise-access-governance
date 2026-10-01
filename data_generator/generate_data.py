"""
Enterprise Access Governance — Synthetic Data Generator
========================================================

Generates realistic enterprise access data with deliberately injected
"toxic access paths" (Contractor → Group → Inherited Group → Sensitive Resource).

Usage:
    python generate_data.py

Output:
    sample_output/
        employees.json / .csv
        departments.json / .csv
        security_groups.json / .csv
        resources.json / .csv
        group_memberships.json / .csv
        group_permissions.json / .csv
        group_inheritance.json / .csv
        toxic_paths_manifest.json   (ground truth for validation)
"""

import json
import os
import random
import uuid
from datetime import datetime, timedelta

import pandas as pd
from faker import Faker

import config as cfg

# ──────────────────────────────────────────────
# Initialize
# ──────────────────────────────────────────────
fake = Faker()
Faker.seed(cfg.RANDOM_SEED)
random.seed(cfg.RANDOM_SEED)

# Ensure output directory exists
os.makedirs(cfg.OUTPUT_DIR, exist_ok=True)


def generate_id() -> str:
    """Generate a deterministic UUID-style ID."""
    return str(uuid.uuid4())


# ──────────────────────────────────────────────
# 1. DEPARTMENTS
# ──────────────────────────────────────────────
def generate_departments(n: int) -> list[dict]:
    """
    Generate departments with a simple hierarchy.
    First department is the root (CEO Office), rest have a parent.
    """
    department_names = [
        "CEO Office", "Finance", "Engineering", "Human Resources",
        "Sales", "Marketing", "Legal", "IT Operations",
        "Compliance", "Product Management", "Data Analytics", "Security"
    ]
    # Ensure we have enough names
    while len(department_names) < n:
        department_names.append(f"Department-{len(department_names) + 1}")

    departments = []
    for i in range(n):
        dept = {
            "department_id": generate_id(),
            "name": department_names[i],
            "cost_center": f"CC-{random.randint(1000, 9999)}",
            # Root department has no parent; others randomly assigned to earlier depts
            "parent_department_id": (
                None if i == 0
                else departments[random.randint(0, max(0, i - 1))]["department_id"]
            ),
        }
        departments.append(dept)

    print(f"Generated {len(departments)} departments")
    return departments


# ──────────────────────────────────────────────
# 2. EMPLOYEES
# ──────────────────────────────────────────────
def generate_employees(n: int, departments: list[dict]) -> list[dict]:
    """
    Generate employees with types distributed according to config weights.
    """
    dept_ids = [d["department_id"] for d in departments]
    emp_types = list(cfg.EMPLOYEE_TYPE_WEIGHTS.keys())
    emp_weights = list(cfg.EMPLOYEE_TYPE_WEIGHTS.values())

    employees = []
    # First, create a few managers
    manager_ids = []

    for i in range(n):
        emp_id = generate_id()
        emp_type = random.choices(emp_types, weights=emp_weights, k=1)[0]
        hire_date = fake.date_between(start_date="-5y", end_date="today")

        emp = {
            "employee_id": emp_id,
            "name": f"{fake.first_name()} {fake.last_name()}",
            "email": fake.company_email(),
            "department_id": random.choice(dept_ids),
            "employee_type": emp_type,
            "hire_date": hire_date.isoformat(),
            "manager_id": (
                random.choice(manager_ids) if manager_ids and i > 10
                else None
            ),
        }
        employees.append(emp)

        # First 10% of employees become potential managers
        if i < n * 0.1:
            manager_ids.append(emp_id)

    print(f"Generated {len(employees)} employees "
          f"({sum(1 for e in employees if e['employee_type'] == 'Contractor')} contractors, "
          f"{sum(1 for e in employees if e['employee_type'] == 'Vendor')} vendors)")
    return employees


# ──────────────────────────────────────────────
# 3. SECURITY GROUPS
# ──────────────────────────────────────────────
def generate_security_groups(n: int, departments: list[dict]) -> list[dict]:
    """
    Generate security groups. Some are department-aligned, some are cross-functional.
    """
    group_prefixes = [
        "SG-Finance-", "SG-Eng-", "SG-HR-", "SG-Sales-", "SG-IT-",
        "SG-Legal-", "SG-Compliance-", "SG-Analytics-", "SG-Security-",
        "SG-CrossFunc-", "SG-Admin-", "SG-ReadOnly-"
    ]
    group_suffixes = [
        "Readers", "Writers", "Admins", "Viewers", "Contributors",
        "Managers", "Operators", "Auditors", "Approvers", "Reviewers"
    ]

    groups = []
    for i in range(n):
        prefix = group_prefixes[i % len(group_prefixes)]
        suffix = group_suffixes[i % len(group_suffixes)]
        group = {
            "group_id": generate_id(),
            "group_name": f"{prefix}{suffix}",
            "description": fake.sentence(nb_words=8),
            # Some groups are nested under earlier groups (creates hierarchy)
            "parent_group_id": (
                None if i < 5
                else groups[random.randint(0, min(i - 1, len(groups) - 1))]["group_id"]
                if random.random() < 0.3
                else None
            ),
        }
        groups.append(group)

    print(f"Generated {len(groups)} security groups")
    return groups


# ──────────────────────────────────────────────
# 4. RESOURCES
# ──────────────────────────────────────────────
def generate_resources(n: int, departments: list[dict]) -> list[dict]:
    """
    Generate resources (databases, servers, apps, file shares) with sensitivity levels.
    """
    resource_name_templates = {
        "Database": ["FinanceDB", "HRDB", "SalesDB", "AnalyticsDB", "PayrollDB",
                      "CustomerDB", "InventoryDB", "AuditDB", "ComplianceDB", "RevenueDB"],
        "Server": ["PROD-WEB-01", "PROD-APP-01", "PROD-DB-01", "DEV-APP-01",
                    "STAGING-01", "BUILD-SERVER", "LOG-SERVER", "AUTH-SERVER",
                    "BACKUP-01", "MONITOR-01"],
        "Application": ["SAP-ERP", "Salesforce-CRM", "Workday-HR", "Jira-PM",
                         "Confluence-Wiki", "ServiceNow-ITSM", "Tableau-Analytics",
                         "Okta-IAM", "Slack-Comms", "GitHub-DevOps"],
        "FileShare": ["\\\\corp\\finance-reports", "\\\\corp\\hr-docs",
                       "\\\\corp\\legal-contracts", "\\\\corp\\engineering-specs",
                       "\\\\corp\\executive-briefs", "\\\\corp\\audit-findings",
                       "\\\\corp\\payroll-data", "\\\\corp\\customer-pii",
                       "\\\\corp\\compliance-docs", "\\\\corp\\security-policies"],
    }

    dept_ids = [d["department_id"] for d in departments]
    resources = []

    for i in range(n):
        res_type = random.choices(
            cfg.RESOURCE_TYPES,
            weights=[0.30, 0.20, 0.30, 0.20],
            k=1
        )[0]
        names = resource_name_templates[res_type]
        res_name = names[i % len(names)]
        # Append a numeric suffix to guarantee uniqueness
        if i >= len(names):
            res_name = f"{res_name}-{i}"

        sensitivity = random.choices(
            cfg.SENSITIVITY_LEVELS,
            weights=cfg.SENSITIVITY_WEIGHTS,
            k=1
        )[0]

        resource = {
            "resource_id": generate_id(),
            "resource_name": res_name,
            "resource_type": res_type,
            "sensitivity": sensitivity,
            "owner_department_id": random.choice(dept_ids),
        }
        resources.append(resource)

    print(f"Generated {len(resources)} resources "
          f"({sum(1 for r in resources if r['sensitivity'] in ('High', 'Critical'))} high/critical)")
    return resources


# ──────────────────────────────────────────────
# 5. GROUP MEMBERSHIPS (Employee → Group edges)
# ──────────────────────────────────────────────
def generate_group_memberships(
    employees: list[dict],
    groups: list[dict],
) -> list[dict]:
    """
    Assign each employee to 1–4 security groups.
    """
    group_ids = [g["group_id"] for g in groups]
    memberships = []
    seen = set()

    for emp in employees:
        num_groups = random.randint(
            cfg.MIN_GROUPS_PER_EMPLOYEE,
            cfg.MAX_GROUPS_PER_EMPLOYEE,
        )
        assigned_groups = random.sample(group_ids, min(num_groups, len(group_ids)))

        for gid in assigned_groups:
            key = (emp["employee_id"], gid)
            if key in seen:
                continue
            seen.add(key)

            memberships.append({
                "employee_id": emp["employee_id"],
                "group_id": gid,
                "assigned_date": fake.date_between(
                    start_date="-3y", end_date="today"
                ).isoformat(),
                "assigned_by": "System-AutoProvision",
            })

    print(f"Generated {len(memberships)} group membership edges")
    return memberships


# ──────────────────────────────────────────────
# 6. GROUP PERMISSIONS (Group → Resource edges)
# ──────────────────────────────────────────────
def generate_group_permissions(
    groups: list[dict],
    resources: list[dict],
) -> list[dict]:
    """
    Assign each group 1–4 resource permissions.
    """
    resource_ids = [r["resource_id"] for r in resources]
    permissions = []
    seen = set()

    for grp in groups:
        num_perms = random.randint(
            cfg.MIN_PERMISSIONS_PER_GROUP,
            cfg.MAX_PERMISSIONS_PER_GROUP,
        )
        assigned_resources = random.sample(
            resource_ids, min(num_perms, len(resource_ids))
        )

        for rid in assigned_resources:
            key = (grp["group_id"], rid)
            if key in seen:
                continue
            seen.add(key)

            perm_level = random.choices(
                cfg.PERMISSION_LEVELS,
                weights=cfg.PERMISSION_LEVEL_WEIGHTS,
                k=1,
            )[0]

            permissions.append({
                "group_id": grp["group_id"],
                "resource_id": rid,
                "permission_level": perm_level,
                "granted_date": fake.date_between(
                    start_date="-2y", end_date="today"
                ).isoformat(),
            })

    print(f"Generated {len(permissions)} group permission edges")
    return permissions


# ──────────────────────────────────────────────
# 7. GROUP INHERITANCE (Group → Group edges)
# ──────────────────────────────────────────────
def generate_group_inheritance(
    groups: list[dict],
    n_edges: int,
) -> list[dict]:
    """
    Create group inheritance edges (child inherits parent's permissions).
    Avoids self-loops and duplicate edges.
    """
    group_ids = [g["group_id"] for g in groups]
    inheritance = []
    seen = set()

    attempts = 0
    while len(inheritance) < n_edges and attempts < n_edges * 10:
        attempts += 1
        child = random.choice(group_ids)
        parent = random.choice(group_ids)

        if child == parent:
            continue
        key = (child, parent)
        if key in seen:
            continue
        seen.add(key)

        inheritance.append({
            "child_group_id": child,
            "parent_group_id": parent,
        })

    print(f"Generated {len(inheritance)} group inheritance edges")
    return inheritance


# ──────────────────────────────────────────────
# 8. TOXIC PATH INJECTION
# ──────────────────────────────────────────────
def inject_toxic_paths(
    employees: list[dict],
    groups: list[dict],
    resources: list[dict],
    memberships: list[dict],
    permissions: list[dict],
    inheritance: list[dict],
    n_toxic: int,
) -> list[dict]:
    """
    Deliberately create N toxic access paths:
        Contractor → Group A → (inherits from) Group B → Write/Admin on High/Critical Resource

    Returns a manifest of injected toxic paths for validation.
    """
    contractors = [e for e in employees if e["employee_type"] == "Contractor"]
    high_crit_resources = [
        r for r in resources if r["sensitivity"] in ("High", "Critical")
    ]

    if not contractors or not high_crit_resources:
        print("Not enough contractors or high/critical resources to inject toxic paths")
        return []

    # Track existing edges for dedup
    membership_keys = {(m["employee_id"], m["group_id"]) for m in memberships}
    permission_keys = {(p["group_id"], p["resource_id"]) for p in permissions}
    inheritance_keys = {(i["child_group_id"], i["parent_group_id"]) for i in inheritance}

    toxic_manifest = []
    group_ids = [g["group_id"] for g in groups]
    group_lookup = {g["group_id"]: g["group_name"] for g in groups}
    resource_lookup = {r["resource_id"]: r for r in resources}

    injected = 0
    for i in range(min(n_toxic, len(contractors), len(high_crit_resources))):
        contractor = contractors[i % len(contractors)]
        resource = high_crit_resources[i % len(high_crit_resources)]

        # Pick two distinct groups for the path
        group_a_id = group_ids[i % len(group_ids)]
        group_b_id = group_ids[(i + len(group_ids) // 2) % len(group_ids)]

        if group_a_id == group_b_id:
            group_b_id = group_ids[(i + 1) % len(group_ids)]

        # 1. Contractor → Group A (membership)
        mem_key = (contractor["employee_id"], group_a_id)
        if mem_key not in membership_keys:
            memberships.append({
                "employee_id": contractor["employee_id"],
                "group_id": group_a_id,
                "assigned_date": fake.date_between(
                    start_date="-1y", end_date="today"
                ).isoformat(),
                "assigned_by": "System-RoleChange",
            })
            membership_keys.add(mem_key)

        # 2. Group A inherits from Group B
        inh_key = (group_a_id, group_b_id)
        if inh_key not in inheritance_keys:
            inheritance.append({
                "child_group_id": group_a_id,
                "parent_group_id": group_b_id,
            })
            inheritance_keys.add(inh_key)

        # 3. Group B → High/Critical Resource with Write or Admin
        perm_level = random.choice(["Write", "Admin"])
        perm_key = (group_b_id, resource["resource_id"])
        if perm_key not in permission_keys:
            permissions.append({
                "group_id": group_b_id,
                "resource_id": resource["resource_id"],
                "permission_level": perm_level,
                "granted_date": fake.date_between(
                    start_date="-1y", end_date="today"
                ).isoformat(),
            })
            permission_keys.add(perm_key)

        toxic_manifest.append({
            "toxic_path_id": i + 1,
            "contractor_name": contractor["name"],
            "contractor_id": contractor["employee_id"],
            "direct_group": group_lookup.get(group_a_id, group_a_id),
            "direct_group_id": group_a_id,
            "inherited_group": group_lookup.get(group_b_id, group_b_id),
            "inherited_group_id": group_b_id,
            "resource_name": resource["resource_name"],
            "resource_id": resource["resource_id"],
            "sensitivity": resource["sensitivity"],
            "permission_level": perm_level,
            "path": (
                f"{contractor['name']} → {group_lookup.get(group_a_id)} "
                f"→ (inherits) {group_lookup.get(group_b_id)} "
                f"→ [{perm_level}] {resource['resource_name']} ({resource['sensitivity']})"
            ),
        })
        injected += 1

    print(f"Injected {injected} toxic access paths")
    return toxic_manifest


# ──────────────────────────────────────────────
# OUTPUT HELPERS
# ──────────────────────────────────────────────
def save_dataset(data: list[dict], name: str) -> None:
    """Save a dataset as both JSON and CSV."""
    for fmt in cfg.OUTPUT_FORMATS:
        filepath = os.path.join(cfg.OUTPUT_DIR, f"{name}.{fmt}")
        if fmt == "json":
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, default=str)
        elif fmt == "csv":
            df = pd.DataFrame(data)
            df.to_csv(filepath, index=False)
        print(f" Saved {filepath} ({len(data)} records)")


# ──────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────
def main():
    print("=" * 60)
    print("Enterprise Access Governance — Data Generator")
    print("=" * 60)
    print()

    # Generate entities (NODES)
    departments = generate_departments(cfg.NUM_DEPARTMENTS)
    employees = generate_employees(cfg.NUM_EMPLOYEES, departments)
    groups = generate_security_groups(cfg.NUM_SECURITY_GROUPS, departments)
    resources = generate_resources(cfg.NUM_RESOURCES, departments)

    # Generate relationships (EDGES)
    memberships = generate_group_memberships(employees, groups)
    permissions = generate_group_permissions(groups, resources)
    inheritance = generate_group_inheritance(groups, cfg.NUM_GROUP_INHERITANCE_EDGES)

    # Inject deliberate toxic paths
    print()
    toxic_manifest = inject_toxic_paths(
        employees, groups, resources,
        memberships, permissions, inheritance,
        cfg.NUM_TOXIC_PATHS,
    )

    # Save all datasets
    print()
    print("Saving datasets...")
    save_dataset(departments, "departments")
    save_dataset(employees, "employees")
    save_dataset(groups, "security_groups")
    save_dataset(resources, "resources")
    save_dataset(memberships, "group_memberships")
    save_dataset(permissions, "group_permissions")
    save_dataset(inheritance, "group_inheritance")

    # Save the toxic path manifest (ground truth for validation)
    manifest_path = os.path.join(cfg.OUTPUT_DIR, "toxic_paths_manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(toxic_manifest, f, indent=2, default=str)
    print(f" Saved {manifest_path} ({len(toxic_manifest)} toxic paths)")

    # Print summary
    print()
    print("=" * 60)
    print("GENERATION COMPLETE — Summary")
    print("=" * 60)
    print(f"  Departments:        {len(departments)}")
    print(f"  Employees:          {len(employees)}")
    print(f"  Security Groups:    {len(groups)}")
    print(f"  Resources:          {len(resources)}")
    print(f"  Group Memberships:  {len(memberships)}")
    print(f"  Group Permissions:  {len(permissions)}")
    print(f"  Group Inheritance:  {len(inheritance)}")
    print(f"  Toxic Paths:        {len(toxic_manifest)}")
    print()
    print("Injected Toxic Paths:")
    for tp in toxic_manifest:
        print(f"   [{tp['toxic_path_id']}] {tp['path']}")
    print()
    print(f"Output directory: {os.path.abspath(cfg.OUTPUT_DIR)}")


if __name__ == "__main__":
    main()
