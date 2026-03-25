import frappe


EXPENSE_TYPES = [
    "Field & Offshore Operations",
    "Equipment & Consumables",
    "Flights & Air Travel",
    "Hotel & Accommodation",
    "Per Diem & Subsistence",
    "Visa & Government Fees",
    "Client Entertainment",
    "Training & Certification",
    "Marine Charter Costs",
    "Transport & Taxi",
]


def execute():
    for expense_type in EXPENSE_TYPES:
        if not frappe.db.exists("Expense Claim Type", expense_type):
            frappe.get_doc({
                "doctype": "Expense Claim Type",
                "expense_type": expense_type,
            }).insert(ignore_permissions=True)
    frappe.db.commit()
