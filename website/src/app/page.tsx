import { Navbar } from "@/components/landing/Navbar";
import { Hero } from "@/components/landing/Hero";
import { Features } from "@/components/landing/Features";
import { MenuDesignerSpotlight } from "@/components/landing/MenuDesignerSpotlight";
import { TemplateGallery } from "@/components/landing/TemplateGallery";
import { HowItWorks } from "@/components/landing/HowItWorks";
import { ClosingCta } from "@/components/landing/ClosingCta";
import { Footer } from "@/components/landing/Footer";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1">
        <Hero />
        <MenuDesignerSpotlight />
        <TemplateGallery />
        <Features />
        <HowItWorks />
        <ClosingCta />
      </main>
      <Footer />
    </div>
  );
}
