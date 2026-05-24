import React, { useState, useEffect } from 'react';

const EXAMPLES = [
  {
    name: "Knee Rehab",
    brief: { goals: "Post-injury rehab", avoid: "Squats, running", equipment: "Bands" },
    plan: { title: "Knee Rehab W1", progression: "Increase band tension 5% weekly", sessions: [{ name: "Day 1", moves: ["Glute Bridge 3x12", "Hamstring Curl 3x15"] }] }
  },
  {
    name: "Hypertrophy Push (Failed)",
    brief: { goals: "Shoulder strength", avoid: "Barbell bench press", equipment: "Gym" },
    plan: { title: "Push Intensity", progression: "None", sessions: [{ name: "Day 1", moves: ["Barbell Bench Press 4x8"] }] }
  }
];

export default function App() {
  const [selectedEx, setSelectedEx] = useState(0);
  const [brief, setBrief] = useState(EXAMPLES[0].brief);
  const [plan, setPlan] = useState(EXAMPLES[0].plan);
  const [scores, setScores] = useState({ constraints: 8, progression: 7, safety: 9, fit: 8 });
  const [comments, setComments] = useState("Avoids forbidden movements well.");
  const [checks, setChecks] = useState([]);

  useEffect(() => {
    const list = [];
    const planStr = JSON.stringify(plan).toLowerCase();
    const avoided = (brief.avoid || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
    
    avoided.forEach(item => {
      const failed = planStr.includes(item);
      list.push({ pass: !failed, text: failed ? `Violated: contains "${item}"` : `Passed: avoided "${item}"` });
    });

    const hasProg = plan.progression && plan.progression.length > 5 && plan.progression !== "None";
    list.push({ pass: !!hasProg, text: hasProg ? "Progression rule specified" : "No progression rule found" });

    setChecks(list);
  }, [brief, plan]);

  const avg = Math.round(((scores.constraints + scores.progression + scores.safety + scores.fit) / 4) * 10) / 10;

  const exportJSON = () => {
    const data = { brief, plan, evaluation: { scores, average: avg, comments, checks } };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `trai-eval-${Date.now()}.json`;
    link.click();
  };

  return (
    <div className="max-w-6xl mx-auto p-4 md:p-8">
      <header className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 pb-4 border-b border-slate-800 gap-4">
        <div>
          <h1 className="text-2xl font-extrabold text-white flex items-center gap-2">
            <span className="text-emerald-500">Trai</span> Eval Harness
          </h1>
          <p className="text-sm text-slate-400">Validate AI-generated workouts against plan briefs</p>
        </div>
        <div className="flex gap-2">
          {EXAMPLES.map((ex, idx) => (
            <button
              key={idx}
              onClick={() => { setSelectedEx(idx); setBrief(ex.brief); setPlan(ex.plan); }}
              className={`px-3 py-1.5 text-xs font-semibold rounded ${selectedEx === idx ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
            >
              Load {ex.name}
            </button>
          ))}
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="space-y-6">
          <div className="bg-slate-800/80 p-5 rounded-xl border border-slate-700">
            <h2 className="text-md font-bold text-emerald-400 mb-4">1. Workout Brief Inputs</h2>
            <div className="space-y-3">
              <div>
                <label className="text-xs font-bold text-slate-400 uppercase">Goals</label>
                <input type="text" value={brief.goals} onChange={(e) => setBrief({ ...brief, goals: e.target.value })} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-sm text-white" />
              </div>
              <div>
                <label className="text-xs font-bold text-slate-400 uppercase">Avoid / Contraindications</label>
                <input type="text" value={brief.avoid} onChange={(e) => setBrief({ ...brief, avoid: e.target.value })} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-sm text-white" />
              </div>
              <div>
                <label className="text-xs font-bold text-slate-400 uppercase">Allowed Equipment</label>
                <input type="text" value={brief.equipment} onChange={(e) => setBrief({ ...brief, equipment: e.target.value })} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-sm text-white" />
              </div>
            </div>
          </div>

          <div className="bg-slate-800/80 p-5 rounded-xl border border-slate-700">
            <h2 className="text-md font-bold text-emerald-400 mb-4">2. Generated Plan Output</h2>
            <div className="space-y-3">
              <div>
                <label className="text-xs font-bold text-slate-400 uppercase">Plan Title</label>
                <input type="text" value={plan.title} onChange={(e) => setPlan({ ...plan, title: e.target.value })} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-sm text-white" />
              </div>
              <div>
                <label className="text-xs font-bold text-slate-400 uppercase">Progression Strategy</label>
                <input type="text" value={plan.progression} onChange={(e) => setPlan({ ...plan, progression: e.target.value })} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-sm text-white" />
              </div>
              <div>
                <label className="text-xs font-bold text-slate-400 uppercase">Workout Session JSON</label>
                <textarea rows="4" value={JSON.stringify(plan.sessions, null, 2)} onChange={(e) => { try { setPlan({ ...plan, sessions: JSON.parse(e.target.value) }); } catch (_) {} }} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-xs font-mono text-emerald-300" />
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-slate-800/80 p-5 rounded-xl border border-slate-700">
            <h2 className="text-md font-bold text-emerald-400 mb-3">3. Automated Policy Audits</h2>
            <div className="space-y-2">
              {checks.map((c, i) => (
                <div key={i} className="flex items-center gap-2.5 p-2.5 bg-slate-950 rounded border border-slate-800 text-xs">
                  <span className={c.pass ? 'text-emerald-500 font-bold' : 'text-rose-500 font-bold'}>{c.pass ? '✓' : '✗'}</span>
                  <span className={c.pass ? 'text-slate-300' : 'text-rose-300'}>{c.text}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-slate-800/80 p-5 rounded-xl border border-slate-700">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-md font-bold text-emerald-400">4. Scorecard & Review</h2>
              <div className="bg-emerald-950 px-3 py-1 rounded border border-emerald-800">
                <span className="text-xs text-emerald-400 uppercase block font-bold">Overall Rating</span>
                <span className="text-lg font-black text-white">{avg} / 10</span>
              </div>
            </div>

            <div className="space-y-3">
              {Object.keys(scores).map((key) => (
                <div key={key}>
                  <div className="flex justify-between text-xs mb-1 font-semibold text-slate-300 capitalize">
                    <span>{key === 'fit' ? 'Target Fit' : key}</span>
                    <span>{scores[key]}/10</span>
                  </div>
                  <input type="range" min="0" max="10" value={scores[key]} onChange={(e) => setScores({ ...scores, [key]: Number(e.target.value) })} className="w-full accent-emerald-500" />
                </div>
              ))}
              <div className="pt-2">
                <label className="text-xs font-bold text-slate-400 uppercase">Reviewer Comments</label>
                <textarea rows="2" value={comments} onChange={(e) => setComments(e.target.value)} className="w-full mt-1 bg-slate-950 border border-slate-700 rounded p-2 text-sm text-white" />
              </div>
            </div>

            <button onClick={exportJSON} className="mt-5 w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded text-sm transition">
              Download Quality Report JSON
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}