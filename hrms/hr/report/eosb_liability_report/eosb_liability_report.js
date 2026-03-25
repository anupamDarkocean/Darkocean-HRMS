frappe.query_reports["EOSB Liability Report"] = {
	filters: [
		{ fieldname: "department", label: __("Department"), fieldtype: "Link", options: "Department" },
	],
};
