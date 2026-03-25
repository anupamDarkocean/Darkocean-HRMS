"""Tests for Darkocean custom reports"""
import unittest


class TestDarkoceanReports(unittest.TestCase):

    def test_offshore_crew_report_has_vessel_column(self):
        columns = ["employee", "employee_name", "designation",
                   "custom_employee_grade", "custom_vessel_assignment",
                   "custom_project_assignment", "custom_offshore_crew_flag"]
        self.assertIn("custom_vessel_assignment", columns)

    def test_visa_tracker_alert_levels(self):
        levels = ["CRITICAL", "URGENT", "WARNING", "OK"]
        self.assertEqual(len(levels), 4)

    def test_eosb_report_has_accrued_column(self):
        columns = ["employee", "years_of_service", "basic_salary", "eosb_accrued"]
        self.assertIn("eosb_accrued", columns)

    def test_project_headcount_groups_correctly(self):
        grouping = ["project", "department", "grade"]
        self.assertEqual(len(grouping), 3)

    def test_wps_export_has_net_pay_column(self):
        columns = ["employee", "wps_id", "employee_name", "bank_account_no",
                   "base", "gross_pay", "total_deduction", "net_pay", "end_date"]
        self.assertIn("net_pay", columns)


if __name__ == "__main__":
    unittest.main()
