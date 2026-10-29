async function run() {
  try {
    const res = await fetch('https://www.tiktok.com/@esther252005/video/7641264615967542549', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
      }
    });
    const text = await res.text();
    const matchDesc = text.match(/<meta\s+property="og:description"\s+content="([^"]+)"/i);
    const matchTitle = text.match(/<meta\s+property="og:title"\s+content="([^"]+)"/i);
    const jsonMatch = text.match(/"desc":"([^"]+)"/);
    console.log('OG_TITLE:', matchTitle ? matchTitle[1] : 'null');
    console.log('OG_DESC:', matchDesc ? matchDesc[1] : 'null');
    console.log('JSON_DESC:', jsonMatch ? jsonMatch[1] : 'null');
  } catch (e) {
    console.error(e);
  }
}
run();
