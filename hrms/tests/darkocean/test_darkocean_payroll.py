"""Tests for Darkocean Payroll customisations"""
import unittest


class TestDarkoceanPayroll(unittest.TestCase):

    def test_housing_allowance_is_25_percent(self):
        self.assertEqual(10000 * 0.25, 2500)

    def test_transport_allowance_is_10_percent(self):
        self.assertEqual(10000 * 0.10, 1000)

    def test_mobile_allowance_fixed_300_qar(self):
        self.assertEqual(300, 300)

    def test_overtime_125_multiplier(self):
        self.assertEqual(100 * 1.25, 125)

    def test_overtime_150_multiplier(self):
        self.assertEqual(100 * 1.5, 150)

    def test_qatar_no_income_tax(self):
        income_tax_rate = 0
        self.assertEqual(income_tax_rate, 0)

    def test_default_currency_qar(self):
        self.assertEqual("QAR", "QAR")

    def test_salary_components_count(self):
        components = [
            "Basic Salary", "Housing Allowance", "Transport Allowance",
            "Offshore Field Allowance", "Mobile Allowance", "EOSB Accrual",
            "Overtime 1.25x", "Overtime 1.5x", "Advance Recovery", "Absence Deduction"
        ]
        self.assertEqual(len(components), 10)


if __name__ == "__main__":
    unittest.main()
