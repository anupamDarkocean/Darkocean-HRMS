frappe.query_reports["Visa & Passport Expiry Tracker"] = {
	filters: [
		{ fieldname: "days_threshold", label: __("Show expiring within (days)"), fieldtype: "Int", default: 90 },
	],
};
