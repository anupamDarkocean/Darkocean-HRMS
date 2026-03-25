"""
Darkocean HRMS — Custom API Endpoints
"""
import frappe
from frappe import _
from frappe.utils import today, date_diff, flt


@frappe.whitelist()
def get_employee_dashboard(employee=None):
    """Returns dashboard summary for an employee (used by mobile app)."""
    if not employee:
        employee = frappe.session.user
    emp = frappe.db.get_value(
        "Employee",
        {"user_id": employee},
        ["name", "employee_name", "department", "designation",
         "custom_employee_grade", "custom_vessel_assignment",
         "custom_project_assignment", "custom_offshore_crew_flag",
         "custom_passport_expiry", "custom_visa_expiry",
         "custom_subsidiary", "image"],
        as_dict=True,
    )
    if not emp:
        frappe.throw(_("Employee not found for user {0}").format(employee))

    leave_balance = frappe.db.sql("""
        SELECT leave_type, total_leaves_allocated - leaves_taken as balance
        FROM `tabLeave Allocation`
        WHERE employee = %s AND docstatus = 1 AND to_date >= %s
        ORDER BY leave_type
    """, (emp.name, today()), as_dict=True)

    alerts = []
    t = today()
    if emp.custom_passport_expiry:
        days = date_diff(emp.custom_passport_expiry, t)
        if days <= 90:
            alerts.append({"type": "passport", "days": days,
                           "level": "critical" if days <= 7 else "warning" if days <= 30 else "info"})
    if emp.custom_visa_expiry:
        days = date_diff(emp.custom_visa_expiry, t)
        if days <= 60:
            alerts.append({"type": "visa", "days": days,
                           "level": "critical" if days <= 7 else "warning" if days <= 30 else "info"})

    return {"employee": emp, "leave_balance": leave_balance, "alerts": alerts}


@frappe.whitelist()
def get_offshore_crew_status(vessel=None, project=None):
    """Returns offshore crew roster for ops team."""
    conditions = "WHERE e.status = 'Active'"
    values = {}
    if vessel:
        conditions += " AND e.custom_vessel_assignment = %(vessel)s"
        values["vessel"] = vessel
    if project:
        conditions += " AND e.custom_project_assignment = %(project)s"
        values["project"] = project
    return frappe.db.sql(f"""
        SELECT e.name, e.employee_name, e.designation,
               e.custom_employee_grade as grade,
               e.custom_vessel_assignment as vessel,
               e.custom_project_assignment as project,
               e.custom_offshore_crew_flag as is_offshore
        FROM `tabEmployee` e {conditions}
        ORDER BY e.custom_vessel_assignment, e.employee_name
    """, values, as_dict=True)


@frappe.whitelist()
def calculate_eosb(employee, termination_date=None):
    """Calculate EOSB per Qatar Labour Law Article 54."""
    frappe.only_for(["HR Manager", "Finance Manager"])
    if not termination_date:
        termination_date = today()
    emp = frappe.db.get_value("Employee", employee,
        ["date_of_joining", "employee_name"], as_dict=True)
    if not emp or not emp.date_of_joining:
        return {"eosb_qar": 0, "error": "Joining date not set"}
    years = date_diff(termination_date, emp.date_of_joining) / 365.0
    basic_row = frappe.db.sql("""
        SELECT sd.amount FROM `tabSalary Detail` sd
        JOIN `tabSalary Slip` ss ON ss.name = sd.parent
        WHERE ss.employee = %s AND sd.salary_component = 'Basic Salary'
        AND ss.docstatus = 1 ORDER BY ss.end_date DESC LIMIT 1
    """, employee)
    basic = basic_row[0][0] if basic_row else 0
    weekly = basic / 4.0
    if years < 1:
        eosb, rate = 0, "No EOSB (< 1 year)"
    elif years < 5:
        eosb, rate = weekly * 3 * years, "3 weeks/year"
    else:
        eosb, rate = weekly * 4 * years, "4 weeks/year"
    return {
        "employee": employee,
        "employee_name": emp.employee_name,
        "years_of_service": round(years, 2),
        "basic_salary_qar": basic,
        "eosb_qar": flt(eosb, 2),
        "eosb_rate": rate,
        "legal_basis": "Qatar Labour Law Article 54",
    }
