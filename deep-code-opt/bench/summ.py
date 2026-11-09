import json,sys,statistics as st
d=json.load(sys.stdin)
for k,v in d.items():
  w=v['wall'];m=st.median(w);mad=st.median([abs(x-m) for x in w]);kc=v['kcyc'];mk=st.median(kc);madk=st.median([abs(x-mk) for x in kc])
  print(f'{k:15} wall {m:9.3f}us MAD {100*mad/m:5.2f}% | kcyc {mk:9.0f} MAD {100*madk/max(mk,1):5.2f}%')
