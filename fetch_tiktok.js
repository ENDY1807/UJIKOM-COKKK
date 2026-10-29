async function main() {
  try {
    const res = await fetch('https://vt.tiktok.com/ZSgGwc7s1/', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      redirect: 'follow',
    });
    console.log('Final URL:', res.url);
    const html = await res.text();
    const title = html.match(/<title>([^<]+)<\/title>/i);
    const ogTitle = html.match(/<meta\s+property=["']og:title["']\s+content=["']([^"']+)["']/i);
    const ogDesc = html.match(/<meta\s+property=["']og:description["']\s+content=["']([^"']+)["']/i);
    console.log('TITLE:', title ? title[1] : '');
    console.log('OG_TITLE:', ogTitle ? ogTitle[1] : '');
    console.log('OG_DESC:', ogDesc ? ogDesc[1] : '');
  } catch (e) {
    console.error(e);
  }
}
main();
