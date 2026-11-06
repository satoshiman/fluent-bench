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
    if t == 'T2':
        # worktree run contaminated (repo/AGENTS.md injected as always-on rule
        # via node_modules symlink); canonical run is the isolated clone
        add(t,'ad-hoc','runs-isolated/T2-ad-hoc',['runs-isolated/T2-ad-hoc/transcript.json'])
    else:
        add(t,'ad-hoc',f'runs/{t}/ad-hoc',[f'runs/{t}/ad-hoc/transcript.json'])
    add(t,'doc-split',f'runs/{t}/doc-centric',[f'runs/{t}/doc-centric/transcript-{p}.json' for p in ['plan','review','impl']])
for i in [1,2,3]:
    add(f'C{i}','doc-split','runs/chain/work',[f'runs/chain/work/transcript-{p}.json' for p in ['plan','review','impl']])
# C1/C2 transcripts were overwritten by C3 in the shared chain worktree; values
# below were recovered from sessions.db (see notes/metrics-log.md incidents)
for i,r in enumerate(rows):
    if r[0]=='C1': rows[i]=('C1','doc-split',614,3016310,42089,'')
    if r[0]=='C2': rows[i]=('C2','doc-split',623,3152689,48216,'')
    if r[0]=='C3': rows[i]=('C3','doc-split',920,3374439,55791,3165984)
for v in ['V1','V2','V3']:
    add(v,'ad-hoc-vague',f'runs/{v}/ad-hoc-vague',[f'runs/{v}/ad-hoc-vague/transcript.json'])
    add(v,'doc-vague',f'runs/{v}/doc-centric-vague',[f'runs/{v}/doc-centric-vague/transcript-{p}.json' for p in ['plan','review','impl']])
for t in ['T2','T3','T4']:
    add(t,'agentsmd',f'runs-isolated/{t}-agentsmd',[f'runs-isolated/{t}-agentsmd/transcript.json'])
w=open('results.csv','w')
w.write('task,arm,wall_s,prompt_tok,completion_tok,cached_tok\n')
for r in rows: w.write(','.join(str(x) for x in r)+'\n')
w.close()
print(f"{len(rows)} rows -> results.csv")
