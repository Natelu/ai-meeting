import type { Metadata } from "next";

import "./styles.css";

export const metadata: Metadata = {
  title: "AI Meeting Pilot",
  description: "Private AI meeting pilot console with mock data",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
