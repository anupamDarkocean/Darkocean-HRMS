"""
WPS SIF File Export for Qatar Wage Protection System
"""
import frappe
from frappe import _


def execute(filters=None):
    return get_columns(), get_data(filters)


def get_columns():
    return [
        {"label": _("Employee ID"), "fieldname": "employee", "fieldtype": "Link", "options": "Employee", "width": 120},
        {"label": _("WPS ID"), "fieldname": "wps_id", "fieldtype": "Data", "width": 120},
        {"label": _("Employee Name"), "fieldname": "employee_name", "fieldtype": "Data", "width": 150},
        {"label": _("Bank Account"), "fieldname": "bank_account_no", "fieldtype": "Data", "width": 150},
        {"label": _("Basic Salary (QAR)"), "fieldname": "base", "fieldtype": "Currency", "width": 130},
        {"label": _("Gross Pay (QAR)"), "fieldname": "gross_pay", "fieldtype": "Currency", "width": 130},
        {"label": _("Deductions (QAR)"), "fieldname": "total_deduction", "fieldtype": "Currency", "width": 130},
        {"label": _("Net Pay (QAR)"), "fieldname": "net_pay", "fieldtype": "Currency", "width": 130},
        {"label": _("Payment Date"), "fieldname": "end_date", "fieldtype": "Date", "width": 110},
    ]


def get_data(filters):
    conditions = "WHERE ss.docstatus = 1"
    values = {}
    if filters and filters.get("start_date"):
        conditions += " AND ss.start_date >= %(start_date)s"
        values["start_date"] = filters["start_date"]
    if filters and filters.get("end_date"):
        conditions += " AND ss.end_date <= %(end_date)s"
        values["end_date"] = filters["end_date"]

    return frappe.db.sql(f"""
        SELECT ss.employee, emp.custom_wps_id as wps_id,
               ss.employee_name, emp.bank_ac_no as bank_account_no,
               ss.base, ss.gross_pay, ss.total_deduction, ss.net_pay, ss.end_date
        FROM `tabSalary Slip` ss
        LEFT JOIN `tabEmployee` emp ON emp.name = ss.employee
        {conditions}
        ORDER BY ss.employee
    """, values, as_dict=True)
