export function HowItWorks() {
  const steps = [
    {
      n: "1",
      title: "Connect",
      desc: "Plug your screen into any internet-connected device.",
    },
    {
      n: "2",
      title: "Design",
      desc: "Use the Menu Designer to build your perfect layout.",
    },
    {
      n: "3",
      title: "Go Live",
      desc: "Assign your content and watch your sales grow.",
    },
  ];

  return (
    <section className="py-24 w-full relative overflow-hidden">
      <div className="container mx-auto px-4 md:px-6">
        <div className="max-w-3xl mx-auto text-center space-y-4">
          <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-white">How it works</h2>
          <p className="text-neutral-400 md:text-xl/relaxed">A simple setup that scales from one screen to a whole chain.</p>
        </div>

        <div className="grid gap-6 md:grid-cols-3 max-w-5xl mx-auto mt-12">
          {steps.map((s) => (
            <div key={s.n} className="rounded-2xl bg-neutral-900/50 border border-white/5 p-6">
              <div className="text-sm text-blue-300 font-semibold tracking-wide">Step {s.n}</div>
              <h3 className="text-white font-semibold mt-2">{s.title}</h3>
              <p className="text-sm text-neutral-400 leading-relaxed mt-2">{s.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
