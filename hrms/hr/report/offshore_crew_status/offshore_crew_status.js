frappe.query_reports["Offshore Crew Status"] = {
	filters: [
		{ fieldname: "vessel", label: __("Vessel"), fieldtype: "Link", options: "Vessel" },
		{ fieldname: "project", label: __("Project"), fieldtype: "Link", options: "Project" },
		{ fieldname: "offshore_only", label: __("Offshore Crew Only"), fieldtype: "Check" },
	],
};
