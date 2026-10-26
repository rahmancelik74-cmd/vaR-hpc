"""Plot only exported reassessment values; no reference/native execution."""
import csv
import hashlib
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1]
PUBLIC=ROOT/'evidence/portfolio-precision-20261025-v1'


def main():
    with (PUBLIC/'reassessment.csv').open(newline='',encoding='ascii') as f:
        rows=list(csv.DictReader(f))
    fig,ax=plt.subplots(figsize=(10,5.2))
    plotted=[]
    for i,(name,alpha) in enumerate((('two-negative',.95),('two-negative',.99),('two-positive',.95),('two-positive',.99))):
        selected=[r for r in rows if r['fixture']==name and float(r['confidence'])==alpha]
        assert len(selected)==3
        r=selected[0]; center=float(r['numerical_var']); target=float(r['practical_target'])
        for j,(low,high,color,label) in enumerate((('old_lower','old_upper','#a5a5a5','Original 20M interval'),('lower','upper','#1565a0','Follow-up 80M interval'))):
            left=float(r[low])-center; right=float(r[high])-center
            ax.plot([left,right],[i+(j-.5)*.16]*2,color=color,linewidth=5,label=label if i==0 else None,solid_capstyle='butt')
        means=[]
        for r,marker,color in zip(selected,('o','s','^'),('#ce5c00','#587a20','#8b3fa1')):
            value=float(r['mean_var'])-center; means.append([r['config'],value])
            ax.scatter(value,i+.22,marker=marker,color=color,s=32,label=r['config']+' observed mean' if i==0 else None,zorder=4)
        assert abs(float(r['new_width'])-(float(r['upper'])-float(r['lower'])))<1e-12
        plotted.append(dict(fixture=name,confidence=alpha,center=center,target=target,
            old_relative_interval=[float(r['old_lower'])-center,float(r['old_upper'])-center],
            new_relative_interval=[float(r['lower'])-center,float(r['upper'])-center],relative_means=means))
    ax.axvspan(-target,target,color='#e5eedb',alpha=.5,label='Practical distance scale +/-0.22')
    ax.axvline(0,color='#333333',linewidth=.8,linestyle=':')
    ax.set_yticks(range(4),['Negative rho, 95%','Negative rho, 99%','Positive rho, 95%','Positive rho, 99%'])
    ax.invert_yaxis(); ax.set_xlim(-.25,.25)
    ax.set_xlabel('Loss difference from corroborating numerical VaR (USD)')
    ax.set_title('Two-asset reference precision: unchanged native observations')
    ax.grid(axis='x',alpha=.2)
    ax.legend(loc='upper center',bbox_to_anchor=(.5,-.2),ncol=3,fontsize=8,frameon=False)
    fig.text(.5,.015,'Studies have separate confidence families. Numerical center is not certified truth; decisions use full 80M intervals.',ha='center',fontsize=8)
    fig.subplots_adjust(left=.2,right=.98,top=.9,bottom=.3)
    fig.savefig(PUBLIC/'comparison.png',dpi=160)
    plt.close(fig)
    (PUBLIC/'figure-data.json').write_bytes((json.dumps(dict(
        csv_sha256=hashlib.sha256((PUBLIC/'reassessment.csv').read_bytes()).hexdigest(),
        data=plotted),indent=2)+'\n').encode('ascii'))


if __name__=='__main__':
    main()
