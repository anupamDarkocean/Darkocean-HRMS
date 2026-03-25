"""
EOSB Liability Report — Qatar Labour Law Article 54
< 5 years: 3 weeks basic/year | >= 5 years: 4 weeks basic/year
"""
import frappe
from frappe import _
from frappe.utils import today, date_diff, flt


def execute(filters=None):
    return get_columns(), get_data(filters)


def get_columns():
    return [
        {"label": _("Employee"), "fieldname": "employee", "fieldtype": "Link", "options": "Employee", "width": 120},
        {"label": _("Employee Name"), "fieldname": "employee_name", "fieldtype": "Data", "width": 150},
        {"label": _("Joining Date"), "fieldname": "date_of_joining", "fieldtype": "Date", "width": 110},
        {"label": _("Years of Service"), "fieldname": "years_of_service", "fieldtype": "Float", "width": 120},
        {"label": _("Basic Salary (QAR)"), "fieldname": "basic_salary", "fieldtype": "Currency", "width": 130},
        {"label": _("EOSB Accrued (QAR)"), "fieldname": "eosb_accrued", "fieldtype": "Currency", "width": 140},
        {"label": _("EOSB Rate"), "fieldname": "eosb_rate", "fieldtype": "Data", "width": 110},
        {"label": _("Department"), "fieldname": "department", "fieldtype": "Data", "width": 130},
        {"label": _("Grade"), "fieldname": "custom_employee_grade", "fieldtype": "Data", "width": 120},
    ]


def get_data(filters):
    conditions = ""
    if filters and filters.get("department"):
        conditions = f" AND e.department = '{filters['department']}'"

    employees = frappe.db.sql(f"""
        SELECT e.name as employee, e.employee_name, e.date_of_joining,
               e.department, e.custom_employee_grade
        FROM `tabEmployee` e
        WHERE e.status = 'Active' {conditions}
        ORDER BY e.date_of_joining
    """, as_dict=True)

    data = []
    for emp in employees:
        if not emp.date_of_joining:
            continue
        years = date_diff(today(), emp.date_of_joining) / 365.0
        basic_row = frappe.db.sql("""
            SELECT sd.amount FROM `tabSalary Detail` sd
            JOIN `tabSalary Slip` ss ON ss.name = sd.parent
            WHERE ss.employee = %s AND sd.salary_component = 'Basic Salary'
            AND ss.docstatus = 1 ORDER BY ss.end_date DESC LIMIT 1
        """, emp.employee)
        basic = basic_row[0][0] if basic_row else 0
        weekly = basic / 4.0

        if years < 1:
            eosb, rate = 0, "< 1 year (no EOSB)"
        elif years < 5:
            eosb, rate = weekly * 3 * years, "3 weeks/year"
        else:
            eosb, rate = weekly * 4 * years, "4 weeks/year"

        emp.years_of_service = round(years, 2)
        emp.basic_salary = basic
        emp.eosb_accrued = flt(eosb, 2)
        emp.eosb_rate = rate
        data.append(emp)

    return data
