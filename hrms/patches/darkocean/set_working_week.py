import frappe


def execute():
    """Configure Qatar working week: Sunday–Thursday, 9 hours/day"""
    hr_settings = frappe.get_doc("HR Settings")
    hr_settings.standard_working_hours = 9
    hr_settings.save(ignore_permissions=True)
    frappe.db.commit()
