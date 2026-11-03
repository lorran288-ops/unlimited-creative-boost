"""Compile only the pure rule block extracted from the delivered MQL5 source.
This does NOT compile MQL5 or simulate broker execution.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest
SOURCE = Path(__file__).with_name('Robo_Fenix_Confluencia_v1.0.mq5')

class TradingRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='fenix-rules-')
        source = SOURCE.read_text()
        block = source.split('// BEGIN_TESTABLE_RULES\n')[1].split('// END_TESTABLE_RULES')[0]
        cls.block = '#include <cmath>\n#include <algorithm>\n#include <cassert>\nusing std::floor;\n#define MathMax std::max\n#define MathMin std::min\n#define MathFloor std::floor\n' + block
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def check(self, assertion):
        p = Path(self.temp.name)
        (p/'rules.cpp').write_text(self.block + '\nint main(){' + assertion + '}\n')
        subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(p/'rules.cpp'), '-o', str(p/'rules')], check=True, capture_output=True)
        subprocess.run([str(p/'rules')], check=True, capture_output=True)
    def test_loss_lock_exact_500(self):
        self.check('assert(DailyDecision(-500.0,500.0,1000.0)==-1); assert(DailyDecision(-499.99,500.0,1000.0)==0); assert(DailyDecision(-501.0,500.0,1000.0)==-1);')
    def test_profit_lock_exact_1000(self):
        self.check('assert(DailyDecision(1000.0,500.0,1000.0)==1); assert(DailyDecision(999.99,500.0,1000.0)==0);')
    def test_shared_exposure_budget(self):
        self.check('assert(AvailableRisk(-100.0,500.0,300.0)==100.0); assert(AvailableRisk(-490.0,500.0,20.0)==0.0);')
    def test_do_not_upsize_minimum_lot(self):
        self.check('assert(NormalizeRiskVolume(0.009,0.01,5.0,0.01)==0.0); assert(std::abs(NormalizeRiskVolume(0.019,0.01,5.0,0.01)-0.01)<1e-9);')
    def test_next_business_day(self):
        self.check('assert(DaysUntilBusinessDay(5)==3); assert(DaysUntilBusinessDay(6)==2); assert(DaysUntilBusinessDay(1)==1);')

if __name__ == '__main__':
    unittest.main()
