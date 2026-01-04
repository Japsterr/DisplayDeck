"use client";

import Link from "next/link";
import Image from "next/image";
import { Github, Twitter, Linkedin, Mail, ExternalLink } from "lucide-react";

const footerLinks = {
  product: [
    { name: "Features", href: "/#features" },
    { name: "Pricing", href: "/pricing" },
    { name: "Templates", href: "/dashboard/menus" },
    { name: "Changelog", href: "/dashboard/roadmap" },
  ],
  resources: [
    { name: "Documentation", href: "/swagger/", external: true },
    { name: "API Reference", href: "/swagger/", external: true },
    { name: "GitHub", href: "https://github.com/Japsterr/DisplayDeck", external: true },
    { name: "Community", href: "https://github.com/Japsterr/DisplayDeck/discussions", external: true },
  ],
  company: [
    { name: "About", href: "/about" },
    { name: "Contact", href: "mailto:support@displaydeck.co.za" },
    { name: "Privacy Policy", href: "/privacy" },
    { name: "Terms of Service", href: "/terms" },
  ],
};

const socialLinks = [
  { name: "GitHub", icon: <Github className="h-5 w-5" />, href: "https://github.com/Japsterr/DisplayDeck" },
  { name: "Twitter", icon: <Twitter className="h-5 w-5" />, href: "#" },
  { name: "LinkedIn", icon: <Linkedin className="h-5 w-5" />, href: "#" },
  { name: "Email", icon: <Mail className="h-5 w-5" />, href: "mailto:support@displaydeck.co.za" },
];

export function Footer() {
  return (
    <footer className="relative border-t border-white/10 bg-slate-950">
      {/* Gradient accent */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-1/2 h-px bg-gradient-to-r from-transparent via-purple-500/50 to-transparent" />

      <div className="container mx-auto px-4 md:px-6 py-16">
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-8 lg:gap-12">
          {/* Brand Column */}
          <div className="col-span-2 lg:col-span-2">
            <Link href="/" className="flex items-center gap-3 mb-6">
              <div className="relative h-10 w-10 overflow-hidden rounded-lg bg-gradient-to-br from-cyan-500 to-purple-600 p-0.5">
                <div className="flex h-full w-full items-center justify-center rounded-[7px] bg-slate-950">
                  <Image
                    src="/landing/logo.png"
                    alt="DisplayDeck"
                    width={32}
                    height={32}
                    className="object-contain"
                  />
                </div>
              </div>
              <span className="text-xl font-bold text-white">DisplayDeck</span>
            </Link>
            <p className="text-slate-400 text-sm leading-relaxed mb-6 max-w-xs">
              The open-source digital signage platform for businesses of all sizes. 
              Create, manage, and deploy stunning displays.
            </p>
            <div className="flex items-center gap-3">
              {socialLinks.map((social) => (
                <Link
                  key={social.name}
                  href={social.href}
                  target="_blank"
                  className="flex items-center justify-center w-10 h-10 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white hover:bg-white/10 hover:border-white/20 transition-all"
                  aria-label={social.name}
                >
                  {social.icon}
                </Link>
              ))}
            </div>
          </div>

          {/* Product Links */}
          <div>
            <h4 className="text-sm font-semibold text-white uppercase tracking-wider mb-4">Product</h4>
            <ul className="space-y-3">
              {footerLinks.product.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-slate-400 hover:text-white transition-colors"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Resources Links */}
          <div>
            <h4 className="text-sm font-semibold text-white uppercase tracking-wider mb-4">Resources</h4>
            <ul className="space-y-3">
              {footerLinks.resources.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    target={link.external ? "_blank" : undefined}
                    className="text-sm text-slate-400 hover:text-white transition-colors inline-flex items-center gap-1"
                  >
                    {link.name}
                    {link.external && <ExternalLink className="h-3 w-3" />}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Company Links */}
          <div>
            <h4 className="text-sm font-semibold text-white uppercase tracking-wider mb-4">Company</h4>
            <ul className="space-y-3">
              {footerLinks.company.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-slate-400 hover:text-white transition-colors"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="mt-16 pt-8 border-t border-white/10 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-sm text-slate-500">
            © {new Date().getFullYear()} DisplayDeck. All rights reserved.
          </p>
          <div className="flex items-center gap-6">
            <Link href="/privacy" className="text-sm text-slate-500 hover:text-slate-300 transition-colors">
              Privacy
            </Link>
            <Link href="/terms" className="text-sm text-slate-500 hover:text-slate-300 transition-colors">
              Terms
            </Link>
            <Link 
              href="https://github.com/Japsterr/DisplayDeck" 
              target="_blank"
              className="text-sm text-slate-500 hover:text-slate-300 transition-colors flex items-center gap-1"
            >
              <Github className="h-4 w-4" />
              Open Source
            </Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
