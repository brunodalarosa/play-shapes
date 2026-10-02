/* Local asset review only. No network services and no production runtime changes. */
'use strict';
const {manifest,palette}=window.REVIEW_DATA;
const ui=Object.fromEntries(['play','color','face','size','speed','ground','scrub','grid','error'].map(id=>[id,document.getElementById(id)]));
for(const [name,hex] of Object.entries(palette))ui.color.add(new Option(name,hex,name==='Blue',name==='Blue'));
const load=src=>new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>resolve(img);img.onerror=()=>reject(new Error(`Could not load ${src}`));img.src=src;});
let playing=!matchMedia('(prefers-reduced-motion: reduce)').matches;
let time=0,last=0;
ui.play.textContent=playing?'Pause':'Play';
ui.play.onclick=()=>{playing=!playing;ui.play.textContent=playing?'Pause':'Play';};
ui.scrub.oninput=()=>{time=Number(ui.scrub.value)/24;playing=false;ui.play.textContent='Play';};
ui.size.onchange=()=>ui.grid.classList.toggle('small',ui.size.value==='128');

function tinted(image,hex){
  const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;
  const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(image,0,0);
  const pixels=ctx.getImageData(0,0,canvas.width,canvas.height),p=pixels.data;
  const target=[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16)/255),blue=[30/255,136/255,229/255];
  for(let i=0;i<p.length;i+=4){const diffuse=Math.min(1.4,Math.max(0,(p[i+2]-p[i])/199));for(let c=0;c<3;c++)p[i+c]=Math.round(Math.min(255,Math.max(0,p[i+c]+255*diffuse*(target[c]-blue[c]))));}
  ctx.putImageData(pixels,0,0);return canvas;
}

function ground(ctx,clip,frame){
  const yaw=clip.yaw_degrees*Math.PI/180,elev=clip.elevation_degrees*Math.PI/180;
  const scale=256/clip.orthographic_scale,[ax,ay]=clip.anchor_px;
  const dy=(time*clip.speed)%.4;
  ctx.fillStyle='#58718f';
  for(let x=-3;x<=3;x+=.4)for(let y=-2;y<=2;y+=.4){
    const movingY=y+dy,px=ax+scale*(Math.cos(yaw)*x+Math.sin(yaw)*movingY);
    const py=ay+scale*Math.sin(elev)*(Math.sin(yaw)*x-Math.cos(yaw)*movingY);
    if(px<4||px>252||py<4||py>252)continue;
    ctx.beginPath();ctx.arc(px,py,1,0,Math.PI*2);ctx.fill();
  }
  for(const foot of Object.values(frame.feet)){if(!foot.planted)continue;ctx.strokeStyle='#91e2c3';ctx.lineWidth=1;ctx.beginPath();ctx.ellipse(foot.pixel[0],foot.pixel[1]+1,9,3,0,0,Math.PI*2);ctx.stroke();}
}

async function start(){
  const cards=[];
  // Keep rows in camera order to make walk/run comparisons easy.
  const sorted=['front','three-quarter'].flatMap(view=>manifest.clips.filter(c=>c.view===view));
  for(const clip of sorted){
    const key=`${clip.name}-${clip.view}`;
    const element=document.createElement('article');element.className='card';
    const heading=document.createElement('h2');heading.textContent=clip.name[0].toUpperCase()+clip.name.slice(1);
    const caption=document.createElement('p');caption.textContent=clip.view==='front'?'Front':'Three-quarter';
    const canvas=document.createElement('canvas');canvas.width=canvas.height=256;canvas.setAttribute('aria-label',heading.textContent+' '+caption.textContent+' animated character');
    const sheetLink=document.createElement('a');sheetLink.href=`previews/${key}-beauty.png`;sheetLink.textContent='View sprite sheet';sheetLink.className='meta';
    element.append(heading,caption,canvas,sheetLink);ui.grid.append(element);
    const [base,neutral,blink]=await Promise.all(['colorable','neutral','blink'].map(layer=>load(`previews/${key}-${layer}.png`)));
    cards.push({clip,ctx:canvas.getContext('2d'),base,neutral,blink,color:null,colored:null});
  }
  function loop(now){
    if(last&&playing)time+=Math.min((now-last)/1000,.1)*Number(ui.speed.value);last=now;
    if(playing)ui.scrub.value=Math.floor(time*24)%48;
    const blinkTime=time%3.7,expression=ui.face.value==='auto'?(blinkTime>2.84&&blinkTime<2.98?'blink':'neutral'):ui.face.value;
    for(const card of cards){
      const {ctx,clip}=card,frame=Math.floor(time*24)%clip.frames,record=clip.sequence[frame];
      if(card.color!==ui.color.value){card.colored=tinted(card.base,ui.color.value);card.color=ui.color.value;}
      ctx.clearRect(0,0,256,256);if(ui.ground.checked)ground(ctx,clip,record);
      const sx=frame%8*256,sy=Math.floor(frame/8)*256;
      ctx.drawImage(card.colored,sx,sy,256,256,0,0,256,256);
      ctx.drawImage(card[expression],sx,sy,256,256,0,0,256,256);
    }
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
  window.reviewReady=true;
}
start().catch(error=>{ui.error.textContent=error.message+'. Open this page through the local preview command in README.md.';});
