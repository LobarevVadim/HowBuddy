import {writeFileSync} from 'node:fs';
import {join} from 'node:path';

const directory = 'assets/avatar/effects';
const colors = {
  pink: ['#FFD3DF', '#FF6780', '#D93F63'],
  gold: ['#FFF4BB', '#FFD166', '#E99A32'],
  mint: ['#E0F8B7', '#8ED081', '#42A975'],
  sky: ['#D7F4FF', '#76C7F2', '#438DD2'],
  lilac: ['#F0E4FF', '#B995F9', '#805ED2'],
  peach: ['#FFE8C9', '#FF9F68', '#E66A4C'],
  aqua: ['#D7FFF5', '#62D6C8', '#23AFA9'],
  rose: ['#FFE0F2', '#F28DB5', '#CF5792'],
};
const outline = '#77513C';
const themes = [
  'heart', 'waterDrop', 'laughingFace', 'fivePointStar', 'fourPointStar',
  'leaf', 'partyPopper', 'flower', 'butterfly', 'moon', 'clover', 'cloud',
  'planet', 'crown', 'bow', 'cherries', 'rainbow', 'sun', 'snowflake',
  'musicNote', 'flame', 'comet', 'mushroom', 'ladybug', 'lightning',
];
const gradients = Object.entries(colors).map(([name, stops]) =>
  `<linearGradient id="${name}" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="${stops[0]}"/><stop offset=".55" stop-color="${stops[1]}"/><stop offset="1" stop-color="${stops[2]}"/></linearGradient>`,
).join('');

function starPath(radius = 9, inner = 4.2, points = 5) {
  const coordinates = [];
  for (let i = 0; i < points * 2; i++) {
    const angle = (-90 + (180 * i) / points) * Math.PI / 180;
    const r = i % 2 ? inner : radius;
    coordinates.push(`${(r * Math.cos(angle)).toFixed(2)},${(r * Math.sin(angle)).toFixed(2)}`);
  }
  return `M ${coordinates.join(' L ')} Z`;
}

