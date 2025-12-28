import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowRight, Terminal } from "lucide-react";
import { DashboardPreview } from "./DashboardPreview";
import { Logo3D } from "./Logo3D";

export function Hero() {
  return (
    <section className="relative overflow-hidden pt-20 md:pt-32 pb-20 min-h-[90vh] flex items-center">
      {/* Background Effects */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-indigo-900/20 via-background to-background" />
      <div className="absolute inset-0 bg-[url('/grid.svg')] bg-center [mask-image:linear-gradient(180deg,white,rgba(255,255,255,0))]" />
      
      <div className="container relative px-4 md:px-6 z-10">
        <div className="grid gap-12 lg:grid-cols-2 lg:gap-8 items-center">
          <div className="flex flex-col justify-center space-y-8">
            <div className="space-y-6">
              <Logo3D className="mb-6" />
              
              <h1 className="text-5xl font-bold tracking-tighter sm:text-6xl xl:text-7xl/none text-white">
                DisplayDeck
              </h1>
              <p className="text-xl font-medium text-blue-400/80 tracking-wide uppercase">
                Programmable Digital Signage
              </p>
              
              <p className="max-w-[600px] text-neutral-400 md:text-xl leading-relaxed">
                The open-source digital signage platform for developers. Control screens, schedule content, and manage devices with a simple API.
              </p>
            </div>
            
            <div className="flex flex-col gap-4 min-[400px]:flex-row">
              <Link href="/register">
                <Button size="lg" className="h-12 px-8 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white border-0 shadow-lg shadow-purple-500/20 rounded-full font-semibold text-base">
                  Get Started
                </Button>
              </Link>
            </div>
          </div>
          
          {/* Dashboard Visual */}
          <div className="mx-auto w-full max-w-[800px] lg:max-w-none perspective-1000">
            <DashboardPreview />
          </div>
        </div>
      </div>
    </section>
  );
}
