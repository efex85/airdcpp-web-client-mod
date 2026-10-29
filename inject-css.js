// inject-css.js
// Reads index.html and dark.css, inserts dark.css content as a <style> block
// immediately before the first </head> tag, then writes the file back.
const fs = require('fs');

const indexPath = '/airdcpp-webclient/web-resources/index.html';
const cssPath = '/tmp/dark.css';

const html = fs.readFileSync(indexPath, 'utf8');
const css = fs.readFileSync(cssPath, 'utf8');

const marker = '</head>';
const idx = html.indexOf(marker);

if (idx === -1) {
  console.error('ERROR: </head> not found in index.html — aborting injection.');
  process.exit(1);
}

const styleBlock = '<style>' + css + '</style>';
const newHtml = html.slice(0, idx) + styleBlock + html.slice(idx);

fs.writeFileSync(indexPath, newHtml, 'utf8');

console.log('Dark mode CSS injected successfully.');
