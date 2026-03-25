import frappe

DARKOCEAN_FOOTER = """
<div style="text-align:center;padding:10px;border-top:1px solid #0A1628;margin-top:20px;color:#1A3A5C;font-size:11px;">
  <strong style="color:#0A1628;">Darkocean AI &amp; Marine Technology</strong> | Doha, Qatar | www.darkocean.ai<br>
  <em>Powering the People Behind the Ocean</em>
</div>
"""


def execute():
    print_formats = frappe.db.get_all(
        "Print Format",
        filters={"module": ["in", ["HR", "Payroll"]]},
        fields=["name"],
    )
    for pf in print_formats:
        try:
            doc = frappe.get_doc("Print Format", pf.name)
            if doc.html and "darkocean" not in doc.html.lower():
                doc.html = (doc.html or "") + DARKOCEAN_FOOTER
                doc.save(ignore_permissions=True)
        except Exception:
            pass
    frappe.db.commit()
