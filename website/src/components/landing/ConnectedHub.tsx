import { Code, RefreshCw, ShieldCheck, Globe, Layers } from "lucide-react";

export function ConnectedHub() {
  return (
    <div className="relative w-full max-w-4xl mx-auto h-[300px] md:h-[400px] flex items-center justify-center my-12">
      {/* Connecting Lines (SVG) */}
      <svg className="absolute inset-0 w-full h-full pointer-events-none" style={{ zIndex: 0 }}>
        <defs>
          <linearGradient id="lineGradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="rgba(99, 102, 241, 0.1)" />
            <stop offset="50%" stopColor="rgba(99, 102, 241, 0.5)" />
            <stop offset="100%" stopColor="rgba(99, 102, 241, 0.1)" />
          </linearGradient>
        </defs>
        {/* Left to Center */}
        <path d="M 20% 50% L 50% 50%" stroke="url(#lineGradient)" strokeWidth="2" strokeDasharray="4 4" className="animate-pulse" />
        {/* Right to Center */}
        <path d="M 80% 50% L 50% 50%" stroke="url(#lineGradient)" strokeWidth="2" strokeDasharray="4 4" className="animate-pulse" />
        {/* Top to Center (Curved) */}
        <path d="M 35% 20% Q 50% 20% 50% 50%" stroke="url(#lineGradient)" strokeWidth="2" fill="none" strokeDasharray="4 4" className="animate-pulse" />
        {/* Bottom to Center (Curved) */}
        <path d="M 65% 20% Q 50% 20% 50% 50%" stroke="url(#lineGradient)" strokeWidth="2" fill="none" strokeDasharray="4 4" className="animate-pulse" />
      </svg>

      {/* Central Hub */}
      <div className="relative z-10 flex flex-col items-center justify-center">
        <div className="w-24 h-24 md:w-32 md:h-32 rounded-full bg-neutral-900 border border-indigo-500/30 shadow-[0_0_50px_-12px_rgba(99,102,241,0.5)] flex items-center justify-center relative group">
          <div className="absolute inset-0 rounded-full bg-indigo-500/10 animate-ping" />
          <Layers className="w-10 h-10 md:w-12 md:h-12 text-indigo-400" />
          <div className="absolute -bottom-8 text-sm font-bold text-white tracking-wider">DisplayDeck</div>
        </div>
      </div>

      {/* Surrounding Nodes */}
      
      {/* Left Node */}
      <div className="absolute left-[10%] md:left-[15%] top-1/2 -translate-y-1/2 flex flex-col items-center gap-3">
        <div className="w-16 h-16 rounded-full bg-neutral-900 border border-white/10 flex items-center justify-center shadow-lg">
          <Code className="w-6 h-6 text-blue-400" />
        </div>
      </div>

      {/* Right Node */}
      <div className="absolute right-[10%] md:right-[15%] top-1/2 -translate-y-1/2 flex flex-col items-center gap-3">
        <div className="w-16 h-16 rounded-full bg-neutral-900 border border-white/10 flex items-center justify-center shadow-lg">
          <Globe className="w-6 h-6 text-purple-400" />
        </div>
      </div>

      {/* Top Left Node */}
      <div className="absolute left-[25%] top-[15%] flex flex-col items-center gap-3">
        <div className="w-16 h-16 rounded-full bg-neutral-900 border border-white/10 flex items-center justify-center shadow-lg">
          <RefreshCw className="w-6 h-6 text-green-400" />
        </div>
      </div>

      {/* Top Right Node */}
      <div className="absolute right-[25%] top-[15%] flex flex-col items-center gap-3">
        <div className="w-16 h-16 rounded-full bg-neutral-900 border border-white/10 flex items-center justify-center shadow-lg">
          <ShieldCheck className="w-6 h-6 text-red-400" />
        </div>
      </div>
    </div>
  );
}
