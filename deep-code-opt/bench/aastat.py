import json,sys,statistics as st
PRIMARY={"submit_spin":"wall","h2d64k":"wall","fence_block":"wall","alloc2m":"kcyc","hostreg1m":"kcyc","uvm_prefetch2m":"kcyc","nvenc1080p":"wall","ctx_create":"wall"}
def mad(x): m=st.median(x); return st.median([abs(v-m) for v in x])
loads=[json.load(open(f)) for f in sys.argv[1:]]
out={}
for sc,met in PRIMARY.items():
    per=[[r[sc][met] for r in L["runs"]] for L in loads]
    within=max(100*mad(p)/st.median(p) for p in per)
    meds=[st.median(p) for p in per]; between=100*mad(meds)/st.median(meds); spread=100*(max(meds)-min(meds))/st.median(meds)
    wall=[[r[sc]["wall"] for r in L["runs"]] for L in loads]
    out[sc]={"metric":met,"mad_within_pct":round(within,3),"mad_between_loads_pct":round(between,3),"spread_loads_pct":round(spread,3),"wall_mad_within_pct":round(max(100*mad(p)/st.median(p) for p in wall),3)}
    print(f"{sc:15} {met:4} within {within:6.3f}%  between-loads MAD {between:6.3f}% spread {spread:6.3f}%")
json.dump(out,open("results2/aa_summary.json","w"),indent=1)
