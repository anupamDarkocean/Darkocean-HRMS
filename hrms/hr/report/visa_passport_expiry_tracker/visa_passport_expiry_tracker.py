import frappe
from frappe import _
from frappe.utils import today, date_diff


def execute(filters=None):
    return get_columns(), get_data(filters)


def get_columns():
    return [
        {"label": _("Employee"), "fieldname": "employee", "fieldtype": "Link", "options": "Employee", "width": 120},
        {"label": _("Employee Name"), "fieldname": "employee_name", "fieldtype": "Data", "width": 150},
        {"label": _("QID"), "fieldname": "custom_qatar_id_number", "fieldtype": "Data", "width": 120},
        {"label": _("Passport No"), "fieldname": "custom_passport_number", "fieldtype": "Data", "width": 120},
        {"label": _("Passport Expiry"), "fieldname": "custom_passport_expiry", "fieldtype": "Date", "width": 120},
        {"label": _("Passport Days Left"), "fieldname": "passport_days_left", "fieldtype": "Int", "width": 130},
        {"label": _("Visa No"), "fieldname": "custom_visa_number", "fieldtype": "Data", "width": 120},
        {"label": _("Visa Expiry"), "fieldname": "custom_visa_expiry", "fieldtype": "Date", "width": 120},
        {"label": _("Visa Days Left"), "fieldname": "visa_days_left", "fieldtype": "Int", "width": 110},
        {"label": _("Alert Level"), "fieldname": "alert_level", "fieldtype": "Data", "width": 100},
    ]


def get_data(filters):
    threshold = (filters or {}).get("days_threshold") or 90
    employees = frappe.db.sql("""
        SELECT name as employee, employee_name, custom_qatar_id_number,
               custom_passport_number, custom_passport_expiry,
               custom_visa_number, custom_visa_expiry
        FROM `tabEmployee`
        WHERE status = 'Active'
        AND (custom_passport_expiry IS NOT NULL OR custom_visa_expiry IS NOT NULL)
        ORDER BY custom_passport_expiry ASC
    """, as_dict=True)

    data = []
    t = today()
    for emp in employees:
        passport_days = date_diff(emp.custom_passport_expiry, t) if emp.custom_passport_expiry else None
        visa_days = date_diff(emp.custom_visa_expiry, t) if emp.custom_visa_expiry else None
        min_days = min([d for d in [passport_days, visa_days] if d is not None], default=999)

        if min_days > threshold:
            continue

        if min_days <= 7:
            alert = "CRITICAL"
        elif min_days <= 30:
            alert = "URGENT"
        elif min_days <= 90:
            alert = "WARNING"
        else:
            alert = "OK"

        emp.passport_days_left = passport_days
        emp.visa_days_left = visa_days
        emp.alert_level = alert
        data.append(emp)

    return data
