import frappe


SALARY_COMPONENTS = [
    {"salary_component": "Basic Salary", "salary_component_abbr": "BS", "type": "Earning", "is_tax_applicable": 0},
    {"salary_component": "Housing Allowance", "salary_component_abbr": "HA", "type": "Earning", "is_tax_applicable": 0, "description": "25% of Basic Salary"},
    {"salary_component": "Transport Allowance", "salary_component_abbr": "TA", "type": "Earning", "is_tax_applicable": 0, "description": "10% of Basic Salary"},
    {"salary_component": "Offshore Field Allowance", "salary_component_abbr": "OFA", "type": "Earning", "is_tax_applicable": 0},
    {"salary_component": "Mobile Allowance", "salary_component_abbr": "MA", "type": "Earning", "is_tax_applicable": 0, "amount": 300, "description": "Fixed QAR 300/month"},
    {"salary_component": "EOSB Accrual", "salary_component_abbr": "EOSB", "type": "Earning", "is_tax_applicable": 0, "description": "Qatar Labour Law Article 54"},
    {"salary_component": "Overtime 1.25x", "salary_component_abbr": "OT125", "type": "Earning", "is_tax_applicable": 0, "description": "Qatar Labour Law Article 68"},
    {"salary_component": "Overtime 1.5x", "salary_component_abbr": "OT150", "type": "Earning", "is_tax_applicable": 0, "description": "Fridays and public holidays"},
    {"salary_component": "Advance Recovery", "salary_component_abbr": "AR", "type": "Deduction", "is_tax_applicable": 0},
    {"salary_component": "Absence Deduction", "salary_component_abbr": "AD", "type": "Deduction", "is_tax_applicable": 0},
]


def execute():
    """Setup Darkocean salary components — Qatar, no income tax"""
    for component in SALARY_COMPONENTS:
        if not frappe.db.exists("Salary Component", component["salary_component"]):
            frappe.get_doc({"doctype": "Salary Component", **component}).insert(ignore_permissions=True)
    frappe.db.commit()
