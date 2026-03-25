import frappe
from frappe import _


def execute(filters=None):
    return get_columns(), get_data(filters)


def get_columns():
    return [
        {"label": _("Employee"), "fieldname": "employee", "fieldtype": "Link", "options": "Employee", "width": 120},
        {"label": _("Name"), "fieldname": "employee_name", "fieldtype": "Data", "width": 150},
        {"label": _("Designation"), "fieldname": "designation", "fieldtype": "Data", "width": 140},
        {"label": _("Grade"), "fieldname": "custom_employee_grade", "fieldtype": "Data", "width": 130},
        {"label": _("Vessel"), "fieldname": "custom_vessel_assignment", "fieldtype": "Link", "options": "Vessel", "width": 130},
        {"label": _("Project"), "fieldname": "custom_project_assignment", "fieldtype": "Link", "options": "Project", "width": 130},
        {"label": _("Offshore Crew"), "fieldname": "custom_offshore_crew_flag", "fieldtype": "Check", "width": 100},
        {"label": _("Subsidiary"), "fieldname": "custom_subsidiary", "fieldtype": "Data", "width": 130},
        {"label": _("Status"), "fieldname": "status", "fieldtype": "Data", "width": 80},
    ]


def get_data(filters):
    conditions = "WHERE e.status = 'Active'"
    values = {}
    if filters and filters.get("vessel"):
        conditions += " AND e.custom_vessel_assignment = %(vessel)s"
        values["vessel"] = filters["vessel"]
    if filters and filters.get("project"):
        conditions += " AND e.custom_project_assignment = %(project)s"
        values["project"] = filters["project"]
    if filters and filters.get("offshore_only"):
        conditions += " AND e.custom_offshore_crew_flag = 1"

    return frappe.db.sql(f"""
        SELECT e.name as employee, e.employee_name, e.designation,
               e.custom_employee_grade, e.custom_vessel_assignment,
               e.custom_project_assignment, e.custom_offshore_crew_flag,
               e.custom_subsidiary, e.status
        FROM `tabEmployee` e
        {conditions}
        ORDER BY e.custom_vessel_assignment, e.employee_name
    """, values, as_dict=True)
