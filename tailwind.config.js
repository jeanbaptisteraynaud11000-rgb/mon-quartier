/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/app/**/*.{js,jsx}',
    './src/components/**/*.{js,jsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Palette Mon Quartier (voir prompt maître, section 3)
        corail: {
          DEFAULT: '#FF5A5F',
          hover: '#E5484F',
        },
        vert: {
          DEFAULT: '#00A699',
        },
        surface: {
          DEFAULT: '#FFFFFF', // fond principal
          card: '#FAFAFA',    // fond cartes
        },
        border: {
          DEFAULT: '#EAEAEA',
        },
        content: {
          primary: '#484848',   // texte principal
          secondary: '#767676', // texte secondaire
        },
      },
      borderRadius: {
        card: '1rem',     // grands border-radius pour cartes
        sheet: '1.5rem',  // bottom sheets
        pill: '9999px',   // boutons/badges arrondis
      },
      boxShadow: {
        soft: '0 2px 10px rgba(0, 0, 0, 0.06)',
        sheet: '0 -4px 24px rgba(0, 0, 0, 0.10)',
      },
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'Helvetica Neue',
          'Arial',
          'sans-serif',
        ],
      },
      spacing: {
        // hauteur de la barre de navigation basse + zone tactile confortable
        'nav-h': '4.25rem',
        'tap': '2.75rem',
      },
      transitionDuration: {
        fast: '150ms',
      },
    },
  },
  plugins: [],
};

