const sharp = require('sharp');
const path = require('path');

const base = '/Users/zp/Documents/Codex/2026-09-11/ge/work/android';
const whale = path.join(base, 'favicon_whale.png');

async function main() {
  // Foreground: transparent 432x432 canvas, whale scaled to 240px and centered.
  const whaleBuf = await sharp(whale).resize(240, 240).toBuffer();
  const foreground = await sharp({
    create: { width: 432, height: 432, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  })
    .composite([{ input: whaleBuf, left: 96, top: 96 }])
    .png()
    .toBuffer();
  await sharp(foreground).toFile(path.join(base, 'ic_launcher_foreground.png'));

  // Legacy: white 432x432 canvas, same whale centered.
  const legacy = await sharp({
    create: { width: 432, height: 432, channels: 4, background: { r: 255, g: 255, b: 255, alpha: 1 } },
  })
    .composite([{ input: whaleBuf, left: 96, top: 96 }])
    .png()
    .toBuffer();
  await sharp(legacy).toFile(path.join(base, 'ic_launcher_legacy.png'));

  console.log('icons written');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
