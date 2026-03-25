"""
Qatar EOSB (End of Service Benefit) Calculator
Per Qatar Labour Law Article 54:
  < 5 years service: 3 weeks basic salary per year
  >= 5 years service: 4 weeks basic salary per year
"""
import frappe
from frappe.utils import date_diff, flt


def calculate_eosb(employee, termination_date):
    emp = frappe.get_doc("Employee", employee)
    if not emp.date_of_joining:
        return 0

    total_days = date_diff(termination_date, emp.date_of_joining)
    years = total_days / 365.0
    basic_salary = get_basic_salary(employee)
    weekly = basic_salary / 4.0

    if years < 1:
        return 0
    elif years < 5:
        return flt(weekly * 3 * years, 2)
    else:
        return flt(weekly * 4 * years, 2)


def get_basic_salary(employee):
    result = frappe.db.sql("""
        SELECT sd.amount
        FROM `tabSalary Detail` sd
        JOIN `tabSalary Slip` ss ON ss.name = sd.parent
        WHERE ss.employee = %s
          AND sd.salary_component = 'Basic Salary'
          AND ss.docstatus = 1
        ORDER BY ss.end_date DESC LIMIT 1
    """, employee)
    return result[0][0] if result else 0
