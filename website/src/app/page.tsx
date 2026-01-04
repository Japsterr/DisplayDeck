import { Navbar } from "@/components/landing/Navbar";
import { Hero } from "@/components/landing/Hero";
import { Features } from "@/components/landing/Features";
import { MenuDesignerSpotlight } from "@/components/landing/MenuDesignerSpotlight";
import { HowItWorks } from "@/components/landing/HowItWorks";
import { Footer } from "@/components/landing/Footer";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col bg-slate-950">
      <Navbar />
      <main className="flex-1">
        <Hero />
        <Features />
        <MenuDesignerSpotlight />
        <HowItWorks />
      </main>
      <Footer />
    </div>
  );
}
