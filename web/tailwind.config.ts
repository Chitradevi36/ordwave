import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#1B4332",
          50: "#E8F5EE",
          100: "#C6E6D3",
          200: "#95CDB0",
          300: "#64B48C",
          400: "#3F9B6F",
          500: "#2D6A4F",
          600: "#1B4332",
          700: "#163727",
          800: "#112B1E",
          900: "#0B1F14",
        },
        secondary: {
          DEFAULT: "#2D6A4F",
        },
        accent: {
          DEFAULT: "#52B788",
        },
        success: "#52B788",
        danger: "#DC2626",
        warning: "#D97706",
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
      spacing: {
        2: "8px",
        3: "12px",
        4: "16px",
      },
    },
  },
  plugins: [],
};

export default config;
