import frappe


DESIGNATIONS = [
    "Marine Surveyor", "Hydrographic Engineer", "Geotechnical Engineer",
    "Offshore Survey Technician", "Software Engineer", "Senior Software Engineer",
    "Operations Manager", "Survey Operations Lead", "Business Development Manager",
    "Finance Officer", "Finance Manager", "HR Officer", "IT Specialist",
    "Project Manager", "Drone Operator", "Vessel Master", "Deck Officer",
    "Director of Engineering", "Director of Operations", "CEO",
]

DEPARTMENTS = [
    "Engineering", "Surveying Operations", "Business Development",
    "Finance & Admin", "IT & Software", "Marine Operations", "Human Resources",
]


def execute():
    company = (
        frappe.db.get_single_value("Global Defaults", "default_company")
        or "Darkocean AI & Marine Technology"
    )
    for d in DESIGNATIONS:
        if not frappe.db.exists("Designation", d):
            frappe.get_doc({"doctype": "Designation", "designation_name": d}).insert(ignore_permissions=True)
    for dept in DEPARTMENTS:
        if not frappe.db.exists("Department", dept):
            frappe.get_doc({"doctype": "Department", "department_name": dept, "company": company}).insert(ignore_permissions=True)
    frappe.db.commit()
