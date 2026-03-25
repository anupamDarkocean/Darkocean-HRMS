import frappe


def execute():
    """Set Darkocean employee naming series"""
    frappe.db.set_value("DocType", "Employee", "autoname", "DO-EMP-.####")
    frappe.db.commit()
