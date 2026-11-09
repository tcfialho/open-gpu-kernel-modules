import subprocess, bisect, sys, re
base=int(sys.argv[1],16)
out = subprocess.run(["nm","-n","mods/asis/nvidia.ko"],capture_output=True,text=True).stdout.splitlines()
syms=[(int(l.split()[0],16),l.split()[2]) for l in out if len(l.split())==3 and l.split()[1] in "tTwW"]
A=[s[0] for s in syms]
def res(m):
    a=int(m.group(0),16)-base; i=bisect.bisect_right(A,a)-1
    return f"{syms[i][1]}" if i>=0 and 0<=a<0x400000 else m.group(0)
for scen in sys.argv[2:]:
    txt=subprocess.run(["perf","report","-i",f"prof2/{scen}.data","--no-children","--sort","sym","--stdio","-q","--percent-limit","20","-g","caller,0.5,callee,function,percent","--max-stack","9"],capture_output=True,text=True).stdout
    print(f"=== {scen}")
    for l in txt.splitlines()[:26]: print(re.sub(r"0xffffffffc[0-9a-f]{7}", res, l)[:140])
