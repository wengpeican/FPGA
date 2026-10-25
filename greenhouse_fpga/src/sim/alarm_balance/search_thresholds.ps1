# Bit-exact software model of sim_sensor_data_gen (auto mode) + alarm_threshold_cmp.
# Simulates one full common period (LCM 36/100/96 s = 2400 s) and searches default
# thresholds/warning bands so that zone states are spread over green/yellow/red.
param([int]$Top = 8, [int]$Keep = 40, [switch]$NoResetDemo)
$code = @'
using System;
using System.Collections.Generic;
public static class AlarmModel {
  // Initial values per zone: temp, hum, light (from sim_sensor_data_gen reset).
  public static readonly int[,] Init = { {25,60,1000}, {28,55,2200}, {31,48,3000}, {22,68,1200} };
  static readonly int[] Lower = {18,30,800}, Upper = {36,80,3200}, Step = {1,1,50};
  public const int T = 2400;
  // trace[zone,type,t]
  public static int[,,] Trace() {
    var tr = new int[4,3,T];
    for (int z = 0; z < 4; z++) for (int k = 0; k < 3; k++) {
      int v = Init[z,k]; bool up = true;
      for (int t = 0; t < T; t++) {
        tr[z,k,t] = v;
        if (up) { if (v + Step[k] >= Upper[k]) { v = Upper[k]; up = false; } else v += Step[k]; }
        else    { if (v <= Lower[k] + Step[k]) { v = Lower[k]; up = true; } else v -= Step[k]; }
      }
    }
    return tr;
  }
  public static int Check(int v, int lo, int hi, int band) {
    if (lo > hi || v < lo || v > hi) return 2;
    if (v - lo <= band || hi - v <= band) return 1;
    return 0;
  }
  // states[zone,t] for one candidate; p = {tlo,thi,tband,hlo,hhi,hband,llo,lhi,lband}
  public static int[,] Zone(int[,,] tr, int[] p) {
    var s = new int[4,T];
    for (int z = 0; z < 4; z++) for (int t = 0; t < T; t++) {
      int r = 0;
      for (int k = 0; k < 3; k++) { int c = Check(tr[z,k,t], p[k*3], p[k*3+1], p[k*3+2]); if (c > r) r = c; }
      s[z,t] = r;
    }
    return s;
  }
  public static double[] Stats(int[,] s) {
    // [0..2] overall g/y/r fractions, [3] worst per-zone deviation, [4] longest red run (s), [5] min per-zone share of any colour
    double[] f = new double[3]; double worst = 0, minShare = 1; int longest = 0;
    for (int z = 0; z < 4; z++) {
      double[] zf = new double[3]; int run = 0;
      for (int t = 0; t < T; t++) { zf[s[z,t]]++; f[s[z,t]]++; run = s[z,t] == 2 ? run + 1 : 0; if (run > longest) longest = run; }
      for (int c = 0; c < 3; c++) { zf[c] /= T; worst = Math.Max(worst, Math.Abs(zf[c] - 1.0/3)); minShare = Math.Min(minShare, zf[c]); }
    }
    for (int c = 0; c < 3; c++) f[c] /= 4.0 * T;
    return new double[] { f[0], f[1], f[2], worst, longest, minShare };
  }
  static double Score(double[] st) {
    double d = 0; for (int c = 0; c < 3; c++) d += (st[c] - 1.0/3) * (st[c] - 1.0/3);
    return d + 0.5 * st[3] * st[3] + 0.0000002 * st[4] * st[4];
  }
  public static List<string> Search(int top, int keepN, bool resetDemo) {
    var tr = Trace();
    var temp = new List<int[]>(); var hum = new List<int[]>(); var light = new List<int[]>();
    // Low limit strictly inside the simulated range so both low and high alarms occur.
    for (int lo = 19; lo <= 24; lo++) for (int hi = 28; hi <= 35; hi++) for (int b = 1; b <= 3; b++) if (hi - lo > 2 * b + 2) temp.Add(new[]{lo,hi,b});
    for (int lo = 31; lo <= 45; lo++) for (int hi = 62; hi <= 79; hi++) for (int b = 2; b <= 8; b++) if (hi - lo > 2 * b + 2) hum.Add(new[]{lo,hi,b});
    for (int lo = 850; lo <= 1500; lo += 50) for (int hi = 2000; hi <= 3150; hi += 50) for (int b = 50; b <= 300; b += 50) if (hi - lo > 2 * b + 100) light.Add(new[]{lo,hi,b});
    // Stage 1: keep per-type candidates whose own state mix is near the per-parameter target.
    Func<List<int[]>, int, List<int[]>> prune = (list, k) => {
      var scored = new List<KeyValuePair<double,int[]>>();
      foreach (var c in list) {
        double[] f = new double[3];
        for (int z = 0; z < 4; z++) for (int t = 0; t < T; t++) f[Check(tr[z,k,t], c[0], c[1], c[2])]++;
        for (int i = 0; i < 3; i++) f[i] /= 4.0 * T;
        double d = Math.Pow(f[0] - 0.69, 2) + Math.Pow(f[1] - 0.18, 2) + Math.Pow(f[2] - 0.13, 2);
        scored.Add(new KeyValuePair<double,int[]>(d, c));
      }
      scored.Sort((a, b) => a.Key.CompareTo(b.Key));
      var keep = new List<int[]>(); for (int i = 0; i < Math.Min(keepN, scored.Count); i++) keep.Add(scored[i].Value);
      return keep;
    };
    var pt = prune(temp, 0); var ph = prune(hum, 1); var pl = prune(light, 2);
    var res = new List<KeyValuePair<double,string>>();
    foreach (var a in pt) foreach (var b in ph) foreach (var c in pl) {
      var p = new[]{a[0],a[1],a[2],b[0],b[1],b[2],c[0],c[1],c[2]};
      // Keep the reset demo: zone A green, zone C red (tb_osd relies on it).
      int A = 0, C = 0;
      for (int k = 0; k < 3; k++) { A = Math.Max(A, Check(Init[0,k], p[k*3], p[k*3+1], p[k*3+2])); C = Math.Max(C, Check(Init[2,k], p[k*3], p[k*3+1], p[k*3+2])); }
      if (resetDemo && (A != 0 || C != 2)) continue;
      var st = Stats(Zone(tr, p));
      res.Add(new KeyValuePair<double,string>(Score(st), Format(p, st)));
    }
    res.Sort((x, y) => x.Key.CompareTo(y.Key));
    var outp = new List<string>(); for (int i = 0; i < Math.Min(top, res.Count); i++) outp.Add(res[i].Value);
    return outp;
  }
  public static string Format(int[] p, double[] st) {
    return string.Format("T {0}-{1} b{2} | H {3}-{4} b{5} | L {6}-{7} b{8} => G {9:P1} Y {10:P1} R {11:P1} | zoneDev {12:P1} minShare {13:P1} longestRed {14}s",
      p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8], st[0],st[1],st[2],st[3],st[5],st[4]);
  }
  public static string Evaluate(int[] p) { return Format(p, Stats(Zone(Trace(), p))); }
}
'@
Add-Type -TypeDefinition $code -Language CSharp
"CURRENT: " + [AlarmModel]::Evaluate([int[]]@(20,30,2,40,70,2,500,2000,20))
[AlarmModel]::Search($Top, $Keep, -not $NoResetDemo)
