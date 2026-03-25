"""
Darkocean Employee DocType override — Qatar-specific validation
"""
import frappe
from frappe import _
from frappe.utils import date_diff, today


class DarkoceanEmployee:
    """Mixin for Employee with Darkocean customisations."""

    def validate(self):
        self.validate_qatar_id()
        self.validate_document_expiry_warnings()
        self.set_darkocean_employee_id()

    def validate_qatar_id(self):
        qid = getattr(self, "custom_qatar_id_number", None)
        if qid and (not qid.isdigit() or len(qid) != 11):
            frappe.throw(_("Qatar ID (QID) must be exactly 11 digits"))

    def validate_document_expiry_warnings(self):
        for field, label, threshold in [
            ("custom_passport_expiry", "Passport", 90),
            ("custom_visa_expiry", "Qatar Visa", 60),
        ]:
            expiry = getattr(self, field, None)
            if expiry:
                days = date_diff(expiry, today())
                if days <= 0:
                    frappe.msgprint(_(f"⚠️ {label} has EXPIRED on {expiry}"), alert=True, indicator="red")
                elif days <= threshold:
                    frappe.msgprint(_(f"⚠️ {label} expires in {days} days ({expiry})"), alert=True, indicator="orange")

    def set_darkocean_employee_id(self):
        if not getattr(self, "custom_darkocean_employee_id", None) and self.name:
            if self.name.startswith("DO-EMP-"):
                self.custom_darkocean_employee_id = self.name
