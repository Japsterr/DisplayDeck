import { Navbar } from "@/components/landing/Navbar";
import { Hero } from "@/components/landing/Hero";
import { MenuDesignerSpotlight } from "@/components/landing/MenuDesignerSpotlight";
import { Footer } from "@/components/landing/Footer";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1">
        <Hero />
        <MenuDesignerSpotlight />
      </main>
      <Footer />
    </div>
  );
}
