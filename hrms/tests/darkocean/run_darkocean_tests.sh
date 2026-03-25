#!/bin/bash
# Run all Darkocean HRMS tests
# Usage: bash run_darkocean_tests.sh [site-name]
SITE=${1:-hrms.localhost}
echo "Running Darkocean HRMS Test Suite against site: $SITE"
echo "======================================================="

cd /home/frappe/frappe-bench

bench --site "$SITE" run-tests --module hrms.tests.darkocean.test_darkocean_employee
bench --site "$SITE" run-tests --module hrms.tests.darkocean.test_darkocean_payroll
bench --site "$SITE" run-tests --module hrms.tests.darkocean.test_darkocean_reports

echo "======================================================="
echo "Darkocean test suite complete."
