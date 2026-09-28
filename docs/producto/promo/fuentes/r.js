const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
const jobs=[['merch',1900,1400],['banner',850,2000],['flyer_frente',1240,1748],['flyer_reverso',1240,1748]];
for (const [n,w,h] of jobs){const p=await b.newPage({viewport:{width:w,height:h}});await p.goto('file://'+__dirname+'/'+n+'.html');await p.waitForTimeout(700);await p.screenshot({path:__dirname+'/'+n+'.png',fullPage:true});await p.close();}
await b.close();})();
