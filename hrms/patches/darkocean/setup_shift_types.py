import frappe


SHIFT_TYPES = [
    {
        "name": "Office - Qatar Standard",
        "start_time": "08:00:00",
        "end_time": "17:00:00",
        "description": "Standard Qatar office shift: Sunday–Thursday 08:00–17:00",
    },
    {
        "name": "Offshore Day",
        "start_time": "06:00:00",
        "end_time": "18:00:00",
        "description": "Offshore 12-hour day shift for survey vessel operations",
    },
    {
        "name": "Offshore Night",
        "start_time": "18:00:00",
        "end_time": "06:00:00",
        "description": "Offshore 12-hour night shift for survey vessel operations",
    },
    {
        "name": "Offshore Rotation (28/14)",
        "start_time": "06:00:00",
        "end_time": "18:00:00",
        "description": "28 days on / 14 days off offshore rotation",
    },
]


def execute():
    for shift in SHIFT_TYPES:
        if not frappe.db.exists("Shift Type", shift["name"]):
            frappe.get_doc({"doctype": "Shift Type", **shift}).insert(ignore_permissions=True)
    frappe.db.commit()
