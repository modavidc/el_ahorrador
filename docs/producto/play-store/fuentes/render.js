const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
for (const n of process.argv.slice(2)){const fg=n==='feature_graphic';
const p=await b.newPage({viewport:fg?{width:1024,height:500}:{width:1080,height:1920},deviceScaleFactor:1});
await p.goto('file://'+__dirname+'/'+n+'.html');await p.waitForTimeout(600);
await p.screenshot({path:__dirname+'/out/'+n+'.png'});await p.close();}
await b.close();})();
