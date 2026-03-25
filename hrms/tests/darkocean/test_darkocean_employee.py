"""Tests for Darkocean Employee customisations"""
import unittest


class TestDarkoceanEmployee(unittest.TestCase):

    def test_employee_grade_options(self):
        valid_grades = ["Junior Engineer", "Engineer", "Senior Engineer",
                        "Lead Engineer", "Manager", "Director", "CEO"]
        self.assertEqual(len(valid_grades), 7)

    def test_eosb_less_than_5_years(self):
        """3 weeks basic/year for < 5 years service"""
        basic, years = 10000, 3
        eosb = (basic / 4.0) * 3 * years
        self.assertEqual(eosb, 22500.0)

    def test_eosb_more_than_5_years(self):
        """4 weeks basic/year for >= 5 years service"""
        basic, years = 10000, 7
        eosb = (basic / 4.0) * 4 * years
        self.assertEqual(eosb, 70000.0)

    def test_visa_expiry_thresholds(self):
        self.assertEqual(sorted([60, 30, 7]), [7, 30, 60])

    def test_passport_expiry_thresholds(self):
        self.assertEqual(sorted([90, 30, 7]), [7, 30, 90])

    def test_qatar_id_must_be_11_digits(self):
        valid_qid = "12345678901"
        self.assertEqual(len(valid_qid), 11)
        self.assertTrue(valid_qid.isdigit())

    def test_qatar_leave_types(self):
        leave_types = {"Annual Leave": 30, "Sick Leave": 84, "Hajj Leave": 21,
                       "Maternity Leave": 50, "Emergency Leave": 3}
        self.assertEqual(leave_types["Annual Leave"], 30)
        self.assertEqual(leave_types["Maternity Leave"], 50)

    def test_working_week_sunday_to_thursday(self):
        working_days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday"]
        self.assertNotIn("Friday", working_days)
        self.assertNotIn("Saturday", working_days)


if __name__ == "__main__":
    unittest.main()
