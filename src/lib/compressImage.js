// Compresse et redimensionne une image côté navigateur AVANT l'upload.
// C'est la cause la plus probable de lenteur perçue : une photo de
// smartphone moderne pèse souvent 3 à 8 Mo à 4000px de large — on la
// ramène à un poids raisonnable pour le web sans perte visible sur mobile.

export async function compressImage(file, { maxWidth = 1600, maxHeight = 1600, quality = 0.8 } = {}) {
  return new Promise((resolve, reject) => {
    const img = new window.Image();
    const objectUrl = URL.createObjectURL(file);

    img.onload = () => {
      let { width, height } = img;

      if (width > maxWidth || height > maxHeight) {
        const ratio = Math.min(maxWidth / width, maxHeight / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);
      }

      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(
        (blob) => {
          URL.revokeObjectURL(objectUrl);
          if (!blob) {
            reject(new Error('Compression échouée'));
            return;
          }
          const compressedFile = new File(
            [blob],
            file.name.replace(/\.[^.]+$/, '.jpg'),
            { type: 'image/jpeg' }
          );
          resolve(compressedFile);
        },
        'image/jpeg',
        quality
      );
    };

    img.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error("Impossible de lire l'image"));
    };

    img.src = objectUrl;
  });
}

