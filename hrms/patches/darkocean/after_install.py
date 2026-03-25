"""
Darkocean HRMS — After Install Setup
Runs all Darkocean customisation patches in sequence.
"""
import frappe


PATCHES = [
    "hrms.patches.darkocean.employee_naming_series",
    "hrms.patches.darkocean.setup_leave_types",
    "hrms.patches.darkocean.set_working_week",
    "hrms.patches.darkocean.setup_payroll",
    "hrms.patches.darkocean.setup_expense_types",
    "hrms.patches.darkocean.setup_designations",
    "hrms.patches.darkocean.setup_shift_types",
    "hrms.patches.darkocean.setup_kra_templates",
    "hrms.patches.darkocean.setup_print_formats",
]


def execute():
    for patch in PATCHES:
        try:
            frappe.get_attr(f"{patch}.execute")()
            frappe.logger().info(f"[Darkocean] Patch executed: {patch}")
        except Exception as e:
            frappe.log_error(f"[Darkocean] Patch failed: {patch} — {e}")