function art(kind, fill) {
  const sticker = (path, extra = '') =>
    `<path d="${path}" fill="url(#${fill})" stroke="#fff" stroke-width="4.5" stroke-linejoin="round"/><path d="${path}" fill="url(#${fill})" stroke="${outline}" stroke-width="1.2" stroke-linejoin="round"/>${extra}`;
  switch (kind) {
    case 'waterDrop': {
      const p = 'M 0 -11 C -2 -7 -9 0 -9 5 C -9 11 -5 14 0 14 C 5 14 9 11 9 5 C 9 0 2 -7 0 -11 Z';
      return sticker(p, '<ellipse cx="-3" cy="3" rx="2" ry="3.2" fill="#fff" opacity=".78" transform="rotate(18 -3 3)"/><ellipse cx="3.5" cy="9" rx="2.2" ry="1" fill="#348FC6" opacity=".36"/>');
    }
    case 'laughingFace':
      return `<circle r="11.5" fill="url(#gold)" stroke="#fff" stroke-width="4.5"/><circle r="11.5" fill="url(#gold)" stroke="#A96B38" stroke-width="1.2"/><path d="M -6 -1 Q -4 -4 -2 -1 M 2 -1 Q 4 -4 6 -1" fill="none" stroke="#704B38" stroke-width="1.8" stroke-linecap="round"/><path d="M -7 2 Q 0 12 7 2 Q 6 8 0 8 Q -6 8 -7 2 Z" fill="#7E3D38" stroke="#fff" stroke-width="1"/><path d="M -4 5 Q 0 6 4 5 L 3 7 Q 0 8 -3 7 Z" fill="#FF6780"/><circle cx="-7.2" cy="2" r="1.5" fill="#F28DB5"/><circle cx="7.2" cy="2" r="1.5" fill="#F28DB5"/><ellipse cx="-4" cy="-6" rx="2.3" ry="1" fill="#fff" opacity=".8" transform="rotate(-30 -4 -6)"/>`;
    case 'fivePointStar':
      return art('star', fill);
    case 'fourPointStar': {
      const p = 'M 0 -12 C 2 -3 4 -2 11 0 C 4 2 2 4 0 12 C -2 4 -4 2 -11 0 C -4 -2 -2 -4 0 -12 Z';
      return sticker(p, '<ellipse cx="-3" cy="-4" rx="1.7" ry=".8" fill="#fff" opacity=".85" transform="rotate(-35 -3 -4)"/>');
    }
    case 'partyPopper':
      return `<path d="M -10 5 L 7 -7 L 10 -4 L -4 11 Z" fill="url(#${fill})" stroke="#fff" stroke-width="4.5" stroke-linejoin="round"/><path d="M -10 5 L 7 -7 L 10 -4 L -4 11 Z" fill="url(#${fill})" stroke="${outline}" stroke-width="1.2" stroke-linejoin="round"/><path d="M -8 5 L -3 10" stroke="#FFF1A8" stroke-width="2" stroke-linecap="round"/><path d="M 4 -8 L 7 -12 M 8 -10 L 11 -11 M 11 -6 L 14 -7 M 3 -12 L 3 -15" stroke="url(#gold)" stroke-width="2.1" stroke-linecap="round"/><circle cx="10" cy="-13" r="1.5" fill="url(#pink)" stroke="#fff" stroke-width="1"/><path d="M 12 -1 L 15 1 L 13 4 Z" fill="url(#aqua)" stroke="#fff" stroke-width="1"/>`;
    case 'musicNote':
      return `<path d="M 2 -10 L 10 -12 L 10 5 C 10 9 4 11 2 8 C 0 5 4 2 8 3 L 8 -6 L 2 -4 Z" fill="url(#${fill})" stroke="#fff" stroke-width="4.5" stroke-linejoin="round"/><path d="M 2 -10 L 10 -12 L 10 5 C 10 9 4 11 2 8 C 0 5 4 2 8 3 L 8 -6 L 2 -4 Z" fill="url(#${fill})" stroke="${outline}" stroke-width="1.2" stroke-linejoin="round"/><ellipse cx="4" cy="6" rx="1.3" ry=".8" fill="#fff" opacity=".8"/>`;
    case 'flame': {
      const p = 'M 1 -13 C 3 -6 11 -4 9 4 C 8 11 3 14 -2 12 C -11 9 -10 1 -6 -4 C -5 1 -2 2 -1 0 C 1 -4 -2 -7 1 -13 Z';
      return sticker(p, '<path d="M 1 2 C 5 6 3 10 0 11 C -4 10 -4 6 1 2 Z" fill="url(#gold)"/><ellipse cx="-4" cy="-4" rx="1.7" ry="3" fill="#fff" opacity=".72" transform="rotate(28 -4 -4)"/>');
    }
    case 'comet': {
      const p = 'M -2 -2 C 1 -9 9 -10 12 -5 C 15 0 10 8 3 8 C 6 4 2 1 -2 -2 Z';
      return `${sticker(p)}<path d="M -4 0 C -10 2 -13 6 -14 12 C -8 9 -3 7 1 5" fill="url(#${fill})" stroke="#fff" stroke-width="3" stroke-linejoin="round"/><path d="M -4 0 C -10 2 -13 6 -14 12 C -8 9 -3 7 1 5" fill="url(#${fill})" stroke="${outline}" stroke-width=".8" stroke-linejoin="round"/><ellipse cx="5" cy="-4" rx="2" ry="1" fill="#fff" opacity=".85"/>`;
    }
    case 'mushroom':
      return `<path d="M -4 -1 L -5 9 Q 0 12 5 9 L 4 -1 Z" fill="url(#gold)" stroke="#fff" stroke-width="4.2" stroke-linejoin="round"/><path d="M -4 -1 L -5 9 Q 0 12 5 9 L 4 -1 Z" fill="url(#gold)" stroke="${outline}" stroke-width="1.1" stroke-linejoin="round"/><path d="M -12 -2 C -11 -11 -5 -14 1 -13 C 8 -13 12 -8 12 -2 Q 0 1 -12 -2 Z" fill="url(#${fill})" stroke="#fff" stroke-width="4.5" stroke-linejoin="round"/><path d="M -12 -2 C -11 -11 -5 -14 1 -13 C 8 -13 12 -8 12 -2 Q 0 1 -12 -2 Z" fill="url(#${fill})" stroke="${outline}" stroke-width="1.2" stroke-linejoin="round"/><circle cx="-5" cy="-7" r="1.5" fill="#fff"/><circle cx="2" cy="-9" r="1.2" fill="#fff"/><circle cx="7" cy="-5" r="1.4" fill="#fff"/><ellipse cx="-2" cy="3" rx="1" ry="2" fill="#fff" opacity=".7"/>`;
    case 'ladybug':
      return `<path d="M 0 -10 C 8 -10 11 -4 10 2 C 9 9 4 12 0 12 C -4 12 -9 9 -10 2 C -11 -4 -8 -10 0 -10 Z" fill="url(#${fill})" stroke="#fff" stroke-width="4.5"/><path d="M 0 -10 C 8 -10 11 -4 10 2 C 9 9 4 12 0 12 C -4 12 -9 9 -10 2 C -11 -4 -8 -10 0 -10 Z" fill="url(#${fill})" stroke="${outline}" stroke-width="1.2"/><path d="M 0 -8 L 0 9" stroke="${outline}" stroke-width="1.3"/><circle cx="-5" cy="-3" r="1.7" fill="#3D3030"/><circle cx="5" cy="-3" r="1.7" fill="#3D3030"/><circle cx="-6" cy="3" r="1.7" fill="#3D3030"/><circle cx="6" cy="3" r="1.7" fill="#3D3030"/><path d="M -3 -9 Q 0 -14 3 -9" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/><path d="M -3 -9 Q 0 -14 3 -9" fill="none" stroke="${outline}" stroke-width="1" stroke-linecap="round"/><ellipse cx="-4" cy="-5" rx="1.6" ry=".8" fill="#fff" opacity=".8"/>`;
    case 'lightning': {
      const p = 'M 2 -13 L -8 1 L -2 1 L -5 13 L 8 -3 L 2 -3 Z';
      return sticker(p, '<path d="M 0 -7 L -4 0 L -1 0" fill="none" stroke="#fff" stroke-width="1.3" stroke-linecap="round"/>');
    }
    case 'star': {
      const p = starPath();
      return `${sticker(p, '<ellipse cx="-2.8" cy="-3" rx="1.8" ry=".9" fill="#fff" opacity=".85" transform="rotate(-30 -2.8 -3)"/><circle cx="3.4" cy="2" r=".8" fill="#fff"/>')}`;
    }
    case 'heart': {
      const p = 'M 0 8 C -3 6 -9 1 -9 -3 C -9 -9 -2 -10 0 -5 C 3 -10 9 -9 9 -3 C 9 1 3 6 0 8 Z';
      return sticker(p, '<ellipse cx="-3" cy="-4" rx="2" ry="1" fill="#fff" opacity=".8" transform="rotate(-35 -3 -4)"/><circle cx="4.5" cy="1" r=".8" fill="#fff"/>');
    }
    case 'flower': {
      let petals = '';
      for (let i = 0; i < 6; i++) {
        petals += `<ellipse cx="0" cy="-5.6" rx="3.4" ry="5.1" fill="url(#${fill})" stroke="#fff" stroke-width="3.3" transform="rotate(${i * 60})"/><ellipse cx="0" cy="-5.6" rx="3.4" ry="5.1" fill="url(#${fill})" stroke="${outline}" stroke-width="1.05" transform="rotate(${i * 60})"/>`;
      }
      return `${petals}<circle r="4.5" fill="url(#gold)" stroke="#fff" stroke-width="2.5"/><circle r="4.5" fill="url(#gold)" stroke="#A96B38" stroke-width=".8"/><circle cx="-1.5" cy="-1" r=".7" fill="#fff"/><circle cx="1.7" cy="1" r=".6" fill="#D8893C"/>`;
    }
    case 'spark': {
      const p = 'M 0 -10 Q 1.1 -1.5 9 0 Q 1.1 1.5 0 10 Q -1.1 1.5 -9 0 Q -1.1 -1.5 0 -10 Z';
      return sticker(p, '<ellipse cx="-2" cy="-3" rx="1.2" ry=".7" fill="#fff"/>');
    }
    case 'butterfly': {
      const p = 'M -1 0 C -11 -11 -13 -3 -8 0 C -12 6 -6 10 -1 3 Z M 1 0 C 11 -11 13 -3 8 0 C 12 6 6 10 1 3 Z';
      return sticker(p, '<path d="M 0 -3 Q -2 1 0 5 Q 2 1 0 -3" fill="#77513C" stroke="#fff" stroke-width="1"/><circle cx="-6" cy="-1" r="1.2" fill="#fff" opacity=".9"/><circle cx="6" cy="-1" r="1.2" fill="#fff" opacity=".9"/>');
    }
    case 'moon': {
      const p = 'M 6 -9 C -1 -11 -9 -5 -8 2 C -7 10 2 12 8 7 C 2 8 -3 3 -2 -2 C -2 -5 1 -8 6 -9 Z';
      return sticker(p, `<circle cx="-2.8" cy=".1" r=".7" fill="${outline}"/><circle cx="1" cy=".6" r=".7" fill="${outline}"/><path d="M -2 3 Q 0 4.5 1.5 3" fill="none" stroke="${outline}" stroke-width=".8" stroke-linecap="round"/><ellipse cx="-3" cy="-4" rx="2" ry=".8" fill="#fff" opacity=".7" transform="rotate(-30 -3 -4)"/>`);
    }
    case 'clover': {
      let leaves = '';
      for (const [x, y] of [[-3, -3], [3, -3], [-3, 3], [3, 3]]) {
        leaves += `<circle cx="${x}" cy="${y}" r="5" fill="url(#${fill})" stroke="#fff" stroke-width="3.5"/><circle cx="${x}" cy="${y}" r="5" fill="url(#${fill})" stroke="${outline}" stroke-width="1.05"/>`;
      }
      return `${leaves}<path d="M 0 2 Q 3 8 7 9" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/><path d="M 0 2 Q 3 8 7 9" fill="none" stroke="#43895B" stroke-width="1.3" stroke-linecap="round"/>`;
    }
    case 'cloud': {
      const p = 'M -10 5 C -13 1 -10 -4 -5 -4 C -3 -10 5 -10 7 -4 C 13 -4 14 3 10 6 Q 8 8 -10 7 Z';
      return sticker(p, '<ellipse cx="-4" cy="-3.5" rx="2.3" ry=".9" fill="#fff" opacity=".8" transform="rotate(-25 -4 -3.5)"/>');
    }
    case 'planet':
      return `<ellipse rx="13" ry="4.5" fill="none" stroke="#fff" stroke-width="5" transform="rotate(-25)"/><ellipse rx="13" ry="4.5" fill="none" stroke="${outline}" stroke-width="1.3" transform="rotate(-25)"/><circle r="7.2" fill="url(#${fill})" stroke="#fff" stroke-width="4"/><circle r="7.2" fill="url(#${fill})" stroke="${outline}" stroke-width="1.2"/><ellipse cx="-2" cy="-3" rx="2" ry="1" fill="#fff" opacity=".8" transform="rotate(-35 -2 -3)"/><path d="M -12 -1 Q -8 -5 -4 -4" fill="none" stroke="url(#gold)" stroke-width="2" stroke-linecap="round"/>`;
    case 'crown': {
      const p = 'M -10 6 L -9 -5 L -3 0 L 0 -9 L 4 0 L 10 -5 L 9 6 Z';
      return `${sticker(p)}<path d="M -9 7 Q 0 9 9 7" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/><path d="M -9 7 Q 0 9 9 7" fill="none" stroke="${outline}" stroke-width="1.2" stroke-linecap="round"/><circle cx="-3" cy="3" r="1" fill="#fff"/><circle cx="3" cy="3" r="1" fill="#fff"/>`;
    }
    case 'bow': {
      const p = 'M 0 0 C -4 -7 -13 -10 -12 -3 C -11 2 -6 3 0 1 C 6 3 11 2 12 -3 C 13 -10 4 -7 0 0 Z';
      return `${sticker(p)}<circle r="3" fill="url(#gold)" stroke="#fff" stroke-width="2"/><circle r="3" fill="url(#gold)" stroke="${outline}" stroke-width=".8"/><ellipse cx="-6" cy="-4" rx="2" ry="1" fill="#fff" opacity=".8" transform="rotate(-25 -6 -4)"/>`;
    }
    case 'leaf': {
      const p = 'M -1 10 C -12 4 -10 -8 9 -10 C 10 3 5 10 -1 10 Z';
      return sticker(p, '<path d="M -2 8 Q 0 0 7 -7" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round"/><path d="M 0 3 L -5 -1 M 3 -1 L 0 -4" fill="none" stroke="#43895B" stroke-width=".9" stroke-linecap="round"/>');
    }
    case 'cherries':
      return `<path d="M -1 -1 Q -6 -10 0 -11 M 1 -1 Q 8 -10 3 -11" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/><path d="M -1 -1 Q -6 -10 0 -11 M 1 -1 Q 8 -10 3 -11" fill="none" stroke="#43895B" stroke-width="1.2" stroke-linecap="round"/><circle cx="-4" cy="3" r="6" fill="url(#${fill})" stroke="#fff" stroke-width="4"/><circle cx="-4" cy="3" r="6" fill="url(#${fill})" stroke="${outline}" stroke-width="1.1"/><circle cx="5" cy="4" r="6" fill="url(#pink)" stroke="#fff" stroke-width="4"/><circle cx="5" cy="4" r="6" fill="url(#pink)" stroke="${outline}" stroke-width="1.1"/><ellipse cx="-6" cy="0" rx="1.8" ry=".9" fill="#fff" opacity=".8"/>`;
    case 'rainbow': {
      const p = 'M -11 8 A 11 11 0 0 1 11 8 L 7 8 A 7 7 0 0 0 -7 8 Z';
      return `${sticker(p)}<path d="M -10 8 A 10 10 0 0 1 10 8" fill="none" stroke="url(#gold)" stroke-width="2.2"/><circle cx="-11" cy="7" r="2.3" fill="#fff"/><circle cx="11" cy="7" r="2.3" fill="#fff"/>`;
    }
    case 'sun': {
      const p = starPath(10, 8, 12);
      return `${sticker(p)}<circle r="6.7" fill="url(#gold)" stroke="#fff" stroke-width="2"/><circle r="6.7" fill="url(#gold)" stroke="${outline}" stroke-width=".8"/><ellipse cx="-2" cy="-2" rx="1.4" ry=".7" fill="#fff"/>`;
    }
    case 'snow': {
      let rays = '';
      for (let i = 0; i < 6; i++) {
        const ray = 'M 0 0 L 0 -10 M 0 -6 L -2.7 -8.7 M 0 -6 L 2.7 -8.7';
        rays += `<path d="${ray}" transform="rotate(${i * 60})" fill="none" stroke="#fff" stroke-width="4.3" stroke-linecap="round"/><path d="${ray}" transform="rotate(${i * 60})" fill="none" stroke="url(#${fill})" stroke-width="1.4" stroke-linecap="round"/>`;
      }
      return `${rays}<circle r="1.5" fill="#fff"/>`;
    }
    default:
      return sticker(starPath());
  }
}

const cluster = [[79, 18, 1.0, -12], [65, 14, .68, -22], [93, 34, .58, 16]];
for (let i = 0; i < themes.length; i++) {
  const kind = themes[i];
  const fill = Object.keys(colors)[i % Object.keys(colors).length];
  const decorations = cluster.map(([x, y, scale, rotation]) =>
    `<g transform="translate(${x} ${y}) rotate(${rotation}) scale(${scale})">${art(kind, fill)}</g>`,
  ).join('');
  const svg = `<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs>${gradients}</defs>${decorations}</svg>`;
  writeFileSync(join(directory, `effect_${String(i + 1).padStart(2, '0')}.svg`), svg);
}
