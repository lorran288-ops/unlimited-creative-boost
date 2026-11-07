"""Test actual pure MQL5 helpers/defaults, not MT5 compilation or backtest."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).with_name('Robo_Fenix_PontoD_Trendline_v5.3.mq5')


class PontoDRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = SOURCE.read_text()
        block = source.split('// BEGIN_TESTABLE_RULES\n')[1].split('// END_TESTABLE_RULES')[0]
        names = ['InpRiscoPorEntradaUSD', 'InpAlvoPorEntradaUSD', 'InpMaxEntradasDia']
        defaults = '\n'.join(re.search(r'^input (?:double|int)\s+' + name + r'\s*=\s*[^;]+;', source, re.M).group().replace('input ', 'const ') for name in names)
        cls.block = '#include <algorithm>\n#include <cmath>\n#include <cassert>\n#define MathMax std::max\n#define MathMin std::min\n#define MathFloor std::floor\n' + defaults + '\n' + block
        cls.temp = tempfile.TemporaryDirectory(prefix='pontod-tests-')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def check(self, code):
        root = Path(self.temp.name)
        (root / 'rules.cpp').write_text(self.block + '\nint main(){' + code + '}')
        subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(root / 'rules.cpp'), '-o', str(root / 'rules')], check=True, capture_output=True)
        subprocess.run([str(root / 'rules')], check=True, capture_output=True)

    def test_risk_500_independent_of_entry_count_and_balance(self):
        self.check('assert(InpRiscoPorEntradaUSD==500.0); assert(RiscoUSDRegra(true,InpRiscoPorEntradaUSD,100000.0,0.1)==500.0); assert(RiscoUSDRegra(true,InpRiscoPorEntradaUSD,93999.87,0.1)==500.0);')

    def test_target_1000_per_trade(self):
        self.check('assert(InpAlvoPorEntradaUSD==1000.0); assert(RiscoUSDRegra(true,InpAlvoPorEntradaUSD,100000.0,0.2)==1000.0);')

    def test_tenth_entry_allowed_eleventh_blocked(self):
        self.check('assert(InpMaxEntradasDia==10); assert(!LimiteEntradasRegra(9,InpMaxEntradasDia)); assert(LimiteEntradasRegra(10,InpMaxEntradasDia));')

    def test_shared_remaining_daily_risk(self):
        self.check('assert(OrcamentoRegra(0.0,500.0,500.0)==0.0); assert(OrcamentoRegra(-500.0,500.0,0.0)==0.0); assert(OrcamentoRegra(-100.0,500.0,0.0)==400.0); assert(OrcamentoRegra(1000.0,500.0,0.0)==1500.0);')

    def test_minimum_volume_never_exceeds_500(self):
        self.check('assert(VolumeRegra(500.0,60000.0,0.01,100.0,0.01)==0.0); double v=VolumeRegra(500.0,33000.0,0.01,100.0,0.01); assert(std::abs(v-0.01)<1e-9); assert(v*33000.0<=500.0);')

    def test_retry_window_prevents_late_signal(self):
        self.check('assert(JanelaRegra(1003,1000,120)); assert(JanelaRegra(1120,1000,120)); assert(!JanelaRegra(1121,1000,120)); assert(!JanelaRegra(999,1000,120)); assert(!JanelaRegra(1000,0,120));')


if __name__ == '__main__':
    unittest.main()