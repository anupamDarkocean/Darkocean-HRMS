import frappe


def execute():
    """Install Darkocean leave types and Qatar public holiday list"""
    leave_types = [
        {"name": "Annual Leave", "max_leaves_allowed": 30, "is_carry_forward": 1, "allow_encashment": 1},
        {"name": "Sick Leave", "max_leaves_allowed": 84, "is_lwp": 0},
        {"name": "Hajj Leave", "max_leaves_allowed": 21, "max_continuous_days_allowed": 21},
        {"name": "Maternity Leave", "max_leaves_allowed": 50},
        {"name": "Emergency Leave", "max_leaves_allowed": 3},
        {"name": "Unpaid Leave", "is_lwp": 1},
    ]
    for lt in leave_types:
        if not frappe.db.exists("Leave Type", lt["name"]):
            frappe.get_doc({"doctype": "Leave Type", **lt}).insert(ignore_permissions=True)

    if not frappe.db.exists("Holiday List", "Qatar Public Holidays 2025"):
        frappe.get_doc({
            "doctype": "Holiday List",
            "name": "Qatar Public Holidays 2025",
            "country": "Qatar",
            "weekly_off": "Friday",
            "holidays": [
                {"holiday_date": "2025-01-01", "description": "New Year's Day"},
                {"holiday_date": "2025-02-10", "description": "National Sports Day"},
                {"holiday_date": "2025-03-30", "description": "Eid Al Fitr Day 1"},
                {"holiday_date": "2025-03-31", "description": "Eid Al Fitr Day 2"},
                {"holiday_date": "2025-04-01", "description": "Eid Al Fitr Day 3"},
                {"holiday_date": "2025-06-06", "description": "Eid Al Adha Day 1"},
                {"holiday_date": "2025-06-07", "description": "Eid Al Adha Day 2"},
                {"holiday_date": "2025-06-08", "description": "Eid Al Adha Day 3"},
                {"holiday_date": "2025-06-27", "description": "Islamic New Year"},
                {"holiday_date": "2025-09-05", "description": "Prophet's Birthday"},
                {"holiday_date": "2025-12-18", "description": "Qatar National Day"},
            ]
        }).insert(ignore_permissions=True)

    frappe.db.commit()
