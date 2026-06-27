import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { SalesEmailLink } from "../components/SalesEmailLink";

export const metadata: Metadata = {
  title: "Mosaic | Mahjong event software",
  description:
    "Host polished mahjong events with check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
  alternates: {
    canonical: "/",
  },
  keywords: [
    "mahjong event software",
    "mahjong tournament software",
    "mahjong event management",
    "live mahjong standings",
  ],
  openGraph: {
    title: "Mosaic | Mahjong event software",
    description:
      "Host polished mahjong events with check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
    url: "/",
    siteName: "Mosaic",
    type: "website",
    locale: "en_US",
    images: [
      {
        url: "/mosaic-app-icon.png",
        width: 1024,
        height: 1024,
        alt: "Mosaic app icon",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "Mosaic | Mahjong event software",
    description:
      "Host polished mahjong events with check-in, seating, scoring, standings, finals, and prizes in one calm tool.",
    images: ["/mosaic-app-icon.png"],
  },
};

const salesEmail = "sales@mosaicmahjong.com";

const workflowSteps = ["Check in", "Seat tables", "Score hands", "Publish standings"];

const benefits = [
  {
    title: "Event-day control",
    copy: "Keep guests, tables, and rounds moving.",
  },
  {
    title: "Live leaderboards",
    copy: "Share standings as the room plays.",
  },
  {
    title: "Finals and prizes",
    copy: "Close the event with clear results.",
  },
];

export default function LandingPage() {
  return (
    <div className="landing-page">
      <header className="landing-header">
        <Link className="landing-brand" href="/" aria-label="Mosaic home">
          <Image src="/mosaic-app-icon.png" alt="" width={40} height={40} priority />
          <span>Mosaic</span>
        </Link>
        <nav className="public-nav landing-nav" aria-label="Public navigation">
          <Link href="/events">Events</Link>
          <SalesEmailLink className="landing-header-email" location="header">
            {salesEmail}
          </SalesEmailLink>
        </nav>
      </header>

      <main>
        <section className="landing-hero" aria-labelledby="landing-title">
          <div className="landing-hero-content">
            <p className="landing-eyebrow">Mahjong event software</p>
            <h1 id="landing-title">Host polished mahjong events.</h1>
            <p className="landing-copy">
              Check-in, seating, scoring, standings, finals, and prizes in one calm tool.
            </p>
            <div className="landing-actions">
              <SalesEmailLink className="landing-primary-link" location="hero">
                Email sales
              </SalesEmailLink>
              <p>For clubs, leagues, pop-ups, and private events.</p>
            </div>
          </div>
        </section>

        <section className="workflow-strip" aria-label="Event workflow">
          {workflowSteps.map((step) => (
            <div className="workflow-step" key={step}>
              {step}
            </div>
          ))}
        </section>

        <section className="benefit-grid" aria-label="Mosaic benefits">
          {benefits.map((benefit) => (
            <article className="benefit-card" key={benefit.title}>
              <h2>{benefit.title}</h2>
              <p>{benefit.copy}</p>
            </article>
          ))}
        </section>

        <section className="closing-cta" aria-labelledby="closing-title">
          <h2 id="closing-title">Interested in Mosaic?</h2>
          <SalesEmailLink location="closing">{salesEmail}</SalesEmailLink>
        </section>
      </main>
    </div>
  );
}
