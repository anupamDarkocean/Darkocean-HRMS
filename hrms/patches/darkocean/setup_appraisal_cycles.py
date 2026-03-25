import frappe


def execute():
    """Create Darkocean appraisal cycles: Annual Dec + Mid-year June"""
    cycles = [
        {"cycle_name": "Annual Appraisal 2025", "start_date": "2025-12-01", "end_date": "2025-12-31"},
        {"cycle_name": "Mid-Year Check-in 2025", "start_date": "2025-06-01", "end_date": "2025-06-30"},
    ]
    for cycle in cycles:
        if not frappe.db.exists("Appraisal Cycle", cycle["cycle_name"]):
            try:
                frappe.get_doc({"doctype": "Appraisal Cycle", **cycle}).insert(ignore_permissions=True)
            except Exception:
                pass
    frappe.db.commit()
