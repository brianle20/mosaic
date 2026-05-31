import type { Metadata } from "next";

const openGraphImage = {
  url: "/mosaic-app-icon.png",
  width: 1024,
  height: 1024,
  alt: "Mosaic app icon",
};

function titleCaseWord(word: string) {
  if (word.length <= 3 && /^[a-z]+$/i.test(word)) {
    return word.toUpperCase();
  }

  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
}

export function eventTitleFromSlug(eventSlug: string) {
  return decodeURIComponent(eventSlug)
    .split("-")
    .filter(Boolean)
    .map(titleCaseWord)
    .join(" ");
}

export function publicEventMetadata({
  canonicalPath,
  description,
  title,
}: {
  canonicalPath: string;
  description: string;
  title: string;
}): Metadata {
  return {
    title,
    description,
    alternates: {
      canonical: canonicalPath,
    },
    openGraph: {
      title,
      description,
      url: canonicalPath,
      siteName: "Mosaic",
      type: "website",
      locale: "en_US",
      images: [openGraphImage],
    },
    twitter: {
      card: "summary",
      title,
      description,
      images: [openGraphImage.url],
    },
  };
}
