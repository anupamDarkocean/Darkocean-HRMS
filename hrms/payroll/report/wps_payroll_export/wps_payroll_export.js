frappe.query_reports["WPS Payroll Export"] = {
	filters: [
		{ fieldname: "start_date", label: __("Start Date"), fieldtype: "Date", reqd: 1 },
		{ fieldname: "end_date", label: __("End Date"), fieldtype: "Date", reqd: 1 },
	],
};
