import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#1B4332",
          700: "#163727",
        },
        secondary: { DEFAULT: "#2D6A4F" },
        accent: { DEFAULT: "#52B788" },
        background: {
          DEFAULT: "#FFFFFF",
          subtle: "#F8FAF8",
        },
        text: {
          primary: "#1E293B",
          secondary: "#64748B",
        },
        border: "#E2E8F0",
      },
      fontFamily: {
        sans: ["Inter", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
