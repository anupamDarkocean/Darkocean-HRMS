import frappe
from frappe import _


def execute(filters=None):
    return get_columns(), get_data(filters)


def get_columns():
    return [
        {"label": _("Project"), "fieldname": "project", "fieldtype": "Data", "width": 160},
        {"label": _("Department"), "fieldname": "department", "fieldtype": "Data", "width": 140},
        {"label": _("Grade"), "fieldname": "grade", "fieldtype": "Data", "width": 130},
        {"label": _("Headcount"), "fieldname": "headcount", "fieldtype": "Int", "width": 100},
    ]


def get_data(filters=None):
    return frappe.db.sql("""
        SELECT
            COALESCE(custom_project_assignment, 'Unassigned') as project,
            department,
            COALESCE(custom_employee_grade, 'Ungraded') as grade,
            COUNT(*) as headcount
        FROM `tabEmployee`
        WHERE status = 'Active'
        GROUP BY custom_project_assignment, department, custom_employee_grade
        ORDER BY project, department, grade
    """, as_dict=True)
