import frappe


TEMPLATES = [
    {
        "template_title": "Engineering KRA Template",
        "goals": [
            {"kra": "Technical Accuracy", "per_weightage": 30},
            {"kra": "Project Delivery", "per_weightage": 25},
            {"kra": "Health & Safety Compliance", "per_weightage": 20},
            {"kra": "Innovation & Problem Solving", "per_weightage": 15},
            {"kra": "Team Collaboration", "per_weightage": 10},
        ],
    },
    {
        "template_title": "Business Development KRA Template",
        "goals": [
            {"kra": "Proposal Win Rate", "per_weightage": 35},
            {"kra": "Revenue Target Achievement", "per_weightage": 30},
            {"kra": "Client Relationship Management", "per_weightage": 20},
            {"kra": "Pipeline Development", "per_weightage": 15},
        ],
    },
    {
        "template_title": "Survey Operations KRA Template",
        "goals": [
            {"kra": "Survey Mission Success Rate", "per_weightage": 35},
            {"kra": "Equipment Uptime", "per_weightage": 25},
            {"kra": "Data Quality", "per_weightage": 20},
            {"kra": "Team Leadership", "per_weightage": 20},
        ],
    },
    {
        "template_title": "Finance & Admin KRA Template",
        "goals": [
            {"kra": "Reporting Timeliness", "per_weightage": 30},
            {"kra": "Compliance & Audit", "per_weightage": 30},
            {"kra": "Cost Control", "per_weightage": 25},
            {"kra": "Process Improvement", "per_weightage": 15},
        ],
    },
]


def execute():
    for tmpl in TEMPLATES:
        if not frappe.db.exists("Appraisal Template", tmpl["template_title"]):
            frappe.get_doc({"doctype": "Appraisal Template", **tmpl}).insert(ignore_permissions=True)
    frappe.db.commit()
