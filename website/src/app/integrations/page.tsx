import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import { BentoGrid, BentoGridItem } from "@/components/landing/BentoGrid";
import { Database, Server, Code, Cloud } from "lucide-react";

export default function IntegrationsPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Integrations
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Connect DisplayDeck with your existing infrastructure.
            </p>
          </div>

          <BentoGrid className="max-w-6xl mx-auto">
            {integrations.map((item, i) => (
              <BentoGridItem
                key={i}
                title={item.title}
                description={item.description}
                header={item.header}
                icon={item.icon}
              />
            ))}
          </BentoGrid>
        </div>
      </main>
      <Footer />
    </div>
  );
}

const Skeleton = () => (
  <div className="flex flex-1 w-full h-full min-h-[6rem] rounded-xl bg-gradient-to-br from-neutral-200 dark:from-neutral-900 dark:to-neutral-800 to-neutral-100 animate-pulse"></div>
);

const integrations = [
  {
    title: "PostgreSQL",
    description: "Use your own database for full data sovereignty.",
    header: <Skeleton />,
    icon: <Database className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Docker",
    description: "Deploy anywhere with our official Docker images.",
    header: <Skeleton />,
    icon: <Server className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "REST API",
    description: "Integrate with any language or framework via standard HTTP.",
    header: <Skeleton />,
    icon: <Code className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "S3 Compatible Storage",
    description: "Store media on AWS S3, MinIO, or Cloudflare R2.",
    header: <Skeleton />,
    icon: <Cloud className="h-4 w-4 text-neutral-500" />,
  },
];
