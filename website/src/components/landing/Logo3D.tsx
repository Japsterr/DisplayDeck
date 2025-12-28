export function Logo3D({ className }: { className?: string }) {
  return (
    <div className={`relative w-24 h-24 ${className}`}>
      <div className="absolute inset-0 transform rotate-45 scale-75">
        {/* Top Face */}
        <div className="absolute top-0 left-0 w-1/2 h-1/2 bg-gradient-to-br from-blue-400 to-blue-600 transform -skew-y-12 translate-y-[-10%] z-20 rounded-sm shadow-lg" />
        
        {/* Right Face */}
        <div className="absolute top-0 right-0 w-1/2 h-1/2 bg-gradient-to-bl from-purple-500 to-purple-700 transform skew-y-12 translate-y-[-10%] z-10 rounded-sm" />
        
        {/* Bottom/Front Face */}
        <div className="absolute bottom-0 left-1/4 w-1/2 h-1/2 bg-gradient-to-t from-indigo-600 to-indigo-400 transform rotate-45 z-30 rounded-sm shadow-2xl border-t border-white/20" />
        
        {/* Glow */}
        <div className="absolute inset-0 bg-blue-500/30 blur-2xl -z-10" />
      </div>
    </div>
  );
}
