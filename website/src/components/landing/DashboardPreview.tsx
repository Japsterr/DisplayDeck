import { Play, MapPin, List, Settings, BarChart3, Users } from "lucide-react";

export function DashboardPreview() {
  return (
    <div className="relative w-full max-w-[800px] perspective-1000">
      {/* Main Dashboard Container - Tilted */}
      <div 
        className="relative rounded-xl bg-neutral-900/90 border border-white/10 shadow-2xl overflow-hidden backdrop-blur-sm transform rotate-y-[-12deg] rotate-x-[5deg] transition-transform duration-500 hover:rotate-y-[-5deg] hover:rotate-x-[2deg]"
        style={{ transformStyle: 'preserve-3d' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-white/10 bg-neutral-900/50">
          <div className="flex items-center gap-2">
            <div className="h-3 w-3 rounded-full bg-red-500/20" />
            <div className="h-3 w-3 rounded-full bg-yellow-500/20" />
            <div className="h-3 w-3 rounded-full bg-green-500/20" />
          </div>
          <div className="text-xs text-neutral-500 font-mono">dashboard.displaydeck.com</div>
          <div className="h-6 w-6 rounded-full bg-neutral-800" />
        </div>

        {/* Content Grid */}
        <div className="grid grid-cols-12 gap-4 p-4 h-[400px]">
          {/* Sidebar */}
          <div className="col-span-2 flex flex-col gap-4 border-r border-white/5 pr-4">
            <div className="h-8 w-8 rounded bg-primary/20 flex items-center justify-center text-primary">
              <BarChart3 size={16} />
            </div>
            <div className="h-8 w-8 rounded bg-neutral-800/50 flex items-center justify-center text-neutral-500">
              <List size={16} />
            </div>
            <div className="h-8 w-8 rounded bg-neutral-800/50 flex items-center justify-center text-neutral-500">
              <Users size={16} />
            </div>
            <div className="mt-auto h-8 w-8 rounded bg-neutral-800/50 flex items-center justify-center text-neutral-500">
              <Settings size={16} />
            </div>
          </div>

          {/* Main Content */}
          <div className="col-span-10 grid grid-cols-2 gap-4">
            {/* Video Player Widget */}
            <div className="col-span-2 h-48 rounded-lg bg-neutral-800/30 border border-white/5 relative overflow-hidden group">
              <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 to-purple-500/10" />
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="h-12 w-12 rounded-full bg-white/10 backdrop-blur flex items-center justify-center group-hover:scale-110 transition-transform">
                  <Play className="fill-white text-white ml-1" size={20} />
                </div>
              </div>
              <div className="absolute bottom-4 left-4">
                <div className="text-sm font-medium text-white">Welcome Campaign</div>
                <div className="text-xs text-neutral-400">Playing on 12 screens</div>
              </div>
            </div>

            {/* Map Widget */}
            <div className="h-40 rounded-lg bg-neutral-800/30 border border-white/5 relative overflow-hidden p-4">
              <div className="absolute inset-0 opacity-20" 
                   style={{ backgroundImage: 'radial-gradient(circle at 2px 2px, rgba(255,255,255,0.15) 1px, transparent 0)', backgroundSize: '20px 20px' }}>
              </div>
              <div className="relative h-full w-full">
                <MapPin className="absolute top-1/4 left-1/4 text-primary animate-bounce" size={20} />
                <MapPin className="absolute top-1/2 right-1/3 text-blue-500" size={20} />
                <MapPin className="absolute bottom-1/4 left-1/2 text-purple-500" size={20} />
              </div>
              <div className="absolute bottom-2 left-2 text-xs text-neutral-400">Active Locations</div>
            </div>

            {/* Stats Widget */}
            <div className="h-40 rounded-lg bg-neutral-800/30 border border-white/5 p-4 space-y-3">
              <div className="text-xs text-neutral-400">System Status</div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-white">Online</span>
                  <span className="text-green-400">98%</span>
                </div>
                <div className="h-1.5 w-full bg-neutral-800 rounded-full overflow-hidden">
                  <div className="h-full w-[98%] bg-green-500 rounded-full" />
                </div>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-white">Storage</span>
                  <span className="text-blue-400">45%</span>
                </div>
                <div className="h-1.5 w-full bg-neutral-800 rounded-full overflow-hidden">
                  <div className="h-full w-[45%] bg-blue-500 rounded-full" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Glow Effect */}
        <div className="absolute -inset-1 bg-gradient-to-r from-primary/20 to-blue-600/20 blur-xl -z-10" />
      </div>

      {/* Connecting Lines / Circuitry Effect behind */}
      <div className="absolute top-1/2 -right-20 w-40 h-[1px] bg-gradient-to-r from-primary/50 to-transparent transform rotate-12" />
      <div className="absolute bottom-10 -left-10 w-32 h-[1px] bg-gradient-to-r from-transparent to-blue-500/50 transform -rotate-12" />
    </div>
  );
}
