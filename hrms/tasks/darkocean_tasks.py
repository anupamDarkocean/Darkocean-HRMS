"""
Darkocean HRMS — Scheduled Tasks
"""
import frappe
from frappe.utils import today, add_days, date_diff


def check_passport_expiry():
    """Weekly: Alert when passport expires in 90, 30, or 7 days."""
    for days in [90, 30, 7]:
        target = add_days(today(), days)
        employees = frappe.db.sql("""
            SELECT name, employee_name, company_email,
                   custom_passport_expiry, custom_passport_number
            FROM `tabEmployee`
            WHERE custom_passport_expiry = %s AND status = 'Active'
        """, target, as_dict=True)
        for emp in employees:
            try:
                frappe.sendmail(
                    recipients=[emp.company_email],
                    subject=f"[Darkocean HR] Passport Expiry Alert — {days} days",
                    message=f"Dear {emp.employee_name},<br><br>"
                            f"Your passport (No: {emp.custom_passport_number}) expires on "
                            f"<strong>{emp.custom_passport_expiry}</strong> — in {days} days.<br><br>"
                            f"Please initiate renewal immediately.<br><br>"
                            f"Regards,<br>Darkocean HR Team",
                )
            except Exception:
                frappe.log_error(f"Passport expiry alert failed for {emp.name}")


def check_visa_expiry():
    """Weekly: Alert when Qatar visa expires in 60, 30, or 7 days."""
    for days in [60, 30, 7]:
        target = add_days(today(), days)
        employees = frappe.db.sql("""
            SELECT name, employee_name, company_email,
                   custom_visa_expiry, custom_visa_number
            FROM `tabEmployee`
            WHERE custom_visa_expiry = %s AND status = 'Active'
        """, target, as_dict=True)
        for emp in employees:
            try:
                frappe.sendmail(
                    recipients=[emp.company_email],
                    subject=f"[Darkocean HR] Visa Expiry Alert — {days} days",
                    message=f"Dear {emp.employee_name},<br><br>"
                            f"Your Qatar Residence Visa (No: {emp.custom_visa_number}) expires on "
                            f"<strong>{emp.custom_visa_expiry}</strong> — in {days} days.<br><br>"
                            f"Please contact HR immediately for visa renewal.<br><br>"
                            f"Regards,<br>Darkocean HR Team",
                )
            except Exception:
                frappe.log_error(f"Visa expiry alert failed for {emp.name}")


def monthly_payroll_reminder():
    """Daily check: send payroll reminder on the 25th of each month."""
    from frappe.utils import now_datetime
    if now_datetime().day != 25:
        return
    payroll_users = frappe.db.get_all("Has Role", filters={"role": "HR Manager"}, fields=["parent"])
    emails = list({u.parent for u in payroll_users if "@" in (u.parent or "")}) or ["hr@darkocean.ai"]
    frappe.sendmail(
        recipients=emails,
        subject="[Darkocean HR] Monthly Payroll Processing Reminder",
        message="Dear Payroll Team,<br><br>Please process the monthly payroll.<br><br>"
                "Ensure: attendance finalised, overtime calculated, WPS SIF file generated.<br><br>"
                "Regards,<br>Darkocean HRMS",
    )


def monthly_leave_balance_summary():
    """Daily check: email leave balances to all employees on the 1st of each month."""
    from frappe.utils import now_datetime
    if now_datetime().day != 1:
        return
    employees = frappe.db.get_all("Employee", filters={"status": "Active"}, fields=["name", "employee_name", "company_email"])
    for emp in employees:
        if not emp.company_email:
            continue
        try:
            balances = frappe.db.sql("""
                SELECT leave_type,
                       total_leaves_allocated - leaves_taken as balance
                FROM `tabLeave Allocation`
                WHERE employee = %s AND docstatus = 1 AND to_date >= %s
            """, (emp.name, today()), as_dict=True)
            if not balances:
                continue
            rows = "".join(
                f"<tr><td>{b.leave_type}</td><td><strong>{b.balance}</strong></td></tr>"
                for b in balances
            )
            frappe.sendmail(
                recipients=[emp.company_email],
                subject="[Darkocean HR] Monthly Leave Balance Summary",
                message=f"Dear {emp.employee_name},<br><br>Your leave balances:<br>"
                        f"<table border='1' cellpadding='5'><tr><th>Leave Type</th><th>Balance</th></tr>"
                        f"{rows}</table><br>Regards,<br>Darkocean HR Team",
            )
        except Exception:
            frappe.log_error(f"Leave balance summary failed for {emp.name}")
