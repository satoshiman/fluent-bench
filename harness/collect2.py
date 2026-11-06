import json, os, glob
def tok(f):
    d=json.load(open(f)); fm=d.get('final_metrics',{})
    return fm.get('total_prompt_tokens',0), fm.get('total_completion_tokens',0), fm.get('total_cached_tokens',0)
rows=[]
def add(task, arm, d, files):
    pt=ct=ca=0
    for f in files:
        if not os.path.exists(f): return
        a,b,c=tok(f); pt+=a; ct+=b; ca+=c
    try: wall=int(open(d+'/.end_time').read())-int(open(d+'/.start_time').read())
    except: wall='?'
    rows.append((task,arm,wall,pt,ct,ca))
for t in ['T1','T2','T3','T4','T5','T6']:
    add(t,'ad-hoc',f'runs/{t}/ad-hoc',[f'runs/{t}/ad-hoc/transcript.json'])
    add(t,'doc-split',f'runs/{t}/doc-centric',[f'runs/{t}/doc-centric/transcript-{p}.json' for p in ['plan','review','impl']])
for i in [1,2,3]:
    add(f'C{i}','doc-split','runs/chain/work',[f'runs/chain/work/transcript-{p}.json' for p in ['plan','review','impl']])
for v in ['V1','V2','V3']:
    add(v,'ad-hoc-vague',f'runs/{v}/ad-hoc-vague',[f'runs/{v}/ad-hoc-vague/transcript.json'])
    add(v,'doc-vague',f'runs/{v}/doc-centric-vague',[f'runs/{v}/doc-centric-vague/transcript-{p}.json' for p in ['plan','review','impl']])
w=open('results.csv','w')
w.write('task,arm,wall_s,prompt_tok,completion_tok,cached_tok\n')
for r in rows: w.write(','.join(str(x) for x in r)+'\n')
w.close()
print(f"{len(rows)} rows -> results.csv")
